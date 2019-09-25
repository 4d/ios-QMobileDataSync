//
//  DataSync+Table.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Moya

import QMobileAPI
import QMobileDataStore

extension DataSync {

    /// Load table structures from embedded files (not working if definition in asset)
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
        let indexedTablesInfo = self.dataStore.tablesInfo.dictionary { $0.originalName }
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
    public func loadTable(on callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) {
        let tableInfo = self.dataStore.tablesInfo.filter { !$0.isAbstract }

        let infos: [(Table, DataStoreTableInfo)] = tableInfo.map { ($0.api, $0) }
        self.tablesInfoByTable = Dictionary(uniqueKeysWithValues: infos)

        logger.info("Table strutures from data store: \(Array(self.tables.map { $0.name }))")

        if let callbackQueue = callbackQueue {
            callbackQueue.async {
                completionHander(.success(self.tables))
            }
        } else {
            completionHander(.success(self.tables))
        }
    }

    public func loadRemoteTable(on callbackQueue: DispatchQueue? = nil, _ completionHander: @escaping TablesCompletionHander) -> Cancellable {
        if self.tables.isEmpty {
            self.loadTable { _ in
                // no really asynchrone; if asynchone must use Future
            }
        }
        // from remote store?
        return self.apiManager.tables(callbackQueue: callbackQueue) { result in
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

                // Look for missing tables or attributes
                let removeTablesByName = remoteTables.dictionary { $0.name }
                var missingTables = [Table]()
                var missingAttributes = [Table: [Attribute]]()
                for table in self.tables {
                    var tableInfo = self.tablesInfoByTable[table]
                    var fieldInfoByOriginalName = tableInfo?.fields.dictionary { $0.originalName }
                    if let remoteTable = removeTablesByName[table.name] {
                        assert(table.name == remoteTable.name)

                        let remoteAttributesByName = remoteTable.attributes
                        // check remoteTable and table equals? or compatible ie. all field in table are in remoteTable
                        for (name, attribute) in table.attributes {
                            if remoteAttributesByName[name] == nil {
                                logger.warning("Missing attribute \(attribute.name) for table \(table.name) on remote 4D Server. Check if you app is up to date")
                                if missingAttributes[table] == nil {
                                    missingAttributes[table] = [attribute]
                                } else {
                                    missingAttributes[table]?.append(attribute)
                                }
                                fieldInfoByOriginalName?[attribute.name]?.isMissingRemoteField = true
                            } else {
                                fieldInfoByOriginalName?[attribute.name]?.isMissingRemoteField = false
                            }
                        }
                        // check if there is global stamp on server for filter
                        tableInfo?.hasGlobalStamp = remoteTable.attributes[kGlobalStamp] != nil
                        if remoteTable.attributes[kGlobalStamp] == nil {
                            logger.warning("No \(kGlobalStamp) for Table \(table.name) on remote 4D Server. Contact the server administator to have incremental data reloading.")
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

let kUserInfoMissingFromRemote = "missingFromRemote"
let kYES = "YES"

extension DataStoreFieldInfo {
    var isMissingRemoteField: Bool {
        get {
            if let userInfo = self.userInfo, let missing = userInfo[kUserInfoMissingFromRemote] as? String {
                return missing == kYES
            }
            return false
        }
        set {
            if newValue {
                var userInfo = self.userInfo ?? [:]
                userInfo[kUserInfoMissingFromRemote] = kYES
                self.userInfo = userInfo
            } else {
                self.userInfo?[kUserInfoMissingFromRemote] = nil
            }
        }
    }
}
