//
//  DataSync+Init.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Result
import Prephirences
import BrightFutures
import Moya

import QMobileDataStore
import QMobileAPI

extension DataSync {

    /// check data store loaded, and tables structures loaded
    public func initFuture(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil) -> SyncFuture {
        var sequence: [SyncFuture] = []

        // Load data store if necessary
        /*dataStore.drop {
         dataStore.load {
         
         }*/

        if Preferences.firstSync && Prephirences.sharedInstance.bool(forKey: "dataSync.dataStoreDrop") {

            let dsLoad: SyncFuture = dataStore.drop().flatMap {
                return self.dataStore.load()
                }.mapError { dataStoreError in
                    logger.warning("Could not drop or load data store \(dataStoreError)")
                    return .dataStoreError(dataStoreError)
            }
            sequence.append(dsLoad)

        } else {
            let dsLoad: SyncFuture = dataStore.load().mapError { dataStoreError in
                logger.warning("Could not load data store \(dataStoreError)")
                return .dataStoreError(dataStoreError)
            }
            sequence.append(dsLoad)
        }

        // Load table if needed
        let loadTable: Future<[Table], DataSyncError> = self.loadTable(callbackQueue: callbackQueue)
        /// check if there is table
        let checkTable: SyncFuture = loadTable.flatMap { (tables: [Table]) -> SyncResult in
            if self.tables.isEmpty {
                return .failure(.noTables)
            }
            return .success()
        }
        sequence.append(checkTable)

        // from file
        if Preferences.firstSync {
            if Preferences.dataFromFile {

                let loadFromFiles: SyncFuture = loadTable.flatMap { (_: [Table]) -> SyncFuture in

                    return self.dataStore.perform(dataStoreContextType).flatMap { (dataStoreContext: DataStoreContext, save: @escaping () throws -> Void) -> Result<Void, DataStoreError> in
                        assert(dataStoreContext.type == dataStoreContextType)

                        logger.info("Load table data from embedded data files")
                        do {
                            try self.loadRecordsFromFile(context: dataStoreContext, save: save)
                            return .success()
                        } catch let dataStoreError as DataStoreError {
                            return .failure(dataStoreError)
                        } catch {
                            return .failure(DataStoreError(error))
                        }
                        }.mapError { error in
                            logger.warning("Could not import records into data store \(error)")
                            return DataSyncError.dataStoreError(error)
                    }
                }
                sequence.append(loadFromFiles)

            }
            Preferences.firstSync = false
        }

        if !Preferences.firstSync {
            if Preferences.deleteRecords {
                // if must removes all the data by tables
                let removeTableRecords: SyncFuture = loadTable.flatMap { (tables: [Table]) -> SyncFuture in

                    return self.dataStore.perform(dataStoreContextType).flatMap { (dataStoreContext: DataStoreContext, save: () throws -> Void) -> Result<Void, DataStoreError> in
                        assert(dataStoreContext.type == dataStoreContextType)
                        // delete all table data
                        logger.info("Delete all tables data")
                        do {
                            for table in self.tables {
                                let bool = try dataStoreContext.delete(in: table)
                                logger.debug("Data of table \(table.name) deleted: \(bool)")
                            }
                            try save()
                            return .success()
                        } catch let dataStoreError as DataStoreError {
                            return .failure(dataStoreError)
                        } catch {
                            return .failure(DataStoreError(error))
                        }

                        }.mapError { dataStoreError in
                            logger.warning("Could not delete records from data store \(dataStoreError)")
                            return DataSyncError.dataStoreError(dataStoreError)
                    }
                }
                sequence.append(removeTableRecords)
            }
        }

        return sequence.sequence().asVoid()
    }

    public func loadTableDataFronmBundleFiles(dataStoreContextType: DataStoreContextType = .background, completionHandler:  @escaping (Result<Void, DataStoreError>) -> Void) -> Bool {
       return self.dataStore.perform(dataStoreContextType) { dataStoreContext, save in
            logger.info("Load table data from embedded data files")
            do {
                try self.loadRecordsFromFile(context: dataStoreContext, save: save)
                completionHandler(.success())
                
                
            } catch let dataStoreError as DataStoreError {
                completionHandler( .failure(dataStoreError))
            } catch {
                completionHandler(.failure(DataStoreError(error)))
            }
        }
    }

}
