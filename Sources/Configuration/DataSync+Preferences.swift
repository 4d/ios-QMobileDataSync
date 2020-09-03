//
//  DataSync+Preferences.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Prephirences
import QMobileAPI

extension Prephirences {

    struct DataSync {

        static let instance = MutableProxyPreferences(preferences: sharedMutableInstance!, key: "dataSync.") // swiftlint:disable:this superfluous_disable_command force_cast

        /// Load data from embedded files. Default true.
        static let dataFromFile = instance["fromFiles"] as? Bool ?? true
        /// Drop the database.
        static let dataStoreDrop = instance["dataStoreDrop"] as? Bool ?? false

        /// Remove at each start the record. Default false.
        static var deleteRecordsAtStart: Bool {
            get {
                return instance["deleteRecords"] as? Bool ?? false
            }
            set {
                instance["deleteRecords"] = newValue
            }
        }

        /// Remove records that do not match records
        static let deletedByFilter = instance["deletedByFilter"] as? Bool ?? false

        /// Is it first synchronisation?.
        public static var firstSync: Bool {
            get {
                return instance["firstSync"] as? Bool ?? true
            }
            set {
                instance["firstSync"] = newValue
            }
        }

        /// If `true` synchronize table sequentially
        public static var sequential: Bool {
            get {
                return instance["sequential"] as? Bool ?? false
            }
            set {
                instance["sequential"] = newValue
            }
        }

        /// Limit the number of parallel task to sync tables. if 0 no limit.
        public static var parallelCount: Int {
            return instance["parallelCount"] as? Int ?? 4
        }

        /// Table order: asc, desc or undefined
        public static var tableOrder: OrderBy? {
            guard let order = instance["order"] as? String else {
                return sequential ? .asc: nil
            }
            return (order == "asc") ? .asc: .desc
        }

        static let allowMissingField: Bool = instance["allowMissingField"] as? Bool ?? true

        /// Use newSync code, by default true
        public static var newSync: Bool {
            get {
                return instance["newSync"] as? Bool ?? true
            }
            set {
                instance["newSync"] = newValue
            }
        }

        struct Request {
            static let instance =  ProxyPreferences(preferences: Prephirences.DataSync.instance, key: "request.")
            static let limit = instance["limit"] as? Int ?? 100000
            static let deleteLimit = instance["deleteLimit"] as? Int ?? Request.limit
        }

    }

}

// MARK: for cache.
extension DataSync {

    private static var preferences = Prephirences.sharedMutableInstance!

    private struct PrefKey {
        static let jsonDataExtension = "dataSync.json.data.ext"
        static let jsonTableExtension = "dataSync.json.table.ext"
    }

    struct Preferences {
        /// Extension for embedded data file. (deprecated, use NSDataAsset instead)
        static let jsonDataExtension = preferences.string(forKey: DataSync.PrefKey.jsonDataExtension) ?? "data.json"
        /// Extension for embedded catalog definition file. (deprecated, use NSDataAsset instead)
        static let jsonTableExtension = preferences.string(forKey: DataSync.PrefKey.jsonTableExtension) ?? "catalog.json"
    }

}
