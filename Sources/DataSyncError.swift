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

public enum DataSyncError: Swift.Error {
    /// Data sync object is no more retained in memory
    case retain

    /// Sync delegate request stop of process before starting it
    case delegateRequestStop

    /// Data store is not ready to perform operation
    case dataStoreNotReady
    /// Data store error, for instance cannot load it
    case dataStoreError(DataStoreError)

    /// an error occurs when synchronizing
    case apiError(Error)
    /// Loading tables failed, check your tables structures
    case noTables
    /// Missing tables on remote server to synchronize. App not up to date?
    case missingRemoteTables([Table])
}

extension DataSyncError {

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
