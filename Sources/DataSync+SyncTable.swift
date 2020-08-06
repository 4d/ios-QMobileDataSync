//
//  DataSync+SyncTable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences
import BrightFutures
import Moya
import FileKit

import QMobileDataStore
import QMobileAPI

extension DataSync {

    fileprivate func sync(tableStatus: [DataSync.Process.TableStatus],
                          cancellable: CancellableComposite,
                          in path: Path,
                          operation: DataSync.Operation,
                          callbackQueue: DispatchQueue? = nil,
                          progress: APIManager.ProgressHandler? = nil,
                          context: DataStoreContext
    ) {
        // There is some table to relaunch sync because stamp are not equal
        for (table, stamp) in tableStatus {
            let c = self.syncTable(table,
                                   at: stamp,
                                   in: path,
                                   operation: operation,
                                   callbackQueue: callbackQueue,
                                   progress: progress,
                                   context: context)
            cancellable.append(c)
        }
    }

    /// Synchronize one table.
    ///
    /// - parameter table:         The table to sync.
    /// - parameter startStamp:    The stamp to bebin sync.
    /// - parameter path:          The path to use if data catched.
    /// - parameter operation:     The type of operation.
    /// - parameter callbackQueue: The queue used for callback of request.
    /// - parameter progress:      An handler to get progression information about the request.
    /// - parameter context:       Data store context, to make data store operation.
    func syncTable(_ table: Table,
                   at startStamp: TableStampStorage.Stamp,
                   in path: Path,
                   operation: DataSync.Operation,
                   callbackQueue: DispatchQueue? = nil,
                   progress: APIManager.ProgressHandler? = nil,
                   context: DataStoreContext,
                   completionHandler: (() -> Void)? = nil) -> Cancellable {
        let cancellable = CancellableComposite()
        guard let tableInfo = self.tablesInfoByTable[table] else {
            assertionFailure("No table storage info for table \(table)")
            completionHandler?()
            return cancellable
        }
        dataSyncBegin(for: table, operation)

        // Maybe do not synchronize the table if slave table.
        if tableInfo.isSlave {
            let pageInfo: PageInfo = .ignored
            self.dataSyncEnd(for: table, with: pageInfo, operation)
            self.process?.completed(for: table, with: .success(pageInfo))
            completionHandler?()
            return cancellable
        }

        let completion: ((Result<([Record], PageInfo), APIError>) -> Void) = { result in
            switch result {
            case .success(let (_/*records*/, pageInfo)):

                guard pageInfo.isLast else {
                    /*if case .eachPage = self.saveMode {
                        self.tryCommit(context)
                    }*/
                    return
                }
                logger.info("Last page loaded for table \(table.name): \(pageInfo)")
                self.dataSyncEnd(for: table, with: pageInfo, operation)
                /*if case .byTable = self.saveMode {
                    self.tryCommit(context) // If save could not manage error

                }*/
                if let process = self.process {
                    _ = process.lock()
                    defer { _ = process.unlock() }

                    // Set current table completed
                    process.completed(for: table, with: .success(pageInfo))
                    // Check if we must relaunch some request due to stamp
                    if let tableStatus = process.checkCompleted() {
                        self.sync(tableStatus: tableStatus,
                                  cancellable: cancellable,
                                  in: path,
                                  operation: operation,
                                  callbackQueue: callbackQueue,
                                  progress: progress,
                                  context: context)
                    } else {
                        logger.verbose(" \(operation) complete, after sync of table \(table)")
                    }
                    completionHandler?()
                } else {
                    logger.warning("No process available when finish to \(operation) the table \(table)")
                    completionHandler?()
                }
            case .failure(let error):
                // notify for one table
                self.dataSyncFailed(for: table, with: error, operation)
                // notify process
                _ = self.process?.completedAndCheck(for: table, with: .mapOtherError(error))
                completionHandler?()
            }
        }

        // Configure and launch the request
        let attributes = self.getAttributes(table)
        let initializer = DataSyncBuilder(table: table, tableInfo: tableInfo, context: context)
        let configureRequest = self.configureRecordsRequest(stamp: startStamp, tableInfo, table)
        let cancellableRecords = self.apiManager.records(table: table,
                                                         attributes: attributes,
                                                         recursive: true,
                                                         configure: configureRequest,
                                                         initializer: initializer,
                                                         queue: callbackQueue,
                                                         completionHandler: completion)
        _ = cancellable.append(cancellableRecords)

        return cancellable
    }

