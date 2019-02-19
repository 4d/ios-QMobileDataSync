//
//  TableStampStorage.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import QMobileAPI

let defaultStamp: TableStampStorage.Stamp = 0

enum TableStampStorageKey: String {
    case lastSync, tableStamp, globalStamp
}

/// Store the table stamps
public protocol TableStampStorage {

    typealias Stamp = Int

    /// Get stamp for one table
    // func stamp(for table: Table) -> Stamp
    /// Set stamp for one table
    // mutating func set(stamp: Stamp, for table: Table)

    /// Global stamp for all tables
    var globalStamp: Stamp { get set }

    /// last successful synchronisation date
    var lastSync: Date? { get set }
}

/// MARK: DataStore
import QMobileDataStore
extension DataStoreMetadata {
    var stampStorage: TableStampStorage {
        return DataStoreTableStampStorage(dataStore: self)
    }
}

// Cannot extends protocol, use an intermediate struct
struct DataStoreTableStampStorage: TableStampStorage {
    var dataStore: DataStoreMetadata

    func stamp(for table: Table) -> TableStampStorage.Stamp {
        return dataStore.stamp(for: table)
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table) {
        dataStore.set(stamp: stamp, for: table)
    }
    public var globalStamp: TableStampStorage.Stamp {
        get {
            return dataStore.globalStamp
        }
        set {
            dataStore.globalStamp = newValue
        }
    }

    public var lastSync: Date? {
        get {
            return dataStore.lastSync
        }
        set {
            dataStore.lastSync = newValue
        }
    }

}

extension DataStoreMetadata {
    func stamp(for table: Table) -> TableStampStorage.Stamp {
        return self["\(table.name).\(TableStampStorageKey.tableStamp.rawValue)"] as? TableStampStorage.Stamp ?? defaultStamp
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table) {
        self["\(table.name).\(TableStampStorageKey.tableStamp.rawValue)"] = stamp
    }
    public var globalStamp: TableStampStorage.Stamp {
        get {
            return self[TableStampStorageKey.globalStamp.rawValue] as? TableStampStorage.Stamp ?? defaultStamp
        }
        set {
            //assert(newValue > 0)
            self[TableStampStorageKey.globalStamp.rawValue] = newValue
        }
    }

   public var lastSync: Date? {
        get {
            return self[TableStampStorageKey.lastSync.rawValue] as? Date
        }
        set {
            self[TableStampStorageKey.lastSync.rawValue] = newValue
        }
    }
}

/// MARK: Prephirences
import Prephirences

/// Store table stamps in a `MutablePreferencesType` (keychain, userdefaults, plist, memory dictionary)
struct PrephirencesTableStampStorage: TableStampStorage {
    var preferences: MutablePreferencesType

    func stamp(for table: Table) -> TableStampStorage.Stamp {
        return preferences["\(table.name).\(TableStampStorageKey.tableStamp.rawValue)"] as? TableStampStorage.Stamp ?? defaultStamp
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table) {
        preferences["\(table.name).\(TableStampStorageKey.tableStamp.rawValue)"] = stamp
    }
    public var globalStamp: TableStampStorage.Stamp {
        get {
            return preferences[TableStampStorageKey.globalStamp.rawValue] as? TableStampStorage.Stamp ?? defaultStamp
        }
        set {
            assert(newValue > 0)
            preferences[TableStampStorageKey.globalStamp.rawValue] = newValue
        }
    }
    public var lastSync: Date? {
        get {
            return preferences[TableStampStorageKey.lastSync.rawValue] as? Date
        }
        set {
            preferences[TableStampStorageKey.lastSync.rawValue] = newValue
        }
    }
}

extension Record {

    open var __stamp: Int {
        return getPrivateAttribute(key: ImportKey.stamp) as? Int ?? 0
    }

}
