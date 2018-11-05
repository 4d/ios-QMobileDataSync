//
//  DataSync+Notification.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 18/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

public extension Notification.Name {

    // Notify data sync begin
    public static let dataSyncBegin = Notification.Name("dataSync.begin")
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

    func wrap(completionHandler: @escaping SyncCompletionHandler) -> SyncCompletionHandler {
        return { result in
            completionHandler(result)

            switch result {
            case .success:
                Notification(name: .dataSyncSuccess).post()
                self.delegate?.didDataSyncEnd(tables: self.tables)
            case .failure(let error):
                Notification(name: .dataSyncFailed, object: error).post()
                self.delegate?.didDataSyncFailed(error: error)
            }
        }

    }

    func dataSyncBegin() -> Bool {
        Notification(name: .dataSyncBegin, object: self.tables).post()
        return self.delegate?.willDataSyncBegin(tables: self.tables) ?? false
    }

    func dataSyncBegin(for table: Table) {
        logger.debug("Load records for \(table.name)")
        Notification(name: .dataSyncForTableBegin, object: table).post()
        self.delegate?.willDataSyncBegin(for: table)
    }

    func dataSyncEnd(for table: Table, with pageInfo: PageInfo) {
        logger.debug("Receive page '\(pageInfo)' for table '\(table.name)'")
        self.delegate?.didDataSyncEnd(for: table, page: pageInfo)
        Notification(name: .dataSyncForTableSuccess, object: (table, pageInfo)).post()
    }

    func dataSyncFailed(for table: Table, with error: APIError) {
        var errorMessage = "\(error)"
        if let requestCase = error.requestCase {
            errorMessage = "\(requestCase) (\(error.localizedDescription))"
        }
        logger.warning("Failed to get records for table \(table.name): \(errorMessage)")
        if let response = error.responseString {
            logger.warning("with response \(response)")
        }

        let dataSyncError: DataSyncError = .apiError(error)
        Notification(name: .dataSyncForTableFailed, object: (table, dataSyncError)).post()
        self.delegate?.didDataSyncFailed(for: table, error: dataSyncError)
    }
}
