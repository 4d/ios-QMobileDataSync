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

    /// Drop all data from tables in data store.
    public func drop(dataStoreContextType: DataStoreContextType = .background, _ completionHandler: SyncCompletionHandler? = nil) -> Bool {
        let result = self.dataStore.perform(dataStoreContextType, blockName: "DropTable") { context in
            if self.isCancelled {
                completionHandler?(.failure(.cancel))
                return
            }

            logger.info("Delete all tables data")
            do {
                for (table, tableInfo) in self.tablesInfoByTable {
                    logger.verbose("Data of table \(table.name) will be deleted")
                    let deletedCount = try context.delete(in: tableInfo)
                    logger.debug("Data of table \(table.name) deleted: \(deletedCount)")
                }
            } catch {
                completionHandler?(.failure(DataSyncError.error(from: DataStoreError.error(from: error))))
            }
            do {
                try context.commit()

                completionHandler?(.success(()))
            } catch {
                completionHandler?(.failure(DataSyncError.error(from: error)))
            }
        }
        return result
    }

}
