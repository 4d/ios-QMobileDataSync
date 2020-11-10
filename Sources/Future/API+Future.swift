//
//  API+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Combine

import QMobileAPI

import Moya

// Extension to use Future
public extension APIManager {

    /// Get server status
    func status(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Status, APIError> {
        return Future<Status, APIError> { _ = self.status(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server info
    func info(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Info, APIError> {
        return Future<Info, APIError> { _ = self.info(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server session info
    func sessionInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[SessionInfo], APIError> {
        return Future<[SessionInfo], APIError> { _ = self.sessionInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Progress Info
    func progressInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[ProgressInfo], APIError> {
        return Future { _ = self.progressInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Cache Info
    func cacheInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[CacheInfo], APIError> {
        return Future { _ = self.cacheInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get server Entity Set Info
    func entitySetInfo(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<EntitySetInfo, APIError> {
        return Future { _ = self.entitySetInfo(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get the catalog, list description of URI for tables and records
    func catalog(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Catalog], APIError> {
        return Future { _ = self.catalog(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get all tables
    func tables(callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<[Table], APIError> {
        return Future { _ = self.tables(callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get one table by name
    /// @param table     the wanted table name
    func table(name: String, callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Table, APIError> {
        return Future { _ = self.table(name: name, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get deleted records
    func deletedRecordPage(configure: ConfigureRecordsRequest? = nil, callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<Page, APIError> {
        return Future { _ = self.deletedRecordPage(configure: configure, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Upload data to the server. Could be an image or a blob.
    /// An id will be returned to use to associate this upload to record field or action parameters.
    func upload(data: Data, image: Bool = false, mimeType: String?, callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<UploadResult, APIError> {
        return Future { _ = self.upload(data: data, image: image, mimeType: mimeType, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Upload file url data to server.
    /// An id will be returned to use to associate this upload to record field or action parameters.
    func upload(url: URL, callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> Future<UploadResult, APIError> {
        return Future { _ = self.upload(url: url, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

    /// Get the records into simple structures. Only one page is loaded.
    /// You must get information from page to configure next request.
    /// @param tableName   the table name
    /// @param attribute   get only this attributes
    /// @param recursive   receive all page until last one (default: false)
    /// @param configure   closure to configure the request
    func recordPage(tableName: String,
                    attributes: [String: Any] = [:],
                    setID: QMobileAPI.EntitySetIdConvertible? = nil,
                    recursive: Bool = false,
                    configure: QMobileAPI.APIManager.ConfigureRecordsRequest? = nil,
                    callbackQueue: DispatchQueue? = nil,
                    progress: QMobileAPI.APIManager.ProgressHandler? = nil) -> Future<Page, APIError> {
        return Future { _ = self.recordPage(tableName: tableName, attributes: attributes, setID: setID, recursive: recursive, configure: configure, callbackQueue: callbackQueue, progress: progress, completionHandler: $0) }
    }

}

public extension APIManager {

    static func status(for urls: [URL], callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> AnyPublisher<[URL: Result<Status, APIError>], Never> {
        if urls.isEmpty {
            return Future<[URL: Result<Status, APIError>], Never>(value: [:]).eraseToAnyPublisher()
        }

        typealias FutureTuple = AnyPublisher<(URL, Result<Status, APIError>), Never>
        var sequence: [FutureTuple] = []
        for url in urls {
            let resultified: AnyPublisher<(Result<Status, APIError>), Never> = manager(for: url).status(callbackQueue: callbackQueue, progress: progress).resultify()
            let future: FutureTuple = resultified.map { (url, $0) }.eraseToAnyPublisher()
            sequence.append(future)
        }
        return sequence.sequence().map { dict($0) }.eraseToAnyPublisher()
    }

  /*  static func firstStatus(for urls: [URL], callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> AnyPublisher<(URL, Status), APIError> {
        if urls.isEmpty {
            assertionFailure("no url provided")
            return Future<(URL, Status), APIError>(error: APIError.error(from: NSError(domain: "qmobile", code: 700))).eraseToAnyPublisher() // CLEAN, use a real APIError
        }

        typealias FutureFirst = AnyPublisher<(URL, Status), APIError>
        var sequence: [FutureFirst] = []
        for url in urls {
            let statusFuture: Future<Status, APIError> = manager(for: url).status(callbackQueue: callbackQueue, progress: progress)
            let future: FutureFirst = statusFuture.map { (url, $0) }.eraseToAnyPublisher()
            sequence.append(future)
        }
        return sequence.firstCompleted()
    }

    static func firstStatusSuccess(for urls: [URL], callbackQueue: DispatchQueue? = nil, progress: ProgressHandler? = nil) -> AnyPublisher<(URL, Status), APIError> {
        var urls = urls.slice // popable

        guard let firstURL: URL = urls.popFirst() else {
            assertionFailure("no url provided")
            return Future<(URL, Status), APIError>(error: APIError.error(from: NSError(domain: "qmobile", code: 700))).eraseToAnyPublisher() // CLEAN, use a real APIError
        }

        typealias FutureFirst = AnyPublisher<(URL, Status), APIError>
        let future: FutureFirst = APIManager(url: firstURL).status(callbackQueue: callbackQueue, progress: progress).map { (firstURL, $0) }.eraseToAnyPublisher()
        // this is sequential with recoverWith, we could do better //
        var current = future
        var currentURL: URL? = urls.popFirst()
        while currentURL != nil {
            if let url  = currentURL {
                let recoverTask: ((APIError) -> FutureFirst) = { error -> FutureFirst in
                    return manager(for: url).status(callbackQueue: callbackQueue, progress: progress).map { (url, $0) }.eraseToAnyPublisher()
                }
                // CLEAN simplify code
                if let callbackQueue = callbackQueue {
                    current = current.receive(on: callbackQueue).catch(recoverTask).eraseToAnyPublisher()
                } else {
                    current = current.catch(recoverTask).eraseToAnyPublisher()
                }
            }
            currentURL = urls.popFirst()
        }
        return current
    }*/

    private static func manager(for url: URL) -> APIManager {
        let apiManager = APIManager(url: url)
        apiManager.stub = APIManager.instance.stub
        apiManager.stubDelegate = APIManager.instance.stubDelegate
        // XXX copy other fields? , move this method into API?
        return apiManager
    }
}
