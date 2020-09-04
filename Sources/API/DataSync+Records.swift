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
import Prephirences

import QMobileAPI
import QMobileDataStore
#if os(iOS)
import UIKit
#endif

extension DataSync {

    fileprivate func json(_ table: Table, _ tableInfo: DataStoreTableInfo) -> JSON? {
        #if os(iOS)
        if let dataAsset = NSDataAsset(name: table.name) ?? NSDataAsset(name: tableInfo.name), let json = dataAsset.json {
            return json
        }
        #endif
        return self.bundle.json(forResource: tableInfo.name, withExtension: Preferences.jsonDataExtension)
    }

    /// Load records from files, need to be done in data store context.
    func loadRecordsFromFile(context: DataStoreContext, tables: [Table]) throws {
        self.dataSyncWillLoad(tables)
        var stamps: [Table: TableStampStorage.Stamp] = [:]
        // load data from files by table.
        for (table, tableInfo) in self.tablesInfoByTable {
            guard tables.contains(table) else { continue } // could filter on some tables.
            let tableName = table.name
            // Get json
            guard let json = json(table, tableInfo) else { continue }

            assert(ImportableParser.tableName(for: json) == tableInfo.originalName) // file with wrong format and an another table, renamed?
            stamps[table] = json[ImportKey.globalStamp].intValue
            // Parse the records from json and create core data object in passed context.
            let builder = DataSyncBuilder(table: table, tableInfo: tableInfo, context: context)
            let records = try builder.parseArray(json: json)
            logger.info("\(records.count) records imported from '\(tableName)' file")
        }

        // read global stamp from embedded files
        if stamps.isEmpty {
            logger.debug("no embedded files, must not set global stamp")
        } else if var stampStorage = self.dataStore.metadata?.stampStorage {
            var globalStamp = 0
            for (_, stamp) in stamps {
                // stampStorage.set(stamp: stamp, for: table)
                if (globalStamp == 0) || (stamp != 0 && stamp < globalStamp) { // take the min but not zero (all stamps must be equal or zero, but in case of)
                    globalStamp = stamp
                }
            }
            stampStorage.globalStamp = globalStamp
            logger.info("set global stamp \(stampStorage.globalStamp)")
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
public class DataSyncBuilder: ImportableBuilder {

    public typealias Importable = Record

    public let table: Table // needed for predicate but could be build using tableInfo
    public let tableInfo: DataStoreTableInfo // needed to create data store object
    let context: DataStoreContext

    var isRelation: Bool = false
    var inContext: Bool = false
    lazy var managePending = {
        return isRelation && !self.tableInfo.isSlave // a slave table will not sync, so record must not be destroyed
    }()

    static var tableCache: [String: Table] = [:]
    static var tableInfoCache: [String: DataStoreTableInfo] = [:]

    public init(table: Table, tableInfo: DataStoreTableInfo, context: DataStoreContext) {
        self.context = context
        self.tableInfo = tableInfo
        self.table = table
    }

    public static func builder(for tableName: String, context: DataStoreContext) -> DataSyncBuilder? {
        return DataSyncBuilder(tableName: tableName, context: context)
    }

    private init?(tableName: String, context: DataStoreContext) {
        self.context = context
        var tableInfo = DataSyncBuilder.tableInfoCache[tableName]
        if tableInfo == nil {
            tableInfo = context.tableInfo(forOriginalName: tableName)
            DataSyncBuilder.tableInfoCache[tableName] = tableInfo
        }
        guard let finalTableInfo = tableInfo else {
            return nil
        }
        var table = DataSyncBuilder.tableCache[tableName]
        if table == nil {
            table = finalTableInfo.api
            DataSyncBuilder.tableCache[tableName] = table
        }
        guard let finalTable = table else {
            return nil
        }
        self.tableInfo = finalTableInfo
        self.table = finalTable

        /*finalTable         guard let relationTableInfo = DataSync.instance.tablesInfoByTable[relationTable] else {
         logger.warning("Could not find related table information \(relationTableName) in structure")
         return
         }guard let relationTable = DataSync.instance.table(for: relationTableName) else {
         logger.warning("Could not find related table \(relationTableName) in structure")
         return
         }*/
    }

    public func setup(in callback: @escaping () -> Void) {
        context.perform(wait: true) {
            self.inContext = true
            callback()
            self.inContext = false
        }
    }

    public func build(_ tableName: String, _ json: JSON) -> Record? {
        assert(tableName == tableInfo.originalName)
        assert(tableName == table.name)
        assert(inContext) // Must beform operation in context

        // Create only if not created
        var created = false
        var record: Record?
        do {
            if let predicate = table.predicate(for: json) {
                record = try context.getOrCreate(in: tableInfo.name, matching: predicate, created: &created)
            } else {
                logger.warning("Cannot checking if record already in database, no primary key for table '\(tableName)'. This could result to duplicate records.")
                record = context.create(in: tableInfo.name)
                // assertionFailure("Table \(tableInfo.name) must have primary key")
                created = true
            }
        } catch {
            logger.warning("Failed to import one data into '\(tableName)': \(error)")
        }
        if let record = record {
            if managePending {
                if created && (record.pending == nil) {
                    record.pending = true
                }
            } else {
                record.pending = false
            }
        }
        return record
    }

    public func teardown() {
        assert(!inContext) // teardown must be called after setup finish (caller issue, or asynchrone setup)
    }
}
import CoreData
extension DataSyncBuilder {
    public func parseArray(json: JSON, using mapper: AttributeValueMapper = .default) throws ->  [DataSyncBuilder.Importable] {
        if Prephirences.DataSync.newSync {
            return try self.parseArray2(json: json, context: self.context as! NSManagedObjectContext)// swiftlint:disable:this force_cast
        }
        return try self.table.parser.parseArray(json: json, using: mapper, with: self)

    }
}

extension DataStoreContext {
    public func tableInfo(forOriginalName tableName: String) -> DataStoreTableInfo? {
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
#if os(iOS)
extension NSDataAsset {
    var json: JSON? {
        return try? JSON(data: self.data)
    }
}
#endif

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

    var deletedRecord: DeletedRecord? {
        guard let primaryKey = self.primaryKeyValue else {
            return nil
        }
        return DeletedRecord(primaryKey: "\(primaryKey)", tableNumber: nil, tableName: self.tableName, stamp: self.value(forKeyPath: kGlobalStamp) as? Double ?? 0)
    }
}

extension DataStoreError: ErrorConvertible {

}

extension DataSyncBuilder {
    public func parseArray2(json: JSON, using mapper: AttributeValueMapper = .default, context: NSManagedObjectContext) throws ->  [DataSyncBuilder.Importable] {
        let mapping = self.tableInfo.mapping
        var entities: [Any] = []
        let representation: [NSObject] = json["__ENTITIES"].arrayObject as? [NSObject] ?? []
        context.perform(wait: true) {
            entities = DataStoreDeserializer.collection(fromRepresentation: representation, mapping: mapping, context: context)

        }
        return entities.compactMap { $0 as? NSManagedObject}.map { Record(store: $0) }
    }
}

typealias DataStoreTableInfoMapping = DataStoreMapping

extension DataStoreTableInfo {

    fileprivate func fill(_ mapping: DataStoreTableInfoMapping) {
        assert(mapping.entityName == self.name)
        mapping.primaryKey = self.primaryKeyFieldInfo?.name
        var names: [String] = []
        for field in self.fields {
            switch field.type {
            case .date:
                let attributeName = field.userInfo?["keyMapping"] as? String ?? field.name
                mapping.addAttribute(withProperty: field.name, keyPath: attributeName, map: { value in
                    if let string = value as? String, !string.isEmpty {
                        if field.simpleDate {
                            return string.simpleDate ?? string.dateFromISO8601 // could remove dateFromISO8601
                        }
                        return string.dateFromISO8601
                    }
                    return  nil
                }, reverseMap: nil/* not implemented if not pushing data*/)
            default:
                if let originalName = field.userInfo?["keyMapping"] as? String {
                    mapping.addAttribute(withProperty: field.name, keyPath: originalName)
                } else {
                    names.append(field.name)
                }
            }
        }
        mapping.addAttributes(fromArray: names)

        for relationship in self.relationships {
            if let destinationTableInfo = relationship.destinationTable {
                let keyPath = relationship.userInfo?["keyMapping"] as? String ?? relationship.name
                let destinationMapping = destinationTableInfo.mapping
                if relationship.isToMany {
                    // mapping.add(toManyRelationshipMapping: destinationMapping, forProperty: relationship.name, keyPath: keyPath)
                    // we must do not create relation recursively, or we must create mapping according to the request we do
                } else {
                    mapping.addRelationshipMapping(destinationMapping, forProperty: relationship.name, keyPath: keyPath)
                }
            } else {
                logger.error("no info for relationship \(relationship.name)")
            }
        }
    }

    var mapping: DataStoreTableInfoMapping {
        return DataStoreTableInfoMapping.mapping(for: self)
    }

}

extension DataStoreTableInfoMapping {

    static var pool: [String: DataStoreTableInfoMapping] = [:]
    static var lock = NSRecursiveLock() // lock concurrent access to pool

    static func mapping(for info: DataStoreTableInfo) -> DataStoreTableInfoMapping {
        let name = info.name
        lock.lock()
        defer {
            lock.unlock()
        }
        if let cached = pool[name] {
            return cached
        }
        let mapping = DataStoreTableInfoMapping(entityName: name)
        pool[name] = mapping
        info.fill(mapping)
        return mapping
    }
}
