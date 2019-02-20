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

    /// Type of data sync operation
    public enum Operation {
        /// Incremental.
        case sync
        /// Total.
        case reload

        // use cache file before adding or updating records?
        // temporary according to opeation, could be changed later (as option)
        var useCache: Bool {
            switch self {
            case .sync:
                return false
            case .reload:
                return true
            }
        }

        var description: String {
            switch self {
            case .sync:
                return "synchronization"
            case .reload:
                return "reloading"
            }
        }
    }

    public typealias SyncResult = Result<Void, DataSyncError>
    public typealias SyncCompletionHandler = (SyncResult) -> Void
    public typealias SyncFuture = Future<Void, DataSyncError>

    /// check data store loaded, and tables structures loaded
    public func initFuture(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil) -> SyncFuture {

        // Load data store if necessary
        var sequence: [SyncFuture] = []
        if Prephirences.DataSync.firstSync && Prephirences.DataSync.dataStoreDrop {

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
        let loadTable: Future<[Table], DataSyncError> = self.loadTable(on: callbackQueue)
        /// check if there is table
        let checkTable: SyncFuture = loadTable.flatMap { (tables: [Table]) -> SyncResult in
              return self.tables.isEmpty ? .failure(.noTables) : .success(())
        }
        sequence.append(checkTable)

        let firstStart = Prephirences.DataSync.firstSync // maybe add other things like no metadata
        if firstStart {
            Prephirences.DataSync.firstSync = false

            // from file
            if Prephirences.DataSync.dataFromFile {
                let loadFromFiles = loadRecordsFromFileFuture(dataStoreContextType: dataStoreContextType, previous: loadTable)
                sequence.append(loadFromFiles)
            }

        } else if Prephirences.DataSync.deleteRecordsAtStart {
            let removeTableRecords = deleteRecordsFuture(dataStoreContextType: dataStoreContextType, previous: loadTable)
            sequence.append(removeTableRecords)
        }

        return sequence.sequence().asVoid()
    }

    private func loadRecordsFromFileFuture(dataStoreContextType: DataStoreContextType, previous: Future<[Table], DataSyncError>) -> SyncFuture {
        return previous.flatMap { (tables: [Table]) -> SyncFuture in

            return self.dataStore.perform(dataStoreContextType, blockName: "LoadEmbeddedData").flatMap { (dataStoreContext: DataStoreContext) -> Result<Void, DataStoreError> in
                assert(dataStoreContext.type == dataStoreContextType)

                logger.info("Load table data from embedded data files")
                self.dataSyncWillLoad(tables)
                do {
                    let stamps = try self.loadRecordsFromFile(context: dataStoreContext, tables: tables)
                    self.dataSyncDidLoad(tables)

                    if var stampStorage = self.dataStore.metadata?.stampStorage {
                        var globalStamp = 0
                        for (_, stamp) in stamps {
                           // stampStorage.set(stamp: stamp, for: table)
                            if stamp != 0 && stamp < globalStamp { // take the min but not zero (all stamps must be equal or zero, but in case of)
                                globalStamp = stamp
                            }
                        }
                        stampStorage.globalStamp = globalStamp
                    }
                    return .success(())
                } catch {
                    return .failure(DataStoreError.error(from: error))
                }
                }.mapError { error in
                    logger.warning("Could not import records into data store \(error)")
                    return DataSyncError.dataStoreError(error)
            }
        }
    }

    private func deleteRecordsFuture(dataStoreContextType: DataStoreContextType, previous: Future<[Table], DataSyncError>) -> SyncFuture {
        return previous.flatMap { (tables: [Table]) -> SyncFuture in

            return self.dataStore.perform(dataStoreContextType).flatMap { (dataStoreContext: DataStoreContext) -> Result<Void, DataStoreError> in
                assert(dataStoreContext.type == dataStoreContextType)
                // delete all table data
                logger.info("Delete all tables data")
                do {
                    let indexedTablesInfo = self.dataStore.tablesInfo.dictionary { $0.originalName }
                    for table in self.tables {
                        if let tableInfo = indexedTablesInfo[table.name] {
                            let bool = try dataStoreContext.delete(in: tableInfo)
                            logger.debug("Data of table \(table.name) deleted: \(bool)")
                        } else {
                            logger.warning("Data of table \(table.name) could not be deleted. Could not found in data store")
                            logger.debug("Dump of table info\(indexedTablesInfo)")
                        }
                    }
                    try dataStoreContext.commit()
                    return .success(())
                } catch {
                    return .failure(DataStoreError.error(from: error))
                }

                }.mapError { dataStoreError in
                    logger.warning("Could not delete records from data store \(dataStoreError)")
                    return DataSyncError.dataStoreError(dataStoreError)
            }
        }
    }

    /*public func loadTableDataFronmBundleFiles(dataStoreContextType: DataStoreContextType = .background, completionHandler:  @escaping (Result<Void, DataStoreError>) -> Void) -> Bool {
       return self.dataStore.perform(dataStoreContextType) { dataStoreContext in
            logger.info("Load table data from embedded data files")
            do {
                try self.loadRecordsFromFile(context: dataStoreContext)
                completionHandler(.success(()))

            } catch let dataStoreError as DataStoreError {
                completionHandler( .failure(dataStoreError))
            } catch {
                completionHandler(.failure(DataStoreError(error)))
            }
        }
    }*/

}
