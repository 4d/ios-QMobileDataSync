//
//  DataSync+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import BrightFutures
import Result
import QMobileAPI
import QMobileDataStore

extension DataSync {

    public func loadTable(queue: DispatchQueue? = nil) -> Future<[Table], DataSyncError> {
        if !self.tablesByName.isEmpty {
            return Future<[Table], DataSyncError>(result: .success(self.tables))
        }
        return Future { _ = self.loadTable(queue: queue, $0) }
    }

    public func sync(dataStoreContextType: DataStoreContextType = .background, queue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future { _ = self.sync(dataStoreContextType:dataStoreContextType, queue: queue, $0) }
    }
}
