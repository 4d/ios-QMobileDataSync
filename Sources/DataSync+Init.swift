//
//  DataSync+Init.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences
import Combine
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
        /// One record.
        case record(String, Any)

        // use cache file before adding or updating records?
        // temporary according to operation, could be changed later (as option)
        var useCache: Bool {
            switch self {
            case .sync:
                return false
            case .reload:
                return true
            case .record:
                return false
            }
        }

        public var description: String {
            switch self {
            case .sync:
                return "synchronization"
            case .reload:
                return "reloading"
            case .record(let tableName, let primaryKeyValue):
                return "record(\(tableName), \(primaryKeyValue)) synchronization"
            }
        }

        public var verb: String {
            switch self {
            case .sync:
                return "synchronized"
            case .reload:
                return "reloaded"
            case .record:
                return "one record synchronized"
            }
        }
    }

    public typealias SyncResult = Result<Void, DataSyncError>
    public typealias SyncCompletionHandler = (SyncResult) -> Void
    public typealias SyncFuture = AnyPublisher<Void, DataSyncError>
    public typealias SyncTableFuture = Future<[Table], DataSyncError>

    /// check data store loaded, and tables structures loaded
    public func initFuture(dataStoreContextType: DataStoreContextType = .background,
                           loadRecordsFromFiles: Bool = true,
                           callbackQueue: DispatchQueue? = nil) -> SyncFuture {

        // Load data store if necessary
        var sequence: [SyncFuture] = []
        if Prephirences.DataSync.firstSync && Prephirences.DataSync.dataStoreDrop {
            let dsLoad: SyncFuture = dataStore.drop().flatMap {
                return self.dataStore.load()
                }.mapError { dataStoreError in
                    logger.warning("Could not drop or load data store \(dataStoreError)")
                    return .dataStoreError(dataStoreError)
                }.eraseToAnyPublisher()
            sequence.append(dsLoad)

        } else {
            let dsLoad: SyncFuture = dataStore.load().mapError { dataStoreError in
                logger.warning("Could not load data store \(dataStoreError)")
                return .dataStoreError(dataStoreError)
            }.eraseToAnyPublisher()
            sequence.append(dsLoad)
        }

        // Load table if needed
        let loadTable: SyncTableFuture = self.loadTable(on: callbackQueue)
        /// check if there is table
        let checkTable: SyncFuture = loadTable.result { (tables: [Table]) -> SyncResult in
              return self.tables.isEmpty ? .failure(.noTables) : .success(())
        }
        sequence.append(checkTable)

        if loadRecordsFromFiles && Prephirences.DataSync.firstSync {
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

    private func loadRecordsFromFileFuture(dataStoreContextType: DataStoreContextType, previous: SyncTableFuture) -> SyncFuture {
        return previous.flatMap { (tables: [Table]) -> SyncFuture in

            return self.dataStore.perform(dataStoreContextType, blockName: "LoadEmbeddedData").result { (dataStoreContext: DataStoreContext) -> Result<Void, DataStoreError> in
                assert(dataStoreContext.type == dataStoreContextType)

                logger.info("Load table data from embedded data files")
                self.dataSyncWillLoad(tables)
                do {
                    try self.loadRecordsFromFile(context: dataStoreContext, tables: tables)
                    self.dataSyncDidLoad(tables)
                    return .success(())
                } catch {
                    return .failure(DataStoreError.error(from: error))
                }
            }.mapError { (error: DataStoreError) -> DataSyncError in
                    logger.warning("Could not import records into data store \(error)")
                    return DataSyncError.dataStoreError(error)
            }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

    private func deleteRecordsFuture(dataStoreContextType: DataStoreContextType, previous: SyncTableFuture) -> SyncFuture {
        return previous.flatMap { (tables: [Table]) -> SyncFuture in

            return self.dataStore.perform(dataStoreContextType).result { (dataStoreContext: DataStoreContext) -> Result<Void, DataStoreError> in
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
            }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
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
