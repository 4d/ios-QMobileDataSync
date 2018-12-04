//
//  DataSync+Preferences.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Prephirences

extension Prephirences {

    struct DataSync {

        static let instance = MutableProxyPreferences(preferences: sharedMutableInstance!, key: "dataSync.") // swiftlint:disable:this force_cast

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

        /// Is it first synchronisation?.
        static var firstSync: Bool {
            get {
                return instance["firstSync"] as? Bool ?? true
            }
            set {
                instance["firstSync"] = newValue
            }
        }

        struct Request {
            static let instance =  ProxyPreferences(preferences: Prephirences.DataSync.instance, key: "request.")
            static let limit = instance["limit"] as? Int ?? 100000

            struct Page {
                static let instance =  ProxyPreferences(preferences: Prephirences.DataSync.Request.instance, key: "page.")
                static let limit = instance["limit"] as? Int ?? 10000
            }
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
