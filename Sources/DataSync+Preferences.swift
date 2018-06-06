//
//  DataSync+Preferences.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Prephirences

extension DataSync {

    private static var preferences = Prephirences.sharedMutableInstance!

    private struct PrefKey {
        static let prefixKey = "dataSync"

        static let jsonDataExtension = "\(prefixKey).json.data.ext"
        static let jsonTableExtension = "\(prefixKey).json.table.ext"

        static let requestLimit = "\(prefixKey).server.request.limit"
        static let requestPageLimit = "\(prefixKey).server.request.page.limit"

        static let firstSync = "\(prefixKey).first"
        static let dataFromFile = "\(prefixKey).fromFiles"
        static let deleteRecords = "\(prefixKey).deleteRecords"
    }

    struct Preferences {

        static let jsonDataExtension = preferences.string(forKey: DataSync.PrefKey.jsonDataExtension) ?? "data.json"
        static let jsonTableExtension = preferences.string(forKey: DataSync.PrefKey.jsonTableExtension) ?? "catalog.json"

        static let requestLimit = preferences[DataSync.PrefKey.requestLimit] as? Int ?? 100000
        static let requestPageLimit = preferences[DataSync.PrefKey.requestPageLimit] as? Int ?? 10000

        static var firstSync: Bool {
            get {
                return preferences[DataSync.PrefKey.firstSync] as? Bool ?? true
            }
            set {
                preferences[DataSync.PrefKey.firstSync] = newValue
            }
        }

        static var deleteRecordsAtStart: Bool {
            get {
                return preferences[DataSync.PrefKey.deleteRecords] as? Bool ?? false
            }
            set {
                preferences[DataSync.PrefKey.deleteRecords] = newValue
            }
        }

        static let dataFromFile = preferences[DataSync.PrefKey.dataFromFile] as? Bool ?? true
    }

}
