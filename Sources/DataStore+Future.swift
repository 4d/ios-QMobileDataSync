//
//  DataStore+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import BrightFutures
import Result
import QMobileDataStore

extension DataStore {

    public func load() -> Future<Void, DataStoreError> {
        if isLoaded {
            return Future<Void, DataStoreError>(result: .success())
        }
        return Future { self.load(completionHandler: $0) }
    }

    public func save() -> Future<Void, DataStoreError> {
        return Future { self.save(completionHandler: $0) }
    }

    public func drop() -> Future<Void, DataStoreError> {
        return Future { self.drop(completionHandler: $0) }
    }

  /*  public func perform(_ type: QMobileDataStore.DataStoreContextType) -> Future<(DataStoreContext, () throws -> Swift.Void), DataStoreError> {

        self.perform(type, _ block: @escaping (DataStoreContext, @escaping () throws -> Swift.Void) -> Swift.Void) -> Bool
        
    }*/

}
