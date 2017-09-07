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

    public func loadTable(callbackQueue: DispatchQueue? = nil) -> Future<[Table], DataSyncError> {
        if !self.tablesByName.isEmpty {
            return Future<[Table], DataSyncError>(result: .success(self.tables))
        }
        return Future { _ = self.loadTable(callbackQueue: callbackQueue, $0) }
    }

    public func sync(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future { _ = self.sync(dataStoreContextType:dataStoreContextType, callbackQueue: callbackQueue, $0) }
    }

    public func reload(dataStoreContextType: DataStoreContextType = .background, callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future { _ = self.reload(dataStoreContextType:dataStoreContextType, callbackQueue: callbackQueue, $0) }
    }
}
