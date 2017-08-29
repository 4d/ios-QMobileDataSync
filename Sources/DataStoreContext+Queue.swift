//
//  DataStore+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileDataStore

extension DataStoreContext {

    var queue: DispatchQueue {
        return self.type.queue
    }

}

extension DataStoreContextType {

    var queue: DispatchQueue {
        switch self {
        case .foreground: return .main
        case .background: return .background
        }
    }

}
