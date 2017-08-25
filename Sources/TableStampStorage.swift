//
//  TableStampStorage.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import QMobileAPI

let kGlobalStamp = "__globalStamp"
let kLastSync = "lastSync"
let kTableStamp = "stamp"
let defaultStamp: TableStampStorage.Stamp = 0

/// Store the table stamps
protocol TableStampStorage {

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
    var globalStamp: TableStampStorage.Stamp {
        get {
            return dataStore.globalStamp
        }
        set {
            dataStore.globalStamp = newValue
        }
    }

    var lastSync: Date? {
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
        return self["\(table.name).\(kTableStamp)"] as? TableStampStorage.Stamp ?? defaultStamp
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table) {
        self["\(table.name).\(kTableStamp)"] = stamp
    }
    var globalStamp: TableStampStorage.Stamp {
        get {
            return self[kGlobalStamp] as? TableStampStorage.Stamp ?? defaultStamp
        }
        set {
            //assert(newValue > 0)
            self[kGlobalStamp] = newValue
        }
    }

    var lastSync: Date? {
        get {
            return self[kLastSync] as? Date
        }
        set {
            self[kLastSync] = newValue
        }
    }
}

/// MARK: Prephirences
import Prephirences

/// Store table stamps in a `MutablePreferencesType` (keychain, userdefaults, plist, memory dictionary)
struct PrephirencesTableStampStorage: TableStampStorage {
    var preferences: MutablePreferencesType

    func stamp(for table: Table) -> TableStampStorage.Stamp {
        return preferences["\(table.name).\(kTableStamp)"] as? TableStampStorage.Stamp ?? defaultStamp
    }
    mutating func set(stamp: TableStampStorage.Stamp, for table: Table) {
        preferences["\(table.name).\(kTableStamp)"] = stamp
    }
    var globalStamp: TableStampStorage.Stamp {
        get {
            return preferences[kGlobalStamp] as? TableStampStorage.Stamp ?? defaultStamp
        }
        set {
            assert(newValue > 0)
            preferences[kGlobalStamp] = newValue
        }
    }
    var lastSync: Date? {
        get {
            return preferences[kLastSync] as? Date
        }
        set {
            preferences[kLastSync] = newValue
        }
    }
}

extension Record {

    open var __stamp: Int {
        return getPrivateAttribute(key: ImportKey.stamp) as? Int ?? 0
    }

}
