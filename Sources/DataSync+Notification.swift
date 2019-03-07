//
//  DataSync+Notification.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 18/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Moya // Cancellable
import QMobileAPI

public extension Notification.Name {

    /// Notify data sync will begin
    public static let dataSyncWillBegin = Notification.Name("dataSync.will.begin")
    /// Notify data sync did begin
    public static let dataSyncDidBegin = Notification.Name("dataSync.did.begin")
    // notify sync end with success
    public static let dataSyncSuccess = Notification.Name("dataSync.success")
    /// notify sync failed
    public static let dataSyncFailed = Notification.Name("dataSync.failed")

    /// sync begin for one table
    public static let dataSyncForTableBegin = Notification.Name("dataSync.table.begin")
    /// each page is published
    public static let dataSyncForTableProgress = Notification.Name("dataSync.table.progress")
    /// table sync end with success
    public static let dataSyncForTableSuccess = Notification.Name("dataSync.table.success")
    /// table sync end with error
    public static let dataSyncForTableFailed = Notification.Name("dataSync.table.failed")
}

public extension Notification.Name {

    /// Notify data sync will begin
    public static let dataSyncWillLoad = Notification.Name("dataSync.will.load")
    /// Notify data sync did begin
    public static let dataSyncDidLoad = Notification.Name("dataSync.did.load")

}

extension DataSync {

    /// The key used in the user info dictionary for notifications.
    public struct NotificationUserInfoKey {
        /// The tables synchronized.
        public static let tables = "tables"
        /// The table synchronized.
        public static let table = "table"
        /// The type of operation. `DataSync.Operation`
        public static let operation = "operation"
        /// Optional page information. `PageInfo`
        public static let pageInfo = "pageInfo"
        /// A `Cancellable` to stop the operation.
        public static let cancellable = "cancellable"
        /// stamp of modification.
        public static let stamp = "stamp"
    }

    /// Wrap completion handler to send also notifications.
    func wrap(_ operation: Operation, completionHandler: @escaping SyncCompletionHandler) -> SyncCompletionHandler {
        return { result in
            completionHandler(result)
            switch result {
            case .success:
                logger.debug("Data \(operation) did finish with success")
                Notification(name: .dataSyncSuccess, object: self, userInfo: [NotificationUserInfoKey.operation: operation]).post()
                self.delegate?.didDataSyncEnd(tables: self.tables, operation: operation)
            case .failure(let error):
                logger.debug("Data \(operation) did failed \(error)")
                Notification(name: .dataSyncFailed, object: self, userInfo: [NSUnderlyingErrorKey: error,
                                                                             NotificationUserInfoKey.operation: operation]).post()
                self.delegate?.didDataSyncFailed(error: error, operation: operation)
            }
        }
    }

    func dataSyncWillLoad(_ tables: [Table]) {
        Notification(name: .dataSyncWillLoad, object: self, userInfo: [NotificationUserInfoKey.tables: tables]).post()
        self.delegate?.willDataSyncWillLoad(tables: self.tables)
    }

    func dataSyncDidLoad(_ tables: [Table]) {
        Notification(name: .dataSyncDidLoad, object: self, userInfo: [NotificationUserInfoKey.tables: tables]).post()
        self.delegate?.willDataSyncDidLoad(tables: self.tables)
    }

    func dataSyncWillBegin(_ operation: Operation, cancellable: Cancellable) {
        logger.debug("Data \(operation) will begin")
        Notification(name: .dataSyncWillBegin, object: self, userInfo: [NotificationUserInfoKey.tables: self.tables,
                                                                        NotificationUserInfoKey.operation: operation,
                                                                        NotificationUserInfoKey.cancellable: cancellable]).post()
        self.delegate?.willDataSyncWillBegin(tables: self.tables, operation: operation, cancellable: cancellable)
    }

    func dataSyncDidBegin(_ operation: Operation) -> Bool {
        logger.debug("Data \(operation) did begin")
        Notification(name: .dataSyncDidBegin, object: self, userInfo: [NotificationUserInfoKey.tables: self.tables,
                                                                       NotificationUserInfoKey.operation: operation]).post()
        return self.delegate?.willDataSyncDidBegin(tables: self.tables, operation: operation) ?? false
    }

    func dataSyncBegin(for table: Table, _ operation: Operation) {
        logger.debug("Load records for \(table.name)")
        Notification(name: .dataSyncForTableBegin, object: self, userInfo: [NotificationUserInfoKey.table: table,
                                                                            NotificationUserInfoKey.operation: operation]).post()
        self.delegate?.willDataSyncBegin(for: table, operation: operation)
    }

    func dataSyncEnd(for table: Table, with pageInfo: PageInfo, _ operation: Operation) {
        logger.debug("Receive page '\(pageInfo)' for table '\(table.name)'")
        self.delegate?.didDataSyncEnd(for: table, page: pageInfo, operation: operation)
        Notification(name: .dataSyncForTableSuccess, object: self, userInfo: [NotificationUserInfoKey.table: table,
                                                                              NotificationUserInfoKey.pageInfo: pageInfo,
                                                                              NotificationUserInfoKey.operation: operation]).post()
    }

    func dataSyncFailed(for table: Table, with error: APIError, _ operation: Operation) {
        var errorMessage = "\(error)"
        if let requestCase = error.requestCase {
            errorMessage = "\(requestCase) (\(error.localizedDescription))"
        }
        logger.warning("Failed to get records for table \(table.name): \(errorMessage)")
        if let response = error.responseString {
            logger.warning("with response \(response)")
        }

        let dataSyncError: DataSyncError = .apiError(error)
        Notification(name: .dataSyncForTableFailed, object: self, userInfo: [NotificationUserInfoKey.table: table,
                                                                             NSUnderlyingErrorKey: dataSyncError,
                                                                             NotificationUserInfoKey.operation: operation]).post()
        self.delegate?.didDataSyncFailed(for: table, error: dataSyncError, operation: operation)
    }
}
