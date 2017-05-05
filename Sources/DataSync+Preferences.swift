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
        static let remoteServerURL = "com.4d.server.host"

        static let jsonDataExtension = "com.4d.json.data.ext"
        static let jsonTableExtension = "com.4d.json.table.ext"

        static let requestLimit = "com.4d.server.request.limit"

        static let firstSync = "com.4d.sync.first"
        static let dataFromFile = "com.4d.sync.fromFiles"
    }

    struct Preferences {
        static let remoteServerURL = preferences.url(forKey: DataSync.PrefKey.remoteServerURL) ?? URL(string: "http://127.0.0.1")!

        static let jsonDataExtension = preferences.string(forKey: DataSync.PrefKey.jsonDataExtension) ?? "data.json"
        static let jsonTableExtension = preferences.string(forKey: DataSync.PrefKey.jsonTableExtension) ?? "catalog.json"

        static let requestLimit = preferences[DataSync.PrefKey.requestLimit] as? Int ?? 100

        static var firstSync: Bool {
            get {
                return preferences[DataSync.PrefKey.requestLimit] as? Bool ?? true
            }
            set {
                preferences[DataSync.PrefKey.requestLimit] = newValue
            }
        }

        static let dataFromFile = preferences[DataSync.PrefKey.dataFromFile] as? Bool ?? false
    }

}
