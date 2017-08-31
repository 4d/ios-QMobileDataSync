//
//  DataSyncError.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import QMobileDataStore
import Result

public enum DataSyncError: Swift.Error {
    /// Data sync object is no more retained in memory
    case retain

    /// Sync delegate request stop of process before starting it
    case delegateRequestStop

    /// Data store is not ready to perform operation
    case dataStoreNotReady
    /// Data store error, for instance cannot load it
    case dataStoreError(DataStoreError)

    /// An error occurs when synchronizing
    case apiError(Error)
    /// Loading tables failed, check your tables structures
    case noTables
    /// Missing tables on remote server to synchronize. App not up to date?
    case missingRemoteTables([Table])
}

extension DataSyncError: ErrorConvertible {

    public static func error(from underlying: Swift.Error) -> DataSyncError {
        if let apiError = underlying as? APIError {
            return .apiError(apiError)
        } else if let dataStoreError = underlying as? DataStoreError {
            return .dataStoreError(dataStoreError)
        } else {
            return .apiError(underlying)
        }
    }

    /// The underlying error if any.
    var error: Swift.Error? {
        switch self {
        case .dataStoreError(let error):
            return error
        case .apiError(let error):
            return error
        default:
            return nil
        }
    }
}

extension String {
    var localized: String {
        return localized(with: "")
    }
    func localized(with comment: String = "") -> String {
        return NSLocalizedString(self, bundle: Bundle(for: DataSync.self), comment: comment)
    }
}

extension DataSyncError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .retain:
            return "dataSync.retain".localized
        case .delegateRequestStop:
            return "dataSync.delegateRequestStop".localized
        case .dataStoreNotReady:
            return "dataSync.dataStoreNotReady".localized
        case .dataStoreError:
            return "dataSync.dataStoreError".localized
        case .apiError:
            return "dataSync.apiError".localized
        case .noTables:
            return "dataSync.noTables".localized
        case .missingRemoteTables:
            return "dataSync.missingRemoteTables".localized
        }
    }

    public var failureReason: String? {
        if let error = self.error as? LocalizedError {
            return error.failureReason ?? error.errorDescription
        } else if let error = self.error {
            return error.localizedDescription
        }
        return nil
    }

    public var recoverySuggestion: String? {
        if let error = self.error as? LocalizedError {
            return error.recoverySuggestion
        }
        switch self {
        case .noTables:
            return "dataSync.noTables.recover".localized
        case .missingRemoteTables:
            return "dataSync.missingRemoteTables.recovery".localized
        default:
            return nil
        }
    }

    public var helpAnchor: String? {
        return nil
    }
}
