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

    /// Return the queue of context.
    var queue: DispatchQueue {
        return self.type.queue
    }

}

extension DataStoreContextType {

    /// Return the queue used according to context type.
    var queue: DispatchQueue {
        switch self {
        case .foreground: return .main
        case .background: return .background
        }
    }

}
