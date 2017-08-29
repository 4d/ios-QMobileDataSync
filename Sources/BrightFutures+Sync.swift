//
//  AsyncType+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import BrightFutures
import Result

extension AsyncType {

    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(_ timeout: TimeInterval) -> Self.Value? {
        return forced(DispatchTime.now() + timeout)
    }

}

extension Future {

    public func resultify() -> Future<Result<T, E>, NoError> {
        let promise = Promise<Result<T, E>, NoError>()
        _ = self.andThen { result in
            let resultified: Result<Result<T, E>, NoError> = .success(result)
            promise.complete(resultified)
        }
        return promise.future
    }

}
