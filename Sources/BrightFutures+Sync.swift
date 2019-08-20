//
//  AsyncType+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import BrightFutures
import Moya

extension AsyncType {

    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(_ timeout: TimeInterval) -> Self.Value? {
        return forced(DispatchTime.now() + timeout)
    }

}

extension AsyncType where Self.Value: ResultProtocol {

    public func resultify() -> Future<Self.Value, Swift.Never> {
        let promise = Promise<Self.Value, Swift.Never>()
        _ = self.andThen { result in
            let resultified: Result<Self.Value, Swift.Never> = .success(result)
            promise.complete(resultified)
        }
        return promise.future
    }

    /*public func resultify2() -> Future<Self.Value, Swift.Never> {
        let future: Future<Result<Value.Value, Value.Error>, Value.Error> = self.map {
            return .success($0)
        }

        let Never = future.recover { error -> Result<Value.Value, Value.Error> in
            return .failure(error)
        }

        return Never
    }*/

}

public class FutureContainer<V, T, E>: Async<Result<T, E>> where E: Swift.Error {

    public  var value: V?
    public var future: Future<T, E>?

    init(resolver: (@escaping (Result<T, E>) -> Swift.Void) -> V) {
        super.init()
        future = Future { completionCallback in
            self.value = resolver(completionCallback)
        }
    }

    public required init(resolver: (@escaping (Value) -> Void) -> Void) {
        super.init()
        future = Future(resolver: resolver)
    }

    public required init<A>(other: A) where A: AsyncType, A.Value == Value {
        super.init()
        future = Future(other: other)
    }

    public required init() {
        super.init()
    }

    public required init(result: Value, delay: DispatchTimeInterval) {
        super.init()
        future = Future(result: result, delay: delay)
    }

    public required init(result: Value) {
        super.init()
        future = Future(result: result)
    }

}

extension FutureContainer where V == Cancellable {

    public func cancel() {
        self.value?.cancel()
    }

    public var isCancelled: Bool {
        return self.value?.isCancelled ?? true
    }

}
/*
extension AsyncType where Self.Value: ResultProtocol {

    @discardableResult
    public func onSuccess(_ queue: DispatchQueue, callback: @escaping (Self.Value -> Swift.Void) -> Self {
        return self.onSuccess(queue.context, callback: callback)
    }

    @discardableResult
    public func onFailure(_ queue: DispatchQueue, callback: @escaping (Self.Error) -> Swift.Void) -> Self {
        return self.onFailure(queue.context, callback: callback)
    }

}
*/
