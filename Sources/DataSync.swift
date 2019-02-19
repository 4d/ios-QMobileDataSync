//
//  DataSync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 02/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import QMobileDataStore
import QMobileAPI

import Result
import FileKit

let logger = Logger.forClass(DataSync.self)
let kGlobalStamp = "__GlobalStamp"

public class DataSync {

    /// Object to make remote request
    public var apiManager: APIManager
    /// Mobile data store
    public let dataStore: DataStore

    public init(apiManager: APIManager = APIManager.instance, dataStore: DataStore = DataStoreFactory.dataStore) {
        self.apiManager = apiManager
        self.dataStore = dataStore
    }

    /// URL for caching data
    public var cachePath: Path = .userCaches

    /// Bundle for files (JSON tables and data)
    public var bundle: Bundle = .main

    /// List of loaded tables
    public var tablesInfoByTable: [Table: DataStoreTableInfo] = [:]
    public var tables: [Table] {
        return Array(tablesInfoByTable.keys)
    }

    /// Current process. Support only one process.
    var process: Process?

    /// Delegate used by application service to be notified of events.
    public weak var delegate: DataSyncDelegate?

    /// If true save each records page received
    /// otherwise save after a complete table loading
    var saveMode: SaveMode = .onCompletion

    public enum SaveMode {
        case eachPage
        case byTable
        case onCompletion
    }

}

extension DataSync {
    func table(for name: String) -> Table? {
        return tablesInfoByTable.keys.filter({ $0.name == name }).first
    }

    func parseDate(from value: Any) -> Date? {
        if let date = value as? Date {
            return date
        } else if let string = value as? String, let date = string.dateFromRFC3339 ?? string.simpleDate {
            return date
        } else if let json = value as? JSON, let date = json.date {
            return date
        }
        return nil
    }
}
