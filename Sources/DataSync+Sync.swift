//
//  DataSync+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences
import Result
import Moya
import FileKit

import QMobileAPI
import QMobileDataStore

// MARK: Sync
extension DataSync {

    /// Reload the data. ie drop data and sync.
    public func reload(in contextType: DataStoreContextType = .background,
                       on callbackQueue: DispatchQueue? = nil,
                       _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {
        return sync(operation: .reload,
                    in: contextType,
                    on: callbackQueue,
                    completionHandler)
    }

    /// Synchronize the data.
    public func sync(operation: DataSync.Operation = .sync,
                     in dataStoreContextType: DataStoreContextType = .background,
                     on callbackQueue: DispatchQueue? = nil,
                     _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {
        if !isCancelled {
            cancel()  // XXX maybe wait...
        }

        let cancellable = CancellableComposite() // return value, a cancellable
        self.dataSyncWillBegin(operation, cancellable: cancellable)

        // Manage delegate completion event
        let completionHandler: SyncCompletionHandler = wrap(operation, completionHandler: completionHandler)

        // Check if data store initialized.
        let future = initFuture(dataStoreContextType: dataStoreContextType, callbackQueue: callbackQueue)
        // On succes launch the sync.
        future.onSuccess { [weak self] in
            guard let this = self else { // memory issue, must retain the dataSync object somewhere
                completionHandler(.failure(.retain))
                return
            }
            // TODO try to factorize operation sync and reload #105176
            switch operation {
            case .sync:
                this.doSync(operation: operation,
                            in: dataStoreContextType,
                            on: callbackQueue,
                            cancellable: cancellable,
                            completionHandler: completionHandler)
            case .reload:
                this.doReload(operation: operation,
                              in: dataStoreContextType,
                              on: callbackQueue,
                              cancellable: cancellable,
                              completionHandler: completionHandler)
            }

        }
        // on failure juste send the error
        future.onFailure { error in
            completionHandler(.failure(error))
        }
        return cancellable
    }

    private func doSync(operation: DataSync.Operation,
                        in contextType: DataStoreContextType = .background,
                        on callbackQueue: DispatchQueue? = nil,
                        cancellable: CancellableComposite,
                        completionHandler: @escaping SyncCompletionHandler) {
        logger.info("Start data \(operation.description)")

        // Check if metadata could be read
        guard let metadata = self.dataStore.metadata else {
            logger.warning("Could not read metadata from datastore when starting \(operation.description)")
            completionHandler(.failure(.dataStoreNotReady))
            return
        }

        // Ask delegate if there is any reason to stop process
        let stop = self.dataSyncDidBegin(operation)
        if stop {
            logger.info("Data \(operation.description) stop requested before starting the process")
            completionHandler(.failure(.delegateRequestStop))
            return
        }

        // perform a data store task in background
        let perform = self.dataStore.perform(contextType, blockName: "\(operation)") { [weak self] context in
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
            let tempPath: Path = .userTemporary

            if operation.useCache {
                try? this.deleteRecordsCacheFile()
            }

            /// Create process and callback
            let processCompletion = this.syncProcessCompletionCallBack(in: context, operation: operation, tempPath: tempPath, completionHandler)
            let process = Process(tables: tables,
                                  startStamp: startStamp,
                                  cancellable: cancellable,
                                  completionHandler: processCompletion)
            this.process = process

            // For each table get data from last global stamp
            let locked = cancellable.perform {
                if cancellable.isCancelledUnlocked { // XXX no reentrance for lock
                    completionHandler(.failure(.cancel))
                } else {

                    for table in this.tables {
                        logger.debug("Start data \(operation.description) for table \(table.name)")

                        let progress: APIManager.ProgressHandler = { progress in }
                        let requestCancellable = this.syncTable(table,
                                                                at: startStamp,
                                                                in: tempPath,
                                                                operation: operation,
                                                                callbackQueue: callbackQueue,
                                                                progress: progress,
                                                                context: context)
                        _ = cancellable.appendUnlocked(requestCancellable)  // XXX no reentrance for lock
                    }
                }
            }
            if !locked {
                logger.warning("Failed to aquire lock on cancellable object before adding new task to \(operation) tables data")
            }
        }
        if !perform {
            logger.warning("Cannot get data: context cannot be created on data store")
            completionHandler(.failure(.dataStoreNotReady))
        }
    }

    func doReload(operation: DataSync.Operation,
                  in contextType: DataStoreContextType = .background,
                  on callbackQueue: DispatchQueue? = nil,
                  cancellable: CancellableComposite,
                  completionHandler: @escaping SyncCompletionHandler) {
        logger.info("Start data \(operation.description)")

        // Check if metadata could be read
        guard var metadata = self.dataStore.metadata else {
            logger.warning("Could not read metadata from datastore when starting \(operation.description)")
            completionHandler(.failure(.dataStoreNotReady))
            return
        }

        // Ask delegate if there is any reason to stop process
        let stop = self.dataSyncDidBegin(operation)
        if stop {
            logger.info("Data \(operation.description) stop requested before starting the process")
            completionHandler(.failure(.delegateRequestStop))
            return
        }

        // Get data from this global stamp
        let startStamp = 0 // metadata.stampStorage.globalStamp
        let tables = self.tables

        // From remote
        let tempPath: Path = .userTemporary

        if operation.useCache {
            try? self.deleteRecordsCacheFile()
        }

        /// Create process and callback
        let processCompletion = self.reloadProcessCompletionCallBack(in: contextType, operation: operation, tempPath: tempPath, completionHandler)
        let process = Process(tables: tables,
                              startStamp: startStamp,
                              cancellable: cancellable,
                              completionHandler: processCompletion)
        self.process = process

        let locked = cancellable.perform {
            if cancellable.isCancelledUnlocked {
                completionHandler(.failure(.cancel))
            } else {
                let callbackQueue: DispatchQueue = callbackQueue ?? contextType.queue

                for table in self.tables {
                    logger.debug("Start data \(operation.description) for table \(table.name)")

                    let progress: APIManager.ProgressHandler = { progress in }
                    let requestCancellable = self.reloadTable(table,
                                                              in: tempPath,
                                                              operation: operation,
                                                              callbackQueue: callbackQueue,
                                                              progress: progress)
                    _ = cancellable.appendUnlocked(requestCancellable)
                }
            }
        }
        if !locked {
            logger.warning("Failed to aquire lock on cancellable object before adding new task to \(operation) tables data")
        }
    }

    // MARK: process completion callback

    func syncProcessCompletionCallBack(in context: DataStoreContext, operation: DataSync.Operation, tempPath: Path, _ completionHandler: @escaping SyncCompletionHandler) -> Process.CompletionHandler {
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
                logger.info("Data \(operation.description) end with stamp \(stamp)")

                // save data store
                do {
                    try context.commit()

                    // call success
                    completionHandler(.success(()))
                } catch {
                    completionHandler(.failure(DataSyncError.error(from: error)))
                }
            case .failure(let error):
                if case .onCompletion = self.saveMode {
                    context.rollback()
                }
                completionHandler(.failure(DataSyncError.apiError(error)))
            }
        }
    }

    func reloadProcessCompletionCallBack(in contextType: DataStoreContextType, operation: DataSync.Operation, tempPath: Path, _ completionHandler: @escaping SyncCompletionHandler) -> Process.CompletionHandler {
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
                logger.info("Data \(operation.description) end with stamp \(stamp)")

                // move file from download path to cache path
                do {
                    try self.moveToCache(from: tempPath)
                } catch {
                    completionHandler(.failure(DataSyncError.dataCache(error)))
                    return
                }

                let result = self.dataStore.perform(contextType, blockName: "\(operation)") { [weak self] context in
                    guard let this = self else {
                        completionHandler(.failure(.retain))
                        return
                    }
                    if this.isCancelled {
                        completionHandler(.failure(.cancel))
                        return
                    }

                    logger.info("Delete all tables data before loading from files")
                    _ = this.doDrop(context, completionHandler) // XXX if failed, go on?

                    logger.info("Load table data from cache data files")
                    do {
                        try this.loadRecordsFromCache(context: context)
                        logger.debug("Load table data from cache data files success")

                        // finally flush the context.
                        try context.commit()

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

}
