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
import Moya

// Extension to use Future
// CLEAN, make request cancellable, maybe using FutureContainer or ask BrightFutures to remove final keyword info Future
public extension APIManager {

    /// Get server status
    public func loadStatus(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Status, APIError> {
        return Future { _ = self.loadStatus(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    func status(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Result<Status, APIError> {
        return loadStatus(callbackQueue: callbackQueue, progress: progress).forced()
    }

    /// Get server info
    public func loadInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Info, APIError> {
        return Future { _ = self.loadInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server session info
    public func loadSessionInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[SessionInfo], APIError> {
        return Future { _ = self.loadSessionInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Progress Info
    public func loadProgressInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[ProgressInfo], APIError> {
        return Future { _ = self.loadProgressInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Cache Info
    public func loadCacheInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[CacheInfo], APIError> {
        return Future { _ = self.loadCacheInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Entity Set
    public func loadEntitySet(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[InfoEntitySet], APIError> {
        return Future { _ = self.loadEntitySet(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get the catalog, list description of URI for tables and records
    public func loadCatalog(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Catalog], APIError> {
        return Future { _ = self.loadCatalog(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get all tables
    public func loadTables(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Table], APIError> {
        return Future { _ = self.loadTables(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get one table by name
    /// @param table     the wanted table name
    public func loadTable(name: String, callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Table, APIError> {
        return Future { _ = self.loadTable(name: name, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

}

public extension APIManager {

    public static func status(for urls: [URL], callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[URL: Result<Status, APIError>], NoError> {
        if urls.isEmpty {
            return Future(value: [:])
        }

        typealias FutureTuple = Future<(URL, Result<Status, APIError>), NoError>
        var sequence: [FutureTuple] = []
        for url in urls {
            let resultified: Future<(Result<Status, APIError>), NoError> = manager(for: url).loadStatus(callbackQueue: callbackQueue, progress: progress).resultify()
            let future: FutureTuple = resultified.map { (url, $0) }
            sequence.append(future)
        }

        return sequence.sequence().map { dict($0) }
    }

    public static func firstStatus(for urls: [URL], callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<(URL, Status), APIError> {
        if urls.isEmpty {
            assertionFailure("no url provided")
            return Future(error: APIError.error(from: NSError(domain: "qmobile", code: 700))) // CLEAN, use a real APIError
        }

        typealias FutureFirst = Future<(URL, Status), APIError>
        var sequence: [FutureFirst] = []
        for url in urls {
            let statusFuture: Future<Status, APIError> = manager(for: url).loadStatus(callbackQueue: callbackQueue, progress: progress)
            let future: FutureFirst = statusFuture.map { (url, $0) }
            sequence.append(future)
        }
        return sequence.firstCompleted()
    }

    public static func firstStatusSuccess(for urls: [URL], callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<(URL, Status), APIError> {
        var urls = urls.slice // popable

        guard let firstURL: URL = urls.popFirst() else {
            assertionFailure("no url provided")
            return Future(error: APIError.error(from: NSError(domain: "qmobile", code: 700))) // CLEAN, use a real APIError
        }

        typealias FutureFirst = Future<(URL, Status), APIError>
        let future: FutureFirst = APIManager(url: firstURL).loadStatus(callbackQueue: callbackQueue, progress: progress).map { (firstURL, $0) }
        // this is sequential with recoverWith, we could do better //
        var current = future
        var currentURL: URL? = urls.popFirst()
        while currentURL != nil {
            if let url  = currentURL {
                let recoverTask: ((APIError) -> FutureFirst) = { error -> FutureFirst in
                    return manager(for: url).loadStatus(callbackQueue: callbackQueue, progress: progress).map { (url, $0) }
                }
                if let callbackQueue = callbackQueue {
                    current = current.recoverWith(context: callbackQueue.context, task: recoverTask)
                } else {
                    current = current.recoverWith(task: recoverTask)
                }
            }
            currentURL = urls.popFirst()
        }
        return current
    }

    private static func manager(for url: URL) -> APIManager {
        let apiManager = APIManager(url: url)
        apiManager.stub = APIManager.instance.stub
        apiManager.stubDelegate = APIManager.instance.stubDelegate
        // XXX copy other fields? , move this method into API?
        return apiManager
    }
}
