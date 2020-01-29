//
//  DataSync+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences

import Moya
import FileKit
import BrightFutures

import QMobileAPI
import QMobileDataStore

// MARK: Sync
extension DataSync {

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
        var future: SyncFuture = initFuture(dataStoreContextType: dataStoreContextType, callbackQueue: callbackQueue)

        future = future.flatMap { _ in
            return self.loadRemoteTable().asVoid()
        }

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
        guard let stampStorage = self.dataStore.metadata?.stampStorage else {
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
            let startStamp = stampStorage.globalStamp
            let tables = this.tables

            logger.info("...\(operation.description) with stamp \(startStamp)")

            // From remote
            let tempPath: Path = .userTemporary

            if operation.useCache {
                try? this.deleteRecordsCacheFile()
            }

            /// Create process and callback
            let processCompletion = this.syncProcessCompletionCallBack(in: context, operation: operation, startStamp: startStamp, tempPath: tempPath, completionHandler)
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
        guard var stampStorage = self.dataStore.metadata?.stampStorage else {
            logger.warning("Could not read metadata from datastore when starting \(operation.description)")
            completionHandler(.failure(.dataStoreNotReady))
            return
        }
        stampStorage.globalStamp = 0 // start from 0

        // Ask delegate if there is any reason to stop process
        let stop = self.dataSyncDidBegin(operation)
        if stop {
            logger.info("Data \(operation.description) stop requested before starting the process")
            completionHandler(.failure(.delegateRequestStop))
            return
        }

        // Get data from this global stamp
        let startStamp = stampStorage.globalStamp
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

    func deleteRecords(_ deletedRecords: [DeletedRecord], in context: DataStoreContext) {
        for deletedRecord in deletedRecords {
            guard let table = table(for: deletedRecord.tableName), let tableInfo = self.tablesInfoByTable[table] else {
                logger.verbose("Unknown record \(deletedRecord). Not managed table.")
                continue
            }
            do {
                let predicate = table.predicate(forDeletedRecord: deletedRecord)
                let result = try context.delete(in: tableInfo.name, matching: predicate)
                if result > 0 {
                    logger.verbose("Record defined by \(deletedRecord) has been deleted")
                } else {
                    logger.debug("Failed to delete \(deletedRecord). Maybe already deleted.")
                }
            } catch {
                logger.warning("Failed to delete \(deletedRecord). Maybe already deleted \(error)")
            }
        }
    }

    func syncDeletedRecods(in context: DataStoreContext,
                           startStamp: TableStampStorage.Stamp,
                           endStamp: TableStampStorage.Stamp,
                           callbackQueue: DispatchQueue? = nil,
                           progress: APIManager.ProgressHandler? = nil) -> Future<[DeletedRecord], APIError> {

        // First get drom DeleteRecord table
        var configure: APIManager.ConfigureRecordsRequest? = { request in
            request.filter("\(DeletedRecordKey.stamp) >= \(startStamp) AND \(DeletedRecordKey.stamp) <= \(endStamp)")  // synchronized interval
        }
        let future = self.apiManager.deletedRecordPage(configure: configure, callbackQueue: callbackQueue, progress: progress).map { page in
            return page.records.compactMap { $0.deletedRecord }
        }

        if Prephirences.DataSync.deletedByFilter {
            // then for all table with filters. in fact some records could now be out of filter scope.
            configure = { request in
                request.filter("\(kGlobalStamp) >= \(startStamp) AND \(kGlobalStamp) <= \(endStamp)")  // synchronized interval
            }
            let futures = [future] + deletedRecordsDueToFilter(in: context, configure: configure)

            // Merge and flattenize all task result
            return futures.sequence().flatMap { (list: [[DeletedRecord]]) -> Result<[DeletedRecord], APIError> in
                return .success(list.flatMap { $0 })
            }
        }
        return future
    }

    /// Synchronize removed record due to filter only
    func deletedRecordsDueToFilter(in context: DataStoreContext, configure: APIManager.ConfigureRecordsRequest? = nil) -> [Future<[DeletedRecord], APIError>] {
        // work only on tables with filter
        let tablesWithFilter = tablesInfoByTable.filter { $1.filter != nil }

        // Find the updated or created records. This records must not be deleted, because we get it with filter
        let updatedRecords: [Record] = context.insertedRecords + context.updatedRecords
        let updatedRecordsByTable: [String: [Record]] = updatedRecords.dictionaryBy { $0.tableName }

        var futures: [Future<[DeletedRecord], APIError>] = []
        for (table, tableInfo) in tablesWithFilter {
            // Get table information
            guard let primaryKey = tableInfo.primaryKeyFieldInfo?.originalName else {
                continue
            }
            let tableName = table.name
            let updatedRecords: [Record] = updatedRecordsByTable[tableName] ?? [] // maybe no one visible for this table
            let updatedRecordPrimaryKeys = updatedRecords.compactMap { $0.primaryKeyValue }

            // Make the request to get records
            let future = APIManager.instance.recordPage(tableName: tableName, attributes: [primaryKey], configure: configure).map { (page: Page) -> [DeletedRecord] in
                let records = page.records
                // Filter records that must not be deleted, ie. the ones pending to be modified by synchro
                let deletedRecords: [DeletedRecord] = records.compactMap { recordJSON in
                    let json = recordJSON.json
                    let primaryKey = "\(json[primaryKey].rawValue)"
                    let hasBeenUpdated = updatedRecordPrimaryKeys.contains { updatedPrimaryKey in
                        return ("\(updatedPrimaryKey)" == primaryKey) // use string to compare, maybe could be faster if not converted
                    }
                    if hasBeenUpdated {
                        return nil // do not deleted
                    }
                    let stamp = json[kGlobalStamp].doubleValue
                    return DeletedRecord(primaryKey: "\(primaryKey)", tableNumber: nil, tableName: tableName, stamp: stamp)
                }
                return deletedRecords
            }
            futures.append(future)
        }
        return futures
    }

    /// Function called after all table has been synchronised
    func syncProcessCompletionCallBack(in context: DataStoreContext,
                                       operation: DataSync.Operation,
                                       startStamp: TableStampStorage.Stamp,
                                       tempPath: Path,
                                       _ completionHandler: @escaping SyncCompletionHandler) -> Process.CompletionHandler {
        return { result in
            if self.isCancelled {
                completionHandler(.failure(.cancel))
                return
            }
            switch result {
            case .success(let stamp):
                self.syncProcessCompletionSuccess(in: context, operation: operation, startStamp: startStamp, endStamp: stamp, completionHandler)
            case .failure(let error):
                if case .onCompletion = self.saveMode {
                    context.rollback()
                }
                completionHandler(.failure(DataSyncError.apiError(error)))
            }
        }
    }

    func syncProcessCompletionSuccess(in context: DataStoreContext,
                                      operation: DataSync.Operation,
                                      startStamp: TableStampStorage.Stamp,
                                      endStamp: TableStampStorage.Stamp,
                                      _ completionHandler: @escaping SyncCompletionHandler) {
        let future = self.syncDeletedRecods(in: context, startStamp: startStamp, endStamp: endStamp)
        future.onSuccess { deletedRecords in

            self.deleteRecords(deletedRecords, in: context)

            // store new stamp
            if var stampStorage = self.dataStore.metadata?.stampStorage {
                stampStorage.globalStamp = endStamp
                stampStorage.lastSync = Date()
            }
            logger.info("Data \(operation.description) end with stamp \(endStamp)")

            // save data store
            do {
                try context.commit()

                // call success
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(DataSyncError.error(from: error)))
            }
        }
        future.onFailure { error in
            if let restErrors = error.restErrors, restErrors.match(.entity_not_found) {
                logger.error("The table \(DeletedRecordKey.entityName) do not exist. Deleted record will not be removed from this mobile application. Please update your struture")

                // Until we change decision, we go on without the table and save the synchronization...
                // store new stamp
                if var stampStorage = self.dataStore.metadata?.stampStorage {
                    stampStorage.globalStamp = endStamp
                    stampStorage.lastSync = Date()
                }
                logger.info("Data \(operation.description) end with stamp \(endStamp) but without removing potential deleted records")

                // save data store
                do {
                    try context.commit()

                    // call success
                    completionHandler(.success(()))
                } catch {
                    completionHandler(.failure(DataSyncError.error(from: error)))
                }

            } else {
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
