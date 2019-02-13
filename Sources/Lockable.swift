//
//  Lockable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/02/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI

extension Lockable {

    public func perform(lockedTask task: () -> Void) -> Bool {
        if lock() {
            defer {
                _ = unlock()
            }
            task()
            return true
        }
        return false
    }

}
