//
//  DataSync+Records.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Moya
import FileKit

import QMobileAPI
import QMobileDataStore

extension DataSync {

    /// Load records from files, need to be done in data store context.
    func loadRecordsFromFile(context: DataStoreContext, tables: [Table]) throws {
        self.dataSyncWillLoad(tables)
        var stamps: [Table: TableStampStorage.Stamp] = [:]
        // load data from files by table.
        for (table, tableInfo) in self.tablesInfoByTable {
            guard tables.contains(table) else { continue } // could filter on some tables.
            let tableName = table.name
            // Get json
            guard let json = NSDataAsset(name: table.name)?.json ??
                NSDataAsset(name: tableInfo.name)?.json ??
                self.bundle.json(forResource: tableInfo.name, withExtension: Preferences.jsonDataExtension) else { continue }

            assert(ImportableParser.tableName(for: json) == tableInfo.originalName) // file with wrong format and an another table, renamed?
            stamps[table] = json[ImportKey.globalStamp].intValue
            // Parse the records from json and create core data object in passed context.
            let records = try table.parser.parseArray(json: json, with: DataSyncBuilder(table: table, tableInfo: tableInfo, context: context))
            logger.info("\(records.count) records imported from '\(tableName)' file")
        }

        // read global stamp from embedded files
        if var stampStorage = self.dataStore.metadata?.stampStorage {
            var globalStamp = 0
            for (_, stamp) in stamps {
                // stampStorage.set(stamp: stamp, for: table)
                if (globalStamp == 0) || (stamp != 0 && stamp < globalStamp) { // take the min but not zero (all stamps must be equal or zero, but in case of)
                    globalStamp = stamp
                }
            }
            stampStorage.globalStamp = globalStamp
        }

        // finally flush the context.
        try context.commit()

        self.dataSyncDidLoad(tables)
    }

    /// We download to a cache folder when reloading. Then we load from this cache.
    func loadRecordsFromCache(context: DataStoreContext, tables: [Table]? = nil) throws {
        for (table, tableInfo) in self.tablesInfoByTable {
            guard tables?.contains(table) ?? true else { continue } // could filter on some tables.
            let tableName = table.name
            // Get json from file
            let cacheFile: Path = self.cachePath + "\(tableName).\(Preferences.jsonDataExtension)"
            guard let json = cacheFile.json else { continue }

            assert(ImportableParser.tableName(for: json) == tableInfo.originalName) // file with wrong format and an another table, renamed?

            // Parse the records from json and create core data object in passed context.
            let records = try table.parser.parseArray(json: json, with: DataSyncBuilder(table: table, tableInfo: tableInfo, context: context))
            logger.info("\(records.count) records imported from '\(tableName)' file")

            try? cacheFile.deleteFile()
        }
    }

    // (a save: publish information to UI)
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

/// Initialize or find an existing record.
class DataSyncBuilder: ImportableBuilder {

    typealias Importable = Record

    let table: Table // needed for predicate but could be build using tableInfo
    let tableInfo: DataStoreTableInfo // needed to create data store object
    let context: DataStoreContext

    var inContext: Bool = false

    init(table: Table, tableInfo: DataStoreTableInfo, context: DataStoreContext) {
        self.context = context
        self.tableInfo = tableInfo
        self.table = table
    }

    init?(tableName: String, context: DataStoreContext) {
        self.context = context
        guard let tableInfo = context.tableInfo(forOriginalName: tableName) else { // XXX if time consuming use a cache...(but not singleton if possible DataSync.instance)
            return nil
        }
        self.tableInfo = tableInfo
        self.table = tableInfo.api
        /*
         guard let relationTableInfo = DataSync.instance.tablesInfoByTable[relationTable] else {
         logger.warning("Could not find related table information \(relationTableName) in structure")
         return
         }guard let relationTable = DataSync.instance.table(for: relationTableName) else {
         logger.warning("Could not find related table \(relationTableName) in structure")
         return
         }*/
    }

    func setup(in callback: @escaping () -> Void) {
        context.perform(wait: true) {
            self.inContext = true
            callback()
            self.inContext = false
        }
    }

    func build(_ tableName: String, _ json: JSON) -> Record? {
        assert(tableName == tableInfo.originalName)
        assert(tableName == table.name)
        assert(inContext) // Must beform operation in context

        // Create only if not created
        var record: Record?
        do {
            if let predicate = table.predicate(for: json) {
                record = try context.getOrCreate(in: tableInfo.name, matching: predicate)
            } else {
                logger.warning("Cannot checking if record already in database, no primary key for table '\(tableName)'. This could result to duplicate records.")
                record = context.create(in: tableInfo.name)
                // assertionFailure("Table \(tableInfo.name) must have primary key")
            }
        } catch {
            logger.warning("Failed to import one data into '\(tableName)': \(error)")
        }
        return record
    }

    func teardown() {
        assert(!inContext) // teardown must be called after setup finish (caller issue, or asynchrone setup)
    }
}

extension DataStoreContext {
    func tableInfo(forOriginalName tableName: String) -> DataStoreTableInfo? {
        for tableInfo in self.tablesInfo where tableInfo.originalName == tableName {
            return tableInfo
        }
        return nil
    }
}

// MARK: JSON extensions
extension Path {
    fileprivate var json: JSON? {
        if self.exists {
            do {
                return try JSON(path: self)
            } catch {
                logger.warning("Failed to parse \(self): \(error)")
                try? self.deleteFile() // remove invalid file
            }
        } else {
            logger.warning("No cache file \(self)")
        }
        return nil
    }
}
extension NSDataAsset {
    var json: JSON? {
        return try? JSON(data: self.data)
    }
}

extension Bundle {
    func json(forResource resource: String, withExtension ext: String) -> JSON? {
        if let url = self.url(forResource: resource, withExtension: ext, subdirectory: nil) {
            return try? JSON(fileURL: url)
        }
        return nil
    }
}

// MARK: RecordImportable
extension Record: RecordImportable {

    public var tableName: String {
        return store.tableName
    }

    public func has(key: String) -> Bool {
        return store.has(key: key)
    }

    public func isRelation(key: String) -> Bool {
        return store.isRelation(key: key)
    }

    public func isField(key: String) -> Bool {
        return store.isField(key: key)
    }

    public func set(attribute: Attribute, value: Any?, with mapper: AttributeValueMapper) {
        return store.set(attribute: attribute, value: value, with: mapper)
    }

    public func setPrivateAttribute(key: String, value: Any?) {
        store.setPrivateAttribute(key: key, value: value)
    }

    public func get(attribute: Attribute, with mapper: AttributeValueMapper) -> Any? {
        return store.get(attribute: attribute, with: mapper)
    }

    public func getPrivateAttribute(key: String) -> Any? {
        return store.getPrivateAttribute(key: key)
    }

}

extension Record {
    /// If in userinfo a primary key is defined, get the value for this key.
    open var primaryKeyValue: Any? {
        guard let primaryKey = self.tableInfo.primaryKey else {
            return nil
        }
        return self[primaryKey]
    }

}

extension DataStoreError: ErrorConvertible {

}
