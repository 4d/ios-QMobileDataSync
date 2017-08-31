//
//  DataStore+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Result
import BrightFutures
import QMobileDataStore

extension DataStore {

    public typealias PerformFuture = Future<(DataStoreContext, () throws -> Swift.Void), DataStoreError>
    public typealias PerformResult = Result<(DataStoreContext, () throws -> Swift.Void), DataStoreError>

    /// Load the data store and return a Future
    public func load() -> Future<Void, DataStoreError> {
        if isLoaded {
            return Future<Void, DataStoreError>(result: .success())
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
    public func perform(_ type: QMobileDataStore.DataStoreContextType) -> PerformFuture {
        return Future { complete in
            let value = self.perform(type) { val in
                complete(.success(val))
            }
            if !value {
                complete(.failure(DataStoreError(DataStoreStateError.dataStoreNotReady)))
            }
        }
    }

}

/// Error about data store state
public enum DataStoreStateError: Error {
    case dataStoreNotReady
}

extension DataStoreStateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .dataStoreNotReady:
            return "dataStore.notReady".localized
        }
    }
}
