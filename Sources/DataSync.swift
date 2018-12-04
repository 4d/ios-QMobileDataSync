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

extension Table: Hashable {
    public var hashValue: Int {
        return self.name.hashValue
    }
}
