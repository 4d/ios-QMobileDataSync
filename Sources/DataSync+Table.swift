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

    private func createTableFromDataStore() -> [Table] {
        return self.dataStore.tablesInfo.map { $0.api }
    }

    // Load database structures from
    public typealias TablesCompletionHander = (Result<[Table], DataSyncError>) -> Void
    public func loadTable(callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) {

        var tables = loadTableFromEmbeddedFiles().dictionary { $0.name }
        tables = stripTablesNotInDataStore(tables)
        /// XXX could be replaced by createTableFromDataStore() if method has been implemented

        self.tablesByName = tables
        if let callbackQueue = callbackQueue {
            callbackQueue.async {
                completionHander(.success(Array(tables.values)))
            }
        } else {
            completionHander(.success(Array(tables.values)))
        }
    }

    public func loadRemoteTable(callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) -> Cancellable {
        if self.tablesByName.isEmpty {
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
                    for remoteTable in remoteTables where self.tablesByName[remoteTable.name] == nil {
                        // normal, not all table displayed in mobile project
                        logger.verbose("Table '\(remoteTable.name) not managed by this mobile project.")
                    }
                #endif
                var indexedRemoteTables = remoteTables.dictionary { $0.name }
                var missingTables = [Table]()
                for (name, table) in self.tablesByName {
                    if let remoteTable = indexedRemoteTables[name] {
                        assert(table.name == remoteTable.name)
                        // TODO check remoteTable and table equals? or compatible ie. all field in table are in remoteTable
                    } else {
                        missingTables.append(table)
                        logger.warning("Table \(name) not accessible on remote 4D Server. Check if you app is up to date")
                    }
                }
                if !missingTables.isEmpty {
                    // notifify app not up to date with data structure
                    completionHander(.failure(.missingRemoteTables(missingTables)))
                } else {
                    completionHander(.success(Array(self.tablesByName.values)))
                }

            case .failure(let error):
                logger.warning("Failed to retrieve tables from remote 4D server \(error)")
                completionHander(.failure(.apiError(error)))
            }
        }
    }

}
