//
//  DataSync+SyncRecord.swift
//  QMobileDataSync
//
//  Created by phimage on 28/12/2020.
//  Copyright © 2020 Eric Marchand. All rights reserved.
//

import Foundation
import Prephirences

import Moya
import FileKit
import Combine

import QMobileAPI
import QMobileDataStore

// MARK: Sync
extension DataSync {

    // MARK: SyncRecord
    func doSyncRecord(tableName: String,
                      primaryKeyValue: Any,
                      in contextType: DataStoreContextType = .background,
                      on callbackQueue: DispatchQueue? = nil,
                      cancellable: CancellableComposite,
                      completionHandler: @escaping SyncCompletionHandler) {
        let operation: Operation = .record(tableName, primaryKeyValue)
        logger.info("Start data \(operation.description)")
        // Ask delegate if there is any reason to stop process
        let stop = self.dataSyncDidBegin(operation)
        if stop {
            logger.info("Data \(operation.description) stop requested before starting the process")
            completionHandler(.failure(.delegateRequestStop))
            return
        }

        // perform a data store task in background
        let perform = self.dataStore.perform(contextType, blockName: "\(tableName):\(primaryKeyValue)") { [weak self] context in
            guard let this = self else {
                // memory issue, must retain the dataSync object somewhere
                completionHandler(.failure(.retain))
                return
            }
            let callbackQueue: DispatchQueue = callbackQueue ?? context.queue

            guard let table = this.tables.filter({$0.name == tableName}).first,
                  let tableInfo = this.tablesInfoByTable[table] else {

                completionHandler(.failure(.dataStoreNotReady)) // XXX maybe table not exist, find a better message
                return
            }
            let initializer = DataSyncBuilder(table: table, tableInfo: tableInfo, context: context)
            let attributes = this.getAttributes(table)
            let cancellableRequest = this.apiManager.loadRecord(table: table, key: "\(primaryKeyValue)", attributes: attributes, initializer: initializer, queue: callbackQueue) { result in
                switch result {
                case .success(let importedRecord):
                    logger.info("Record \(tableName) with primary key \(primaryKeyValue) imported")
                    logger.verbose("\(importedRecord)")
                    do {
                        try context.commit()
                        completionHandler(.success(()))
                    } catch {
                        logger.warning("Failed to commit record \(tableName) with primary key \(primaryKeyValue): \(error)")
                        completionHandler(.failure(.dataStoreError(DataStoreError.error(from: error))))
                    }
                case .failure(let error):
                    logger.warning("Failed to import record \(tableName) with primary key \(primaryKeyValue): \(error)")
                    completionHandler(.failure(.apiError(error)))
                }
            }
            cancellable.append(cancellableRequest)
        }
        if !perform {
            logger.warning("Cannot get data: context cannot be created on data store")
            completionHandler(.failure(.dataStoreNotReady))
        }
    }
}
