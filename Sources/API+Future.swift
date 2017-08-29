//
//  API+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import Result
import BrightFutures

public extension APIManager {

    /// Get server status
    public func loadStatus(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Status, APIError> {
        return Future { _ = self.loadStatus(queue: queue, progress: progress, completionHandler: $0) }
    }

    func status(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Result<Status, APIError> {
        return loadStatus(queue: queue, progress: progress).forced()
    }

    /// Get server info
    public func loadInfo(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Info, APIError> {
        return Future { _ = self.loadInfo(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get server session info
    public func loadSessionInfo(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[SessionInfo], APIError> {
        return Future { _ = self.loadSessionInfo(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get server Progress Info
    public func loadProgressInfo(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[ProgressInfo], APIError> {
        return Future { _ = self.loadProgressInfo(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get server Cache Info
    public func loadCacheInfo(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[CacheInfo], APIError> {
        return Future { _ = self.loadCacheInfo(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get server Entity Set
    public func loadEntitySet(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[InfoEntitySet], APIError> {
        return Future { _ = self.loadEntitySet(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get the catalog, list description of URI for tables and records
    public func loadCatalog(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Catalog], APIError> {
        return Future { _ = self.loadCatalog(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get all tables
    public func loadTables(queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Table], APIError> {
        return Future { _ = self.loadTables(queue: queue, progress: progress, completionHandler: $0) }
    }

    /// Get one table by name
    /// @param table     the wanted table name
    public func loadTable(name: String, queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Table, APIError> {
        return Future { _ = self.loadTable(name: name, queue: queue, progress: progress, completionHandler: $0) }
    }

}

public extension APIManager {

    public static func status(for urls: [URL], queue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[URL: Result<Status, APIError>], NoError> {
        typealias FutureTuple = Future<(URL, Result<Status, APIError>), NoError>
        var sequence: [FutureTuple] = []
        for url in urls {
            let resultified: Future<(Result<Status, APIError>), NoError> = APIManager(url: url).loadStatus().resultify()
            let future: FutureTuple = resultified.map { (url, $0) }
            sequence.append(future)
        }
        return sequence.sequence().map { dict($0) }
    }

}

private func dict<K, V>(_ tuples: [(K, V)])->[K:V] {
    var dict: [K:V] = [K: V]()
    tuples.forEach {dict[$0.0] = $0.1}
    return dict
}
