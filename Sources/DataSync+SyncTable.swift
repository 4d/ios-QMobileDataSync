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

import QMobileDataStore
import QMobileAPI

extension DataSync {

    func configureRequest(stamp: TableStampStorage.Stamp) -> ((RecordsRequest) -> Void) {
        return { request in
            request.limit(Preferences.requestPageLimit)
            // stamp filter
            let filter = "\(kStampFilter)=\(stamp)"
            request.filter(filter)
        }
    }

    func syncTable(_ table: Table, callbackQueue: DispatchQueue? = nil, configureRequest: @escaping ((RecordsRequest) -> Void), context: DataStoreContext, save: @escaping DataStore.SaveClosure) -> Cancellable {
        dataSyncBegin(for: table)

        var cancellable = CancellableComposite()

        guard let tableInfo = self.tablesInfoByTable[table] else {
            assertionFailure("No table storage info for table \(table)")
            return cancellable
        }

        let initializer = self.recordInitializer(table: table, tableInfo: tableInfo, context: context)

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

                    self.dataSyncEnd(for: table, with: pageInfo)
                    if case .byTable = self.saveMode {
                        self.trySave(save)
                        // If save could not manage error
                    }
                }
                if case .eachPage = self.saveMode {
                    self.trySave(save)
                }
                if pageInfo.isLast, let process = self.process {
                    _ = process.lock() // #FIXME dead lock here????
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
                            let c = self.syncTable(table, configureRequest: configureRequest, context: context, save: save)
                            cancellable.append(c)
                        }
                    }
                }
            case .failure(let error):
                self.dataSyncFailed(for: table, with: error)

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
        let attributes: [String]
        if let no = Prephirences.sharedInstance["dataSync.noAttributeFilter"] as? Bool, no {
            attributes = []
        } else {
            attributes = table.attributes.map { $0.0 }
        }
        let cancellableRecords = self.rest.loadRecords(table: table, attributes: attributes, recursive: true, configure: configureRequest, initializer: initializer, queue: callbackQueue, completionHandler: completion)

        cancellable.append(cancellableRecords)

        return cancellable
    }
}
