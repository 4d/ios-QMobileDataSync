//
//  DataSync+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Combine
import Moya

import QMobileAPI
import QMobileDataStore

extension DataSync {

    public func loadTable(on callbackQueue: DispatchQueue? = nil) -> SyncTableFuture {
        if !self.tables.isEmpty {
            return SyncTableFuture(result: .success(self.tables)) // cache
        }
        return SyncTableFuture { self.loadTable(on: callbackQueue, $0) }
    }

    public func loadRemoteTable(on callbackQueue: DispatchQueue? = nil) -> SyncTableFuture {
        return SyncTableFuture { _ = self.loadRemoteTable(on: callbackQueue, $0) }
    }

    public func sync(in dataStoreContextType: DataStoreContextType = .background, on callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future<Void, DataSyncError> { _ = self.sync(in: dataStoreContextType, on: callbackQueue, $0) }
    }

    public func drop(in dataStoreContextType: DataStoreContextType = .background, on callbackQueue: DispatchQueue? = nil) -> Future<Void, DataSyncError> {
        return Future<Void, DataSyncError> { _ = self.drop(in: dataStoreContextType, on: callbackQueue, $0) }
    }

}
