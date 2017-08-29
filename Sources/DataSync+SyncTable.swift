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

    func syncTable(_ table: Table, queue: DispatchQueue? = nil, configureRequest: @escaping ((RecordsRequest) -> Void), context: DataStoreContext, save: @escaping VoidClosure) -> Cancellable {
        let tableName = table.name
        logger.debug("Load records for \(tableName)")
        Notification(name: .dataSyncForTableBegin, object: table).post()
        self.delegate?.willDataSyncBegin(for: table)

        let initializer = self.recordInitializer(table: table, context: context)
        var cancellable = CancellableComposite()
        let cancellableRecords = self.rest.loadRecords(table: table, recursive: true, configure: configureRequest, initializer: initializer, queue: queue) { result in
            switch result {
            case .success(let (records, page)):
                logger.debug("Receive page '\(page)' for table '\(tableName)'")
                #if DEBUG
                    let stamps = records.map { $0.__stamp }
                    if let max = stamps.max(), max > page.globalStamp {
                        logger.warning("GlobalStamp(\(page.globalStamp)) is not updated. Receive a record with stamp \(max)'")
                    }
                #endif

                // TODO check/save global stamp and current one
                // TODO If a table have more recent stamp resync this table

                if page.isLast {
                    logger.info("Last page loaded for table \(tableName)")

                    self.delegate?.didDataSyncEnd(for: table, page: page)
                    Notification(name: .dataSyncForTableSuccess, object: (table, page)).post()
                    if case .byTable = self.saveMode {
                        self.trySave(save)
                        // If save could not manage error
                    }
                }
                if case .eachPage = self.saveMode {
                    self.trySave(save)
                }
                if page.isLast {

                    if var process = self.process {
                        // #FIXME dead lock here????
                        logger.verbose("will lock process")
                        objc_sync_enter(process)
                        logger.verbose("did lock process")
                        defer {
                            logger.verbose("will unlock process")
                            objc_sync_exit(process)
                            logger.verbose("did unlock process")
                        }

                        self.process?.completed(for: table, with: .success(page))

                        if let tableStatus = self.process?.checkCompleted() {
                            // There is some table to relaunch sync
                            for (table, stamp) in tableStatus {
                                let configureRequest = self.configureRequest(stamp: stamp)
                                let c = self.syncTable(table, configureRequest: configureRequest, context: context, save: save)
                                cancellable.append(c)
                            }
                        }
                    }
                }
            case .failure(let error):
                var errorMessage = "\(error)"
                if let requestCase = error.requestCase {
                    errorMessage = "\(requestCase) (\(error.localizedDescription))"
                }

                logger.warning("Failed to get records for table \(tableName): \(errorMessage)")

                Notification(name: .dataSyncForTableFailed, object: (table, error)).post()
                self.delegate?.didDataSyncFailed(for: table, error: error)

                if var process = self.process {
                    objc_sync_enter(process)
                    defer {
                        objc_sync_exit(process)
                    }

                    self.process?.completed(for: table, with: .failureMappable(error))

                    _ = self.process?.checkCompleted()
                }
            }
        }
        cancellable.append(cancellableRecords)

        return cancellable
    }
}
