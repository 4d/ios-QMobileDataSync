//
//  DataSync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 02/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileDataStore
import QMobileAPI
import Result
import Moya

let logger = Logger.forClass(DataSync.self) // XXX check if configuration not already done...
public class DataSync {

    // object to make remote request
    public let rest: APIManager
    // mobile data store
    public let dataStore: DataStore

    public init(rest: APIManager = APIManager(url: Preferences.remoteServerURL), dataStore: DataStore = QMobileDataStore.dataStore) {
        self.rest = rest
        self.dataStore = dataStore
    }

    /// Bundle for files (JSON tables and data)
    public var bundle: Bundle = .main

    /// List of loaded tables indexed by name
    public var tables: [String: Table] = [:]

}

// MARK: Sync
extension DataSync {

    /*
     public func cancel() {
     // TODO cancel all requests, or return a cancellable object in sync function
    }*/

    public typealias SyncCompletionHander = (Result<Void, APIError>) -> Void
    public func sync(completitonHandler: SyncCompletionHander) -> Cancellable? {
        // TODO add an handler for completion and maybe progress
        // TODO If there is already a sync stop it, maybe add a bool force and only if force=true, or do nothing

        // TODO get last stamp from dataStore metadata

        if self.tables.isEmpty { // no request to do if no table
            return nil
        }
        // return value, a cancellable
        var cancellable = CancellableComposite()

        // perform a data store task in background
        let perform = dataStore.perform(.background) { [unowned self] context, save in

            if Preferences.firstSync {
                if Preferences.dataFromFile {
                    self.loadRecordsFromFile(context: context, save: save)
                }
                Preferences.firstSync = false
            }
            // TODO for each table get data from last global stamp
            // If no stamp and dataStore empty get from files?
            // If no stamp get all
            for (tableName, table) in self.tables {
                logger.debug("Load records for \(tableName)")

                // from remote

                let configure: ((RecordsRequest) -> Void) = { request in
                    request.limit(Preferences.requestLimit)
                    let filter = ""
                    request.filter(filter)
                }

                let requestCancellable = self.rest.loadRecords(table: table, configure: configure, initializer: self.recordInitializer(table: table, context: context)) { result in
                    switch result {
                    case .success(let (_, page)):

                        // (a save publish information to UI)
                        if page.isLast {
                           // NOTIFY table end

                            logger.info("Last page loaded for table \(tableName)")
                        }
                        self.trySave(save)
                        // TODO check/save global stamp and current one

                        logger.debug("Page \(page) for table \(tableName)")

                        break
                    case .failure(let error):
                        logger.warning("Failed to get records for table \(tableName): \(error)")
                        // NOTIFY table end
                    }
                }
                cancellable.list.append(requestCancellable)

            }
        }
        // return no task if dataStore not ready
        if !perform {
            logger.warning("Cannot get data: context cannot be created on data store")
            return nil
        }
        return cancellable
    }

}
