//
//  DataSync+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Result
import Prephirences
import BrightFutures
import Moya

import QMobileDataStore
import QMobileAPI

let kStampFilter = "__stamp"

extension Lockable {

    public func perform(lockedTask task: () -> Void) -> Bool {
        if lock() {
            defer {
                _ = unlock()
            }
            task()
            return true
        }
        return false
    }

}

// MARK: Sync
extension DataSync {

    public typealias SyncResult = Result<Void, DataSyncError>
    public typealias SyncCompletionHandler = (SyncResult) -> Void
    public typealias SyncFuture = Future<Void, DataSyncError>

    public func sync(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil, _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {

        cancel()
        // TOTEST maybe wait process cancel...

        // Manage delegate completion event
        let completionHandler = wrap(completionHandler: completionHandler)

        let cancellable = CancellableComposite() // return value, a cancellable

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
            logger.info("Start data synchronisation")

            // Check if metadata could be read
            guard let metadata = this.dataStore.metadata else {
                logger.warning("Could not read metadata from datastore")
                completionHandler(.failure(.dataStoreNotReady))
                return
            }

            // Ask delegate if there is any reason to stop process
            let stop = this.dataSyncBegin()
            if stop {
                logger.info("Data synchronisation stop requested before starting the process")
                completionHandler(.failure(.delegateRequestStop))
                return
            }

            // perform a data store task in background
            let perform = this.dataStore.perform(dataStoreContextType) { [weak self] context, save in
                guard let this = self else {
                    // memory issue, must retain the dataSync object somewhere
                    completionHandler(.failure(.retain))
                    return
                }
                let callbackQueue: DispatchQueue = callbackQueue ?? context.queue

                // Get data from this global stamp
                let startStamp = metadata.stampStorage.globalStamp
                let tables = this.tables

                // From remote
                let processCompletion = this.syncProcessCompletionCallBack(completionHandler, context: context, save: save)
                let process = Process(tables: tables, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

                // assert(this.process == nil)
                this.process = process

                // For each table get data from last global stamp
                let configureRequest = this.configureRequest(stamp: startStamp)
                let locked = cancellable.perform {
                    if cancellable.isCancelledUnlocked { // XXX no reentrance for lock
                        completionHandler(.failure(.cancel))
                    } else {

                        for table in this.tables {
                            logger.debug("Start data synchronisation for table \(table.name)")
                            let requestCancellable = this.syncTable(table, callbackQueue: callbackQueue, configureRequest: configureRequest, context: context, save: save)
                            _ = cancellable.appendUnlocked(requestCancellable)  // XXX no reentrance for lock
                        }
                    }
                }
                if !locked {
                    logger.warning("Failed to aquire lock on cancellable object before adding new task to sync table")
                }
            }
            if !perform {
                logger.warning("Cannot get data: context cannot be created on data store")
                completionHandler(.failure(.dataStoreNotReady))
            }
        }
        return cancellable
    }

    func syncProcessCompletionCallBack(_ completionHandler: @escaping SyncCompletionHandler, context: DataStoreContext, save: @escaping DataStore.SaveClosure) -> Process.CompletionHandler {
        return { result in
            switch result {
            case .success(let stamp):
                // store new stamp
                var metadata = self.dataStore.metadata
                metadata?.globalStamp = stamp
                metadata?.lastSync = Date()

                // save data store
                self.trySave(save)

                // call success
                completionHandler(.success(()))
            case .failure(let error):
                if case .onCompletion = self.saveMode {
                    context.rollback()
                }
                completionHandler(.failure(DataSyncError.apiError(error)))
            }
        }
    }

}
