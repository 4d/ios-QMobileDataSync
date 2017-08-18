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

let logger = Logger.forClass(DataSync.self) // XXX check if configuration not already done...

public class DataSync {

    /// Object to make remote request
    public let rest: APIManager
    /// Mobile data store
    public let dataStore: DataStore

    public init(rest: APIManager = APIManager.instance, dataStore: DataStore = QMobileDataStore.dataStore) {
        self.rest = rest
        self.dataStore = dataStore
    }

    /// Bundle for files (JSON tables and data)
    public var bundle: Bundle = .main

    /// List of loaded tables indexed by name
    public var tablesByName: [String: Table] = [:]
    // shorcut to get only tables
    var tables: [Table] {
        return Array(self.tablesByName.values)
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
