//
//  DataStore+Reload.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 28/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences
import Result
import Moya
import FileKit

import QMobileAPI
import QMobileDataStore

extension DataSync {

    /// Reload the data. ie drop data and sync.
    public func reload(dataStoreContextType: DataStoreContextType = .background,
                       callbackQueue: DispatchQueue? = nil,
                       _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {
        return sync(operation: .reload,
                    dataStoreContextType: dataStoreContextType,
                    callbackQueue: callbackQueue,
                    completionHandler)
    }

    func doReload(operation: DataSync.Operation, dataStoreContextType: DataStoreContextType, callbackQueue: DispatchQueue? = nil, cancellable: CancellableComposite, completionHandler: @escaping SyncCompletionHandler) {
        logger.info("Start data reloading")

        // Ask delegate if there is any reason to stop process
        let stop = self.dataSyncDidBegin(operation)
        if stop {
            logger.info("Data reloading stop requested before starting the process")
            completionHandler(.failure(.delegateRequestStop))
            return
        }

        // Get data from this global stamp
        let startStamp = 0
        let tables = self.tables

        // From remote
        let tempPath: Path = .userTemporary

        try? self.deleteRecordsCacheFile()

        /// Create process and callback
        let processCompletion = self.reloadProcessCompletionCallBack(dataStoreContextType: dataStoreContextType, tempPath: tempPath, completionHandler)
        let process = Process(tables: tables,
                              startStamp: startStamp,
                              cancellable: cancellable,
                              completionHandler: processCompletion)
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

}
