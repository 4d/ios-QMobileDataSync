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

        self.rest.plugins.append(ReceivePlugin { [weak self] result, target in
            if case .success(let response) = result {
                let data = response.data

                if let cacheTarget = target as? CacheTargetType, let fileName = cacheTarget.cacheFileName {

                    /*let url = response.request?.url, let routeTarget = self?.rest.target(for: url) {
                        
                    }*/

                    logger.debug("Save request into \(fileName)")
                    if let fileURL = self?.cacheURL?.appendingPathComponent(fileName) {
                        do {
                            try data.write(to:fileURL)
                        } catch {
                            logger.warning("Failed to write to cache file \(fileURL)")
                        }
                    }
                }
            }
        })
    }

            /// URL for caching data
    public var cacheURL: URL? = FileManager.SearchPathDirectory.cachesDirectory.url

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
