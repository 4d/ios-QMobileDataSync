//
//  DataSync+Cancellable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 09/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Moya // Cancellable

private let goOn = true
extension DataSync: Cancellable {
    public func cancelOrWait(operation: Operation) -> Bool {
        guard let process = self.process else { return goOn }
        if process.isCancelled {
            return goOn
        }
        switch operation {
        case .reload:
            cancel()
            return goOn
        case .sync:
            switch process.operation {
            case .reload:
                // wait
                logger.warning("A \(process.operation.description) is in progress. The \(operation.description) will be cancelled.")
                return false
            case .sync:
                cancel()
                return goOn
            }
        }
    }

    /// Cancel any data synchornization operation.
    public func cancel() {
        process?.cancel()
        process = nil
    }

    /// Is the current process cancelled or no operation is launched.
    public var isCancelled: Bool { return process?.isCancelled ?? true }
}
