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

    public func reload(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil, _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {
        if !isCancelled {
            cancel()
            // XXX maybe wait...
        }

        // Manage delegate completion event
        let completionHandler: SyncCompletionHandler = wrap(completionHandler: completionHandler)

        let cancellable = CancellableComposite() // return value, a cancellable

        initFuture(dataStoreContextType: dataStoreContextType, callbackQueue: callbackQueue)
            .onFailure { error in
                completionHandler(.failure(error))
            }
            .onSuccess { [weak self] in
                guard let this = self else {
                    // memory issue, must retain the dataSync object somewhere
                    completionHandler(.failure(.retain))
                    return
                }

                logger.info("Start data reloading")

                // Ask delegate if there is any reason to stop process
                let stop = this.dataSyncBegin()
                if stop {
                    logger.info("Data reloading stop requested before starting the process")
                    completionHandler(.failure(.delegateRequestStop))
                    return
                }

                // perform a data store task in background
                //let perform = this.dataStore.perform(dataStoreContextType) { [weak self] context, save in
                /*guard let this = self else {
                 // memory issue, must retain the dataSync object somewhere
                 completionHandler(.failure(.retain))
                 return
                 }*/

                let startStamp = 0
                let tables = this.tables

                // From remote
                let tempPath: Path = .userTemporary

                let processCompletion = this.reloadProcessCompletionCallBack(dataStoreContextType: dataStoreContextType, tempPath: tempPath, completionHandler)
                let process = Process(tables: tables, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

                // assert(this.process == nil)
                this.process = process

                let locked = cancellable.perform {
                    if cancellable.isCancelledUnlocked {
                        completionHandler(.failure(.cancel))
                    } else {
                       let callbackQueue: DispatchQueue = callbackQueue ?? dataStoreContextType.queue

                        // For each table get data from last global stamp
                        //let configureRequest = this.configureRequest(stamp: startStamp)
                        for table in this.tables {
                            logger.debug("Start data reloading for table \(table.name)")

                            let progress: APIManager.ProgressHandler = { progress in

                            }

                            let requestCancellable = this.reloadTable(table, in: tempPath, callbackQueue: callbackQueue, progress: progress)
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
        return cancellable
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

    func reloadTable(_ table: Table, in path: Path, callbackQueue: DispatchQueue? = nil, progress: APIManager.ProgressHandler? = nil) -> Cancellable {
        dataSyncBegin(for: table)

        let cancellable = CancellableComposite()
        let attributes: [String]
        if let no = Prephirences.sharedInstance["dataSync.noAttributeFilter"] as? Bool, no {
            attributes = []
        } else {
            attributes = table.attributes.map { $0.0 }
        }

        var target = rest.rest.records(from: table.name, attributes: attributes)
        target.limit(Preferences.requestLimit)

        let completion: APIManager.Completion = { result in
            switch result {
            case .success(let response):

                let path: Path = path + "\(table.name).\(DataSync.Preferences.jsonDataExtension)"
                let data = response.data

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
                self.dataSyncEnd(for: table, with: pageInfo)

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
                self.dataSyncFailed(for: table, with: APIError.error(from: error))

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
}

extension PageInfo {
    static let dummy = PageInfo(globalStamp: 0, sent: DataSync.Preferences.requestLimit, first: 0, count: DataSync.Preferences.requestLimit)
}
