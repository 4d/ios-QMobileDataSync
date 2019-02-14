//
//  DataSync+SyncTable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Foundation
import Result
import Prephirences
import BrightFutures
import Moya
import FileKit

import QMobileDataStore
import QMobileAPI

extension DataSync {

    func syncTable(_ table: Table,
                   in path: Path,
                   operation: DataSync.Operation,
                   callbackQueue: DispatchQueue? = nil,
                   progress: APIManager.ProgressHandler? = nil,
                   configureRequest: @escaping ((RecordsRequest) -> Void),
                   context: DataStoreContext) -> Cancellable {
        let cancellable = CancellableComposite()
        guard let tableInfo = self.tablesInfoByTable[table] else {
            assertionFailure("No table storage info for table \(table)")
            return cancellable
        }

        dataSyncBegin(for: table, operation)

        let initializer = DataSync.recordInitializer(table: table, tableInfo: tableInfo, context: context)

        let completion: ((Result<([Record], PageInfo), APIError>) -> Void) = { result in
            switch result {
            case .success(let (records, pageInfo)):
                // TODO check/save global stamp and current one
                #if DEBUG
                    let stamps = records.map { $0.__stamp }
                    if let max = stamps.max(), max > pageInfo.globalStamp {
                        logger.warning("GlobalStamp(\(pageInfo.globalStamp)) is not updated. Receive a record with stamp \(max)'")
                    }
                #endif

                if pageInfo.isLast {
                    logger.info("Last page loaded for table \(table.name)")

                    self.dataSyncEnd(for: table, with: pageInfo, operation)
                    if case .byTable = self.saveMode {
                        self.tryCommit(context)
                        // If save could not manage error
                    }
                }
                if case .eachPage = self.saveMode {
                    self.tryCommit(context)
                }
                if pageInfo.isLast, let process = self.process {
                    _ = process.lock()
                    defer {
                        _ = process.unlock()
                    }
                    // Set current table completed
                    process.completed(for: table, with: .success(pageInfo))
                    // Check if we must relaunch some request due to stamp
                    if let tableStatus = process.checkCompleted() {

                        // There is some table to relaunch sync because stamp are not equal
                        for (table, stamp) in tableStatus {
                            let configureRequest = self.configureRequest(stamp: stamp) // XXX Maybe a max stamp also to not do job eternally
                            let c = self.syncTable(table,
                                                   in: path,
                                                   operation: operation,
                                                   callbackQueue: callbackQueue,
                                                   progress: progress,
                                                   configureRequest: configureRequest,
                                                   context: context)
                            cancellable.append(c)
                        }
                    }
                }
            case .failure(let error):
                self.dataSyncFailed(for: table, with: error, operation)

                if var process = self.process {
                    _ = process.lock()
                    defer {
                        _ = process.unlock()
                    }
                    self.process?.completed(for: table, with: .mapOtherError(error))
                    _ = self.process?.checkCompleted()
                }
            }
        }
        let attributes = getAttributes(table)
        let cancellableRecords = self.apiManager.records(table: table,
                                                         attributes: attributes,
                                                         recursive: true,
                                                         configure: configureRequest,
                                                         initializer: initializer,
                                                         queue: callbackQueue,
                                                         completionHandler: completion)

        cancellable.append(cancellableRecords)

        return cancellable
    }

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

        let attributes = self.getAttributes(table)
        var target = self.apiManager.base.records(from: table.name, attributes: attributes)
        target.limit(Prephirences.DataSync.Request.limit)

        // Maybe do not synchronize the table
        if tableInfo.slave != nil {
            let pageInfo: PageInfo = .dummy
            self.dataSyncEnd(for: table, with: pageInfo, operation)
            self.process?.completed(for: table, with: .success(pageInfo))
            return cancellable
        }

        // If a filter is defined by table in data store, use it
        if let filter = tableInfo.filter {
            target.filter(filter)

            /// Get user info to filter data
            if var params = APIManager.instance.authToken?.userInfo {
                for (key, value) in params {
                    if let date = parseDate(from: value), date.isUTCStartOfDay {
                        params[key] = "'\(DateFormatter.simpleDate.string(from: date))'" // format for 4d
                        // APIManager.instance.authToken?.userInfo = params
                    }
                }
                target.params(params)
                // target.params([params])
                logger.debug("Filter query params \(params) for \(table.name)")
            }
        }

        // custom limit by table
        if let limitString = tableInfo.limit, let limit = Int(limitString) {
            target.limit(limit)
        }

        // Expand according to relation
        if Prephirences.DataSync.expandAttribute { // will expend related entity will all fields
            let relatedEntityAttributes = table.attributes.filter { $0.1.kind == .relatedEntity }
            if !relatedEntityAttributes.isEmpty {
                let expand = relatedEntityAttributes.map { $0.0 }.joined(separator: ",")
                target.expand(expand)
            }
        }

        // what to do when finishing
        let completion: APIManager.Completion = { result in
            switch result {
            case .success(let response):

                // Write to file
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

                let pageInfo: PageInfo = .dummy // here multipage is deactivated
                self.dataSyncEnd(for: table, with: pageInfo, operation)

                if pageInfo.isLast, let process = self.process {
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
                }
            case .failure(let error):
                // notify for one table
                self.dataSyncFailed(for: table, with: APIError.error(from: error), operation)

                // notify process
                if var process = self.process {
                    if process.lock() {
                        defer { _ = process.unlock() }
                        process.completed(for: table, with: .mapOtherError(error))
                        _ = process.checkCompleted()
                    }
                }
            }
        }

        // launch the request
        let cancellableRecords = self.apiManager.request(target, callbackQueue: callbackQueue, progress: progress, completion: completion)
        _ = cancellable.append(cancellableRecords)

        return cancellable
    }

    func getAttributes(_ table: Table) -> [String] {
        let attributes: [String]
        if Prephirences.DataSync.noAttributeFilter {
            attributes = []
        } else if Prephirences.DataSync.expandAttribute {
            attributes = table.attributes.filter { !$0.1.type.isRelative }.map { $0.0 }
        } else {
            attributes = table.attributes.compactMap { (name, attribute) in
                if let relationType = attribute.relativeType {
                    if let expand = relationType.expand {
                        let expands = expand.split(separator: ",")
                        return expands.map { "\(name).\($0)"}.joined(separator: ",")
                    }
                    return nil
                } else {
                    return name
                }
            }
        }
        return attributes
    }

    func configureRequest(stamp: TableStampStorage.Stamp) -> ((RecordsRequest) -> Void) {
        return { request in
            request.limit(Prephirences.DataSync.Request.Page.limit)
            // stamp filter
            let filter = "\(kStampFilter)=\(stamp)"
            request.filter(filter)

            /*if let filter = tablesInfoByTable[table]?.filter {
             target.filter(filter)

             /// Get user info to filter data
             if var params = APIManager.instance.authToken?.userInfo {
             for (key, value) in params {
             if let date = parseDate(from: value), date.isUTCStartOfDay {
             params[key] = "'\(DateFormatter.simpleDate.string(from: date))'" // format for 4d`
             // APIManager.instance.authToken?.userInfo = params
             }
             }
             // target.params(params)
             target.params([params]) // need a collection for the moment
             }
             }*/
        }
    }
}
