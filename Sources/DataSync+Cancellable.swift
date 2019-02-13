//
//  DataSync+Cancellable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 09/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Moya // Cancellable

extension DataSync: Cancellable {

    /// Cancel any data synchornization operation.
    public func cancel() {
        process?.cancel()
        process = nil
    }

    /// Is the current process cancelled or no operation is launched.
    public var isCancelled: Bool { return process?.isCancelled ?? true }
}