    /// Reload one table.
    ///
    /// - parameter table:         The table to sync.
    /// - parameter path:          The path to use if data catched.
    /// - parameter operation:     The type of operation.
    /// - parameter callbackQueue: The queue used for callback of request.
    /// - parameter progress:      An handler to get progression information about the request.
    func reloadTable( _ table: Table,
                      in path: Path,
                      operation: DataSync.Operation,
                      callbackQueue: DispatchQueue? = nil,
                      progress: APIManager.ProgressHandler? = nil) -> Cancellable {
        let cancellable = CancellableComposite()
        guard let tableInfo = self.tablesInfoByTable[table] else {
            assertionFailure("No table storage info for table \(table)")
            return cancellable
        }
        dataSyncBegin(for: table, operation)

        // Maybe do not synchronize the table if slave table.
        if tableInfo.isSlave {
            let pageInfo: PageInfo = .ignored
            self.dataSyncEnd(for: table, with: pageInfo, operation)
            self.process?.completed(for: table, with: .success(pageInfo))
            return cancellable
        }

        // what to do when finishing
        let completion: APIManager.Completion = { result in
            switch result {
            case .success(let response):

                // Write to file
                let filePath: Path = path + "\(table.name).\(DataSync.Preferences.jsonDataExtension)"
                let data = response.data
                if filePath.exists {
                    try? filePath.deleteFile()
                }
                do {
                    try DataFile(path: filePath).write(response.data)
                } catch {
                    logger.warning("failed to write to \(filePath)")
                }

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

                let pageInfo: PageInfo = .ignored // here multipage is deactivated
                if pageInfo.isLast {
                    self.dataSyncEnd(for: table, with: pageInfo, operation)

                    if let process = self.process {
                        if process.lock() {
                            defer { _ = process.unlock() }

                            // Set current table completed
                            process.completed(for: table, with: .success(pageInfo))

                            // Check if we must relaunch some request due to stamp
                            if let tableStatus = process.checkCompleted() {
                                // There is some table to relaunch sync because stamp are not equal
                                for (table, _) in tableStatus {
                                    let c = self.reloadTable(table,
                                                             in: path,
                                                             operation: operation,
                                                             callbackQueue: callbackQueue,
                                                             progress: progress)
                                    _ = cancellable.append(c)
                                }
                            }
                        }
                    } else {
                        logger.warning("No process available when finish to \(operation) the table \(table)")
                    }
                }
            case .failure(let error):
                // notify for one table
                self.dataSyncFailed(for: table, with: APIError.error(from: error), operation)
                // notify process
                _ = self.process?.completedAndCheck(for: table, with: .mapOtherError(error))
            }
        }

        // Configure and launch the request
        let attributes = self.getAttributes(table)
        let target = self.apiManager.base.records(from: table.name, attributes: attributes)
        self.configureRecordsRequest(target, tableInfo, table)
        let cancellableRecords = self.apiManager.request(target, callbackQueue: callbackQueue, progress: progress, completion: completion)
        _ = cancellable.append(cancellableRecords)

        return cancellable
    }

    /// For one table, get list of attribute to use in records request.
    func getAttributes(_ table: Table) -> [String: Any] {
        var attributes: [String: Any] = [:]

        let tableInfo = self.tablesInfoByTable[table]
        let fieldInfoByOriginalName = tableInfo?.fields.dictionary { $0.originalName }

        for (name, attribute) in table.attributes {
            if let relationType = attribute.relativeType { // is a relation
                if let expandString = relationType.expand {
                    let expands = expandString.split(separator: ",")

                    if RecordsTarget.attributeInBody {
                        var relationsInfo: [String: Any] = [:]
                        for expand in expands {
                            relationsInfo[String(expand)]=true
                        }
                        if let filter = relationType.filter {
                            relationsInfo["__Query"]=filter
                        }
                        attributes[name]=relationsInfo
                    } else {
                        for expand in expands.map({ "\(name).\($0)"}) {
                            attributes[expand]=true
                        }
                    }
                } // else skip relation with no field
            } else {
                if Prephirences.DataSync.allowMissingField, let fieldInfo = fieldInfoByOriginalName?[name], fieldInfo.isMissingRemoteField {  // allow to reload event if missing attributes
                    // skip
                } else {
                    attributes[name]=true
                }
            }
        }

        return attributes
    }

    func configureRecordsRequest(stamp: TableStampStorage.Stamp, _ tableInfo: DataStoreTableInfo, _ table: Table) -> ((RecordsRequest) -> Void) {
        return { request in
            self.configureRecordsRequest(request, tableInfo, table)

            // Stamp filter
            if tableInfo.hasGlobalStamp || table.attributes[kGlobalStamp] != nil {
                request.appendToFilter("\(kGlobalStamp)>=\(stamp)") // seems to be superior or equal today
            } else {
                logger.warning("There is no \(kGlobalStamp) field in table \(table.name). We could not make optimized data synchronization. Please update your structure.")
            }
        }
    }

    /// Configure the record request
    func configureRecordsRequest(_ request: RecordsRequest, _ tableInfo: DataStoreTableInfo, _ table: Table) {
        /// Defined limit
        request.limit(Prephirences.DataSync.Request.Page.limit)

        // If a filter is defined by table in data store, use it
        if let filter = tableInfo.filter {
            request.filter(filter)

            /// Get user info to filter data
            if var params = APIManager.instance.authToken?.userInfo {
                for (key, value) in params {
                    if let date = parseDate(from: value), date.isUTCStartOfDay {
                        params[key] = "'\(DateFormatter.simpleDate.string(from: date))'" // format for 4d
                        // APIManager.instance.authToken?.userInfo = params
                    }
                }
                request.params(params)
                // target.params([params])
                logger.debug("Filter query params \(params) for \(table.name) with filter \(filter)")
            }
        }

        // custom limit by table
        if let limitString = tableInfo.limit, let limit = Int(limitString) {
            request.limit(limit)
        }
    }

}
