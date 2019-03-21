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

    public func loadTable(on callbackQueue: DispatchQueue? = nil) -> Future<[Table], DataSyncError> {
        if !self.tables.isEmpty {
            return Future<[Table], DataSyncError>(result: .success(self.tables))
        }
        return Future { _ = self.loadTable(on: callbackQueue, $0) }
    }

    public func sync(in dataStoreContextType: DataStoreContextType = .background, on callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future { _ = self.sync(in: dataStoreContextType, on: callbackQueue, $0) }
    }

    public func reload(in dataStoreContextType: DataStoreContextType = .background, on callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future { _ = self.reload(in: dataStoreContextType, on: callbackQueue, $0) }
    }

    public func drop(in dataStoreContextType: DataStoreContextType = .background, on callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future { _ = self.drop(in: dataStoreContextType, on: callbackQueue, $0) }
    }

}
