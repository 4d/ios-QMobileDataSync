//
//  DataSync+Records.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Result
import Moya
import FileKit

import QMobileAPI
import QMobileDataStore

extension DataSync {

    typealias RecordInitializer = (String, JSON) -> Record?
    /// Initialize or find an existing record
    func recordInitializer(table: Table, tableInfo: DataStoreTableInfo, context: DataStoreContext) -> RecordInitializer {
        let recordInitializer: RecordInitializer = { tableName, json in

            assert(tableName == tableInfo.originalName)
            assert(tableName == table.name)

            // Create only if not created
            var record: Record?
            context.perform(wait: true) {
                do {
                    if let predicate = table.predicate(for: json) {
                        record = try context.getOrCreate(in: tableInfo.name, matching: predicate)
                    } else {
                        logger.warning("Cannot checking if record already in database, no key for table '\(tableName)'")
                        record = context.create(in: tableInfo.name)
                        assertionFailure("Table must have primary key")
                    }
                } catch {
                    logger.warning("Failed to import one data into '\(tableName)': \(error)")
                }
            }
            return record
        }
        return recordInitializer
    }

    /// Load records from files, need to be done in data store context
    func loadRecordsFromFile(context: DataStoreContext) throws {
        // load data from files
        for (table, tableInfo) in self.tablesInfoByTable {
            let tableName = tableInfo.name
            if let url = self.bundle.url(forResource: tableName, withExtension: Preferences.jsonDataExtension, subdirectory: nil),
                let json = try? JSON(fileURL: url) {

                assert(ImportableParser.tableName(for: json) == tableInfo.originalName)

                let records = try table.parser.parseArray(json: json, with: self.recordInitializer(table: table, tableInfo: tableInfo, context: context))
                logger.info("\(records.count) records imported from '\(tableName)' file")
            }
        }

        try context.commit()
    }

    func loadRecordsFromCache(context: DataStoreContext) throws {
        // load data from files
        for (table, tableInfo) in self.tablesInfoByTable {
            let tableName = table.name
            let cacheFile: Path = self.cachePath + "\(tableName).\(Preferences.jsonDataExtension)"
            if cacheFile.exists {
                do {
                    let json = try JSON(path: cacheFile)

                    assert(ImportableParser.tableName(for: json) == tableInfo.originalName) // file with wrong format and an another table, renamed?

                    let records = try table.parser.parseArray(json: json, with: self.recordInitializer(table: table, tableInfo: tableInfo, context: context))
                    logger.info("\(records.count) records imported from '\(tableName)' file")

                } catch {
                    logger.warning("Failed to parse \(cacheFile): \(error)")
                }
            } else {
                logger.warning("No cache file \(cacheFile)")
            }
        }

        try context.commit()
    }

    // (a save publish information to UI)
    @discardableResult
    func tryCommit(_ context: DataStoreContext) -> Bool {
        do {
            try context.commit()
            return true
        } catch {
            logger.warning("Failed to save some records: \(error)")
            return false
        }
    }

}

import QMobileDataStore
extension Record: RecordImportable {

    public var tableName: String {
        return store.tableName
    }

    public func has(key: String) -> Bool {
        return store.has(key: key)
    }

    public func `import`(attribute: Attribute, value: Any?, with mapper: AttributeValueMapper) {
        return store.import(attribute: attribute, value: value, with: mapper)
    }

    public func importPrivateAttribute(key: String, value: Any?) {
        store.importPrivateAttribute(key: key, value: value)
    }

    public func get(attribute: Attribute, with mapper: AttributeValueMapper) -> Any? {
        return store.get(attribute: attribute, with: mapper)
    }

    public func getPrivateAttribute(key: String) -> Any? {
        return store.getPrivateAttribute(key: key)
    }

}
