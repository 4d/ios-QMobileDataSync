//
//  DataStore+Reload.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 28/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileDataStore
import QMobileAPI
import FileKit
import Moya
import Prephirences

extension DataSync {

    static var noAttributeFilter: Bool = {
         return Prephirences.sharedInstance["dataSync.noAttributeFilter"] as? Bool ?? false
    }()

    public func reload(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil, _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {
        if !isCancelled {
            cancel()
            // XXX maybe wait...
        }
        let cancellable = CancellableComposite() // return value, a cancellable
        self.dataSyncWillBegin(.reload, cancellable: cancellable)

        // Manage delegate completion event
        let completionHandler: SyncCompletionHandler = wrap(.reload, completionHandler: completionHandler)

        let future = initFuture(dataStoreContextType: dataStoreContextType, callbackQueue: callbackQueue)
        future.onFailure { error in
            completionHandler(.failure(error))
        }

        future.onSuccess { [weak self] in
            guard let this = self else {
                // memory issue, must retain the dataSync object somewhere
                completionHandler(.failure(.retain))
                return
            }
            this.doReload(dataStoreContextType: dataStoreContextType, callbackQueue: callbackQueue, cancellable: cancellable, completionHandler)

        }
        return cancellable
    }

    private func doReload(dataStoreContextType: DataStoreContextType, callbackQueue: DispatchQueue? = nil, cancellable: CancellableComposite, _ completionHandler: @escaping SyncCompletionHandler) {
        logger.info("Start data reloading")

        // Ask delegate if there is any reason to stop process
        let stop = self.dataSyncDidBegin(.reload)
        if stop {
            logger.info("Data reloading stop requested before starting the process")
            completionHandler(.failure(.delegateRequestStop))
            return
        }

        let startStamp = 0
        let tables = self.tables

        // From remote
        let tempPath: Path = .userTemporary

        let processCompletion = self.reloadProcessCompletionCallBack(dataStoreContextType: dataStoreContextType, tempPath: tempPath, completionHandler)
        let process = Process(tables: tables, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

        // assert(self.process == nil)
        self.process = process

        let locked = cancellable.perform {
            if cancellable.isCancelledUnlocked {
                completionHandler(.failure(.cancel))
            } else {
                let callbackQueue: DispatchQueue = callbackQueue ?? dataStoreContextType.queue

                // For each table get data from last global stamp
                //let configureRequest = this.configureRequest(stamp: startStamp)
                for table in self.tables {
                    logger.debug("Start data reloading for table \(table.name)")

                    let progress: APIManager.ProgressHandler = { progress in
                    }

                    let requestCancellable = self.reloadTable(table, in: tempPath, callbackQueue: callbackQueue, progress: progress)
                    _ = cancellable.appendUnlocked(requestCancellable)
                }
            }
        }
        if !locked {
            logger.warning("Failed to aquire lock on cancellable object before adding new task to reload tables data")
        }
        /*}*/
        // return no task if dataStore not ready
        /* if !perform {
         logger.warning("Cannot get data: context cannot be created on data store")
         completionHandler(.failure(.dataStoreNotReady))
         return

         }*/
    }

    func reloadProcessCompletionCallBack(dataStoreContextType: DataStoreContextType, tempPath: Path, _ completionHandler: @escaping SyncCompletionHandler) -> Process.CompletionHandler {
        return { result in

            if self.isCancelled {
                completionHandler(.failure(.cancel))
                return
            }

            switch result {
            case .success(let stamp):
                // store new stamp
                var metadata = self.dataStore.metadata
                metadata?.globalStamp = stamp
                metadata?.lastSync = Date()

                let files = tempPath.children().filter { $0.pathFullExtension == DataSync.Preferences.jsonDataExtension }

                self.clearFileCache()
                if self.isCancelled {
                    completionHandler(.failure(.cancel))
                    return
                }

                for file in files {
                    let destination: Path = self.cachePath + file.fileName
                    do {
                        try file.copyFile(to: destination)
                    } catch {
                        completionHandler(.failure(DataSyncError.dataCache(error)))
                        return
                    }
                }
                if self.isCancelled {
                    completionHandler(.failure(.cancel))
                    return
                }

                let result = self.dataStore.perform(dataStoreContextType, blockName: "LoadCacheDataAfterRealoading") { context in
                    if self.isCancelled {
                        completionHandler(.failure(.cancel))
                        return
                    }

                    logger.info("Delete all tables data before loading from files")
                    do {
                        for (table, tableInfo) in self.tablesInfoByTable {
                            logger.verbose("Data of table \(table.name) will be deleted")
                            let deletedCount = try context.delete(in: tableInfo)
                            logger.debug("Data of table \(table.name) deleted: \(deletedCount)")
                        }
                    } catch {
                        completionHandler(.failure(DataSyncError.error(from: DataStoreError.error(from: error))))
                    }

                    logger.info("Load table data from cache data files")
                    do {
                        try self.loadRecordsFromCache(context: context)
                        logger.debug("Load table data from cache data files success")
                        completionHandler(.success(()))
                    } catch {
                        completionHandler(.failure(DataSyncError.error(from: DataStoreError.error(from: error))))
                    }
                }
                if !result {
                    completionHandler(.failure(DataSyncError.dataStoreNotReady))
                }

            case .failure(let error):
                completionHandler(.failure(DataSyncError.apiError(error)))
            }
        }
    }

    private func parseDate(from value: Any) -> Date? {
        if let date = value as? Date {
            return date
        } else if let string = value as? String, let date = string.dateFromRFC3339 ?? string.simpleDate {
            return date
        } else if let json = value as? JSON, let date = json.date {
            return date
        }
        return nil
    }

    func reloadTable(_ table: Table, in path: Path, callbackQueue: DispatchQueue? = nil, progress: APIManager.ProgressHandler? = nil) -> Cancellable {
        dataSyncBegin(for: table, .reload)

        let cancellable = CancellableComposite()
        let attributes: [String] = DataSync.noAttributeFilter ? [] : table.attributes.map { $0.0 }

        var target = rest.base.records(from: table.name, attributes: attributes)
        target.limit(Prephirences.DataSync.Request.limit)

        // If a filter is defined by table in data store, use it
        if let filter = tablesInfoByTable[table]?.filter {
            target.filter(filter)

            /// Get user info to filter data
            if var params = APIManager.instance.authToken?.userInfo {
                for (key, value) in params {
                    if let date = parseDate(from: value), date.isUTCStartOfDay {
                        params[key] = "'\(DateFormatter.simpleDate.string(from: date))'" // format for 4d
                        // APIManager.instance.authToken?.userInfo = params
                    }
                }
                // target.params(params)
                target.params([params]) // need a collection for the moment
                logger.debug("Filter query params [\(params)] for \(table.name)")
            }
        }

        let completion: APIManager.Completion = { result in
            switch result {
            case .success(let response):

                let path: Path = path + "\(table.name).\(DataSync.Preferences.jsonDataExtension)"
                let data = response.data

                #if DEBUG
                // Check before writing to file if correct data.
                // But we must to be here if http code management are correct
                if let json = try? JSON(data: data) {
                    if json["ok"] != true {
                        assert(ImportableParser.tableName(for: json) != nil)
                    }// else bug 4D
                } else {
                    assertionFailure("Unable to read JSON data")
                }
                #endif

                if path.exists {
                    try? path.deleteFile()
                }
                do {
                    try DataFile(path: path).write(response.data)
                } catch {
                    logger.warning("failed to write to \(path)")
                }

                let pageInfo = PageInfo.dummy
                assert(pageInfo.isLast)
                self.dataSyncEnd(for: table, with: pageInfo, .reload)

                if pageInfo.isLast, let process = self.process {
                    if process.lock() {
                        defer {
                           _ = process.unlock()
                        }

                        // Set current table completed
                        process.completed(for: table, with: .success(pageInfo))
                        // Check if we must relaunch some request due to stamp
                        if let tableStatus = process.checkCompleted() {
                            // There is some table to relaunch sync because stamp are not equal
                            for (table, _) in tableStatus {
                                let c = self.reloadTable(table, in: path, callbackQueue: callbackQueue, progress: progress)
                                _ = cancellable.append(c)
                            }
                        }
                    }
                }
            case .failure(let error):
                self.dataSyncFailed(for: table, with: APIError.error(from: error), .reload)

                if var process = self.process {
                    if process.lock() {
                        defer {
                            _ = process.unlock()
                        }
                        self.process?.completed(for: table, with: .mapOtherError(error))
                        _ = self.process?.checkCompleted()
                    }
                }
            }
        }

        let cancellableRecords = rest.request(target, callbackQueue: callbackQueue, progress: progress, completion: completion)
        _ = cancellable.append(cancellableRecords)

        return cancellable
    }

    /// Drop all data from tables in data store.
    public func drop(dataStoreContextType: DataStoreContextType = .background, _ completionHandler: @escaping SyncCompletionHandler) -> Bool {
        let result = self.dataStore.perform(dataStoreContextType, blockName: "DropTable") { context in
            if self.isCancelled {
                completionHandler(.failure(.cancel))
                return
            }

            logger.info("Delete all tables data")
            do {
                for (table, tableInfo) in self.tablesInfoByTable {
                    logger.verbose("Data of table \(table.name) will be deleted")
                    let deletedCount = try context.delete(in: tableInfo)
                    logger.debug("Data of table \(table.name) deleted: \(deletedCount)")
                }
            } catch {
                completionHandler(.failure(DataSyncError.error(from: DataStoreError.error(from: error))))
            }
        }
        return result
    }
}

extension PageInfo {
    static let dummy = PageInfo(globalStamp: 0, sent: Prephirences.DataSync.Request.limit, first: 0, count: Prephirences.DataSync.Request.limit)
}

extension Date {
    public var isUTCStartOfDay: Bool {
        return Calendar.utc.startOfDay(for: self) == self
    }
}

extension Calendar {
    static let utc: Calendar  = {
        var calendar = Calendar.current
        // swiftlint:disable:next force_cast
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    static let localTime: Calendar  = {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar
    }()
}
