//
//  DataSync+Table.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Result
import Moya

import QMobileAPI
import QMobileDataStore


let kGlobalStamp = "__globalStamp"
let kTableStamp = "stamp"
let defaultStamp: TableStampStorage.Stamp = 0


protocol TableStampStorage {
    typealias Stamp = Int
    func stamp(for table: Table) -> Stamp
    mutating func set(stamp: Stamp, for table: Table)
    var globalStamp: Stamp { get set}
    
}

// Cannot extends protocol, use an intermediate struct
extension DataStoreMetadata {
    var stampStorage: TableStampStorage {
        return DataStoreTableStampStorage(dataStore: self)
    }
}
struct DataStoreTableStampStorage: TableStampStorage {
    var dataStore: DataStoreMetadata
    
    func stamp(for table: Table) -> TableStampStorage.Stamp {
        return dataStore.stamp(for: table)
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table)  {
       dataStore.set(stamp: stamp, for: table)
    }
    var globalStamp: TableStampStorage.Stamp {
        get {
            return dataStore.globalStamp
        }
        set {
            dataStore.globalStamp = newValue
        }
    }
}

extension DataStoreMetadata {
    func stamp(for table: Table) -> TableStampStorage.Stamp {
        return self["\(table.name).\(kTableStamp)"] as? TableStampStorage.Stamp ?? defaultStamp
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table)  {
        self["\(table.name).\(kTableStamp)"] = stamp
    }
    var globalStamp: TableStampStorage.Stamp {
        get {
            return self[kGlobalStamp] as? TableStampStorage.Stamp ?? defaultStamp
        }
        set {
            assert(newValue > 0)
            self[kGlobalStamp] = newValue
        }
    }
}

extension DataSync {

    // Load database structures from
    public typealias TablesCompletionHander = (Result<[Table], APIError>) -> Void
    public func loadTable(_ completionHander: @escaping TablesCompletionHander) -> Cancellable {
        // from files
        logger.info("Read table structures from files")
        var tables = [String: Table]()
        // extension = catalog.json by default
        if let tableStructures = bundle.urls(forResourcesWithExtension: Preferences.jsonTableExtension, subdirectory: nil) {
            for tableStructure in tableStructures {
                /// Parse using QMobileAPI
                if let table = Table(fileURL: tableStructure) {
                    tables[table.name] = table
                } else {
                    logger.warning("File \(tableStructure) do not contains valid table structure")
                }
            }
        }
        logger.info("Table strutures read from files: \(Array(tables.keys))")

        // Check consistency with data store
        var indexedTablesInfo = self.dataStore.tablesInfo.dictionary { $0.name }
        for (name, table) in tables {
            if let tableInfo = indexedTablesInfo[name] {
                assert(table.name == tableInfo.name)
                // TODO could check fields between data store and json

            } else {
                logger.error("Table \(name) not in dataStore model. Check your mobile structures model.")
                // Fatal?
                tables.removeValue(forKey: name)
            }
        }
        logger.info("Table strutures after checking with data store: \(Array(tables.keys))")

        // cache it
        self.tablesByName = tables

        // from remote store?
        return rest.loadTables { result in
            switch result {
            case .success(let remoteTables):
                // Check if all tables accessible on remote target

                #if DEBUG
                    for remoteTable in remoteTables where tables[remoteTable.name] == nil {
                        // normal, not all table displayed in mobile project
                        logger.verbose("Table '\(remoteTable.name) not managed by this mobile project.")
                    }
                #endif
                var indexedRemoteTables = remoteTables.dictionary { $0.name }
                for (name, table) in tables {
                    if let remoteTable = indexedRemoteTables[name] {
                        assert(table.name == remoteTable.name)
                        // TODO check remoteTable and table equals? or compatible ie. all field in table are in remoteTable
                    } else {
                        logger.warning("Table \(name) not accessible on remote 4D Server. Check if you app is up to date")
                        // TODO UPDATE notifify app not up to date with data structure
                    }
                }

                completionHander(.success(Array(tables.values)))
            case .failure(let error):
                logger.warning("Failed to retrieve tables from remote 4D server \(error)")
                // TODO maybe retry later, when network is back
                completionHander(result)
            }
        }
    }

}
