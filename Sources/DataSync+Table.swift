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

    // Load database structures from
    public typealias TablesCompletionHander = (Result<[Table], DataSyncError>) -> Void
    public func loadTable(callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) -> Cancellable {
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
        return rest.loadTables(callbackQueue: callbackQueue) { result in
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
                var missingTables = [Table]()
                for (name, table) in tables {
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
                }

                completionHander(.success(Array(tables.values)))
            case .failure(let error):
                logger.warning("Failed to retrieve tables from remote 4D server \(error)")
                completionHander(.failure(.apiError(error)))
            }
        }
    }

}
