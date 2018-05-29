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
    public func status(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Status, APIError> {
        return Future { _ = self.status(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server info
    public func info(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Info, APIError> {
        return Future { _ = self.info(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server session info
    public func sessionInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[SessionInfo], APIError> {
        return Future { _ = self.sessionInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Progress Info
    public func progressInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[ProgressInfo], APIError> {
        return Future { _ = self.progressInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Cache Info
    public func cacheInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[CacheInfo], APIError> {
        return Future { _ = self.cacheInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Entity Set Info
    public func entitySetInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<EntitySetInfo, APIError> {
        return Future { _ = self.entitySetInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get the catalog, list description of URI for tables and records
    public func catalog(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Catalog], APIError> {
        return Future { _ = self.catalog(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get all tables
    public func tables(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Table], APIError> {
        return Future { _ = self.tables(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get one table by name
    /// @param table     the wanted table name
    public func table(name: String, callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Table, APIError> {
        return Future { _ = self.table(name: name, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
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
            let resultified: Future<(Result<Status, APIError>), NoError> = manager(for: url).status(callbackQueue: callbackQueue, progress: progress).resultify()
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
            let statusFuture: Future<Status, APIError> = manager(for: url).status(callbackQueue: callbackQueue, progress: progress)
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
        let future: FutureFirst = APIManager(url: firstURL).status(callbackQueue: callbackQueue, progress: progress).map { (firstURL, $0) }
        // this is sequential with recoverWith, we could do better //
        var current = future
        var currentURL: URL? = urls.popFirst()
        while currentURL != nil {
            if let url  = currentURL {
                let recoverTask: ((APIError) -> FutureFirst) = { error -> FutureFirst in
                    return manager(for: url).status(callbackQueue: callbackQueue, progress: progress).map { (url, $0) }
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
