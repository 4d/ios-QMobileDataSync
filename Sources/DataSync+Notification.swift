//
//  DataSync+Notification.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 18/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

public extension Notification.Name {

    // Notify data sync will begin
    public static let dataSyncWillBegin = Notification.Name("dataSync.will.begin")
    // Notify data sync did begin
    public static let dataSyncDidBegin = Notification.Name("dataSync.did.begin")
    // notify sync end with success
    public static let dataSyncSuccess = Notification.Name("dataSync.success")
    // notify sync failed
    public static let dataSyncFailed = Notification.Name("dataSync.failed")

    // sync begin for one table
    public static let dataSyncForTableBegin = Notification.Name("dataSync.table.begin")
    // each page is published
    public static let dataSyncForTableProgress = Notification.Name("dataSync.table.progress")
    // table sync end with success
    public static let dataSyncForTableSuccess = Notification.Name("dataSync.table.success")
    // table sync end with error
    public static let dataSyncForTableFailed = Notification.Name("dataSync.table.failed")

}

import QMobileAPI

extension DataSync {

    func wrap(_ operation: Operation, completionHandler: @escaping SyncCompletionHandler) -> SyncCompletionHandler {
        return { result in
            completionHandler(result)

            switch result {
            case .success:
                Notification(name: .dataSyncSuccess, object: self, userInfo: ["operation": operation]).post()
                self.delegate?.didDataSyncEnd(tables: self.tables, operation: operation)
            case .failure(let error):
                Notification(name: .dataSyncFailed, object: self, userInfo: [NSUnderlyingErrorKey: error, "operation": operation]).post()
                self.delegate?.didDataSyncFailed(error: error, operation: operation)
            }
        }
    }

    func dataSyncWillBegin(_ operation: Operation) {
        Notification(name: .dataSyncWillBegin, object: self, userInfo: ["tables": self.tables, "operation": operation]).post()
        self.delegate?.willDataSyncWillBegin(tables: self.tables, operation: operation)
    }

    func dataSyncDidBegin(_ operation: Operation) -> Bool {
        Notification(name: .dataSyncDidBegin, object: self, userInfo: ["tables": self.tables, "operation": operation]).post()
        return self.delegate?.willDataSyncDidBegin(tables: self.tables, operation: operation) ?? false
    }

    func dataSyncBegin(for table: Table, _ operation: Operation) {
        logger.debug("Load records for \(table.name)")
        Notification(name: .dataSyncForTableBegin, object: self, userInfo: ["table": table, "operation": operation]).post()
        self.delegate?.willDataSyncBegin(for: table, operation: operation)
    }

    func dataSyncEnd(for table: Table, with pageInfo: PageInfo, _ operation: Operation) {
        logger.debug("Receive page '\(pageInfo)' for table '\(table.name)'")
        self.delegate?.didDataSyncEnd(for: table, page: pageInfo, operation: operation)
        Notification(name: .dataSyncForTableSuccess, object: self, userInfo: ["table": table, "pageInfo": pageInfo, "operation": operation]).post()
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
        Notification(name: .dataSyncForTableFailed, object: self, userInfo: ["table": table, NSUnderlyingErrorKey: dataSyncError, "operation": operation]).post()
        self.delegate?.didDataSyncFailed(for: table, error: dataSyncError, operation: operation)
    }
}
