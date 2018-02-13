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

extension DataSync {
    /// Load table structures from embedded files
    private func loadTableFromEmbeddedFiles() -> [Table] {
        // from files
        logger.info("Read table structures from files")
        var tables = [Table]()
        // extension = catalog.json by default
        if let tableStructures = bundle.urls(forResourcesWithExtension: Preferences.jsonTableExtension, subdirectory: nil) {
            for tableStructure in tableStructures {
                /// Parse using QMobileAPI
                if let table = Table(fileURL: tableStructure) {
                    tables.append(table)
                } else {
                    logger.warning("File \(tableStructure) do not contains valid table structure")
                }
            }
        }
        logger.info("Table strutures read from files: \(tables.map { $0.name })")
        return tables
    }

    private func stripTablesNotInDataStore(_ tables: [String: Table]) -> [String: Table] {
        // Check consistency with data store
        var indexedTablesInfo = self.dataStore.tablesInfo.dictionary { $0.originalName }
        var tables = tables
        for (name, table) in tables {
            if let tableInfo = indexedTablesInfo[table.name] {
                assert(table.name == tableInfo.originalName)
                // XXX could check fields between data store and json

            } else {
                logger.warning("Table \(table.name) not in dataStore model. Check your mobile structures model.")
                tables.removeValue(forKey: name)
            }
        }
        logger.info("Table strutures after checking with data store: \(Array(tables.keys))")
        return tables
    }

    // Load database structures from
    public typealias TablesCompletionHander = (Result<[Table], DataSyncError>) -> Void
    public func loadTable(callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) {
        let tableInfo = self.dataStore.tablesInfo

        let infos: [(Table, DataStoreTableInfo)] = tableInfo.map { ($0.api, $0) }
        self.tablesInfoByTable = Dictionary(infos)

        logger.info("Table strutures from data store: \(Array(self.tables.map { $0.name }))")

        if let callbackQueue = callbackQueue {
            callbackQueue.async {
                completionHander(.success(self.tables))
            }
        } else {
            completionHander(.success(self.tables))
        }
    }

    public func loadRemoteTable(callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) -> Cancellable {
        if self.tables.isEmpty {
            self.loadTable { _ in
                // no really asynchrone; if asynchone must use Future
            }
        }
        // from remote store?
        return rest.loadTables(callbackQueue: callbackQueue) { result in
            switch result {
            case .success(let remoteTables):
                // Check if all tables accessible on remote target

                #if DEBUG
                    let managedNames = self.tables.map { $0.name }
                    for remoteTable in remoteTables where !managedNames.contains(remoteTable.name) {
                        // normal, not all table displayed in mobile project
                        logger.verbose("Table '\(remoteTable.name) not managed by this mobile project.")
                    }
                #endif
                var removeTablesByName = remoteTables.dictionary { $0.name }
                var missingTables = [Table]()
                var missingAttributes = [Table: [Attribute]]()
                for table in self.tables {
                    if let remoteTable = removeTablesByName[table.name] {
                        assert(table.name == remoteTable.name)

                        let remoteAttributesByName = remoteTable.attributes
                        // check remoteTable and table equals? or compatible ie. all field in table are in remoteTable
                        for (name, attribute) in table.attributes where remoteAttributesByName[name] == nil {
                            if missingAttributes[table] == nil {
                                missingAttributes[table] = [attribute]
                            } else {
                                missingAttributes[table]?.append(attribute)
                            }
                        }

                    } else {
                        missingTables.append(table)
                        logger.warning("Table \(table.name) not accessible on remote 4D Server. Check if you app is up to date")
                    }
                }
                if !missingTables.isEmpty {
                    // notifify app not up to date with data structure
                    completionHander(.failure(.missingRemoteTables(missingTables)))
                } else if !missingAttributes.isEmpty {
                    // notifify app not up to date with data structure
                    completionHander(.failure(.missingRemoteTableAttributes(missingAttributes)))
                } else {
                    completionHander(.success(self.tables))
                }

            case .failure(let error):
                logger.warning("Failed to retrieve tables from remote 4D server \(error)")
                completionHander(.failure(.apiError(error)))
            }
        }
    }

}

extension Dictionary { // factorize
    init(_ pairs: [Element]) {
        self.init()
        for (k, v) in pairs {
            self[k] = v
        }
    }
}
