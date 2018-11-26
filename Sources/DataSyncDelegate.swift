//
//  DataSyncDelegate.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI

/// Delegate protocol for DataSync. Follow all sync progression
public protocol DataSyncDelegate: NSObjectProtocol {

    /// Notify data sync will begin.
    func willDataSyncWillBegin(tables: [Table], operation: DataSync.Operation)

    /// Notify data sync did begin.
    /// return a bool to stop sync if needed
    func willDataSyncDidBegin(tables: [Table], operation: DataSync.Operation) -> Bool

    /// sync begin for one table.
    func willDataSyncBegin(for table: Table, operation: DataSync.Operation)

    /// each page is published.
    func dataSync(for table: Table, page: PageInfo, operation: DataSync.Operation)

    /// table sync end with success.
    func didDataSyncEnd(for table: Table, page: PageInfo, operation: DataSync.Operation)
    /// table sync end with error.
    func didDataSyncFailed(for table: Table, error: DataSyncError, operation: DataSync.Operation)

    /// notify sync end with success.
    func didDataSyncEnd(tables: [Table], operation: DataSync.Operation)
    /// notify sync failed
    func didDataSyncFailed(error: DataSyncError, operation: DataSync.Operation)

}
