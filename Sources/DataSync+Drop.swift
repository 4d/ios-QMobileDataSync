//
//  DataSync+Drop.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/02/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation

import Moya

import QMobileDataStore
import QMobileAPI

extension DataSync {

    func doDrop(_ context: DataStoreContext, _ completionHandler: SyncCompletionHandler? = nil) -> Bool {
        logger.info("Delete all tables data")
        do {
            for (table, tableInfo) in self.tablesInfoByTable {
                logger.verbose("Data of table \(table.name) will be deleted")
                let deletedCount = try context.delete(in: tableInfo) // XXX maybe catch error by table and try the best effort on others?
                logger.debug("Data of table \(table.name) deleted: \(deletedCount)")
            }
            return true
        } catch {
            completionHandler?(.failure(DataSyncError.error(from: DataStoreError.error(from: error))))
            return false
        }
    }

    /// Drop all data from tables in data store.
    public func drop(in dataStoreContextType: DataStoreContextType = .background,
                     on callbackQueue: DispatchQueue? = nil,
                     _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {

        let cancellable = CancellableComposite() // return value, a cancellable

        // Check if data store initialized.
        let future = initFuture(dataStoreContextType: dataStoreContextType, loadRecordsFromFiles: false, callbackQueue: callbackQueue)

        // On succes launch the sync.
        future.onSuccess { [weak self] in
            guard let this = self else { // memory issue, must retain the dataSync object somewhere
                completionHandler(.failure(.retain))
                return
            }
            let dataStore = this.dataStore
            if var stampStorage = dataStore.metadata?.stampStorage {
                stampStorage.globalStamp = 0
            }
            let perform = dataStore.perform(dataStoreContextType, blockName: "DropTables") { [weak self] context in
                guard let this = self else {
                    completionHandler(.failure(.retain))
                    return
                }
                if this.isCancelled {
                    completionHandler(.failure(.cancel))
                    return
                }
                if this.doDrop(context, completionHandler) {
                    do {
                        try context.commit() // XXX maybe do not commit before loading files
                        try this.loadRecordsFromFile(context: context, tables: Array(this.tablesInfoByTable.keys))
                        completionHandler(.success(()))

                    } catch {
                        completionHandler(.failure(DataSyncError.error(from: error)))
                    }
                }
            }
            if !perform {
                logger.warning("Cannot get data: context cannot be created on data store")
                completionHandler(.failure(.dataStoreNotReady))
            }
        }

        // on failure juste send the error
        future.onFailure { error in
            completionHandler(.failure(error))
        }
        return cancellable
    }

}
