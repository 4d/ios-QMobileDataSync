//
//  DataSync+Drop.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/02/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation

import QMobileDataStore

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
            return true
        }
    }

    /// Drop all data from tables in data store.
    public func drop(dataStoreContextType: DataStoreContextType = .background, _ completionHandler: SyncCompletionHandler? = nil) -> Bool {
       return self.dataStore.perform(dataStoreContextType, blockName: "DropTable") { [weak self] context in
            guard let this = self else {
                completionHandler?(.failure(.retain))
                return
            }
            if this.isCancelled {
                completionHandler?(.failure(.cancel))
                return
            }
            _ = this.doDrop(context, completionHandler)
            do {
                try context.commit()
                completionHandler?(.success(()))
            } catch {
                completionHandler?(.failure(DataSyncError.error(from: error)))
            }
        }
    }

}
