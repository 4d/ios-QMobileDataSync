//
//  DataStore+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import BrightFutures
import QMobileDataStore

extension DataStore {

    public typealias PerformFuture = Future<DataStoreContext, DataStoreError>
    public typealias PerformResult = Result<DataStoreContext, DataStoreError>

    /// Load the data store and return a Future
    public func load() -> Future<Void, DataStoreError> {
        if isLoaded {
            return Future<Void, DataStoreError>(result: .success(()))
        }
        return Future { self.load(completionHandler: $0) }
    }

    /// Save the data store and return a Future
    public func save() -> Future<Void, DataStoreError> {
        return Future { self.save(completionHandler: $0) }
    }

    /// Drop the data store and return a Future
    public func drop() -> Future<Void, DataStoreError> {
        return Future { self.drop(completionHandler: $0) }
    }

    /// Provide a context for performing data store operation
    public func perform(_ type: QMobileDataStore.DataStoreContextType, blockName: String? = nil) -> PerformFuture {
        return Future { complete in
            let value = self.perform(type, wait: false, blockName: blockName) { context in
                complete(.success(context))
            }
            if !value {
                complete(.failure(DataStoreError(DataSyncError.dataStoreNotReady)))
            }
        }
    }

}