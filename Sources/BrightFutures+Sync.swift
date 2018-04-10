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
import Moya

extension AsyncType {

    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(_ timeout: TimeInterval) -> Self.Value? {
        return forced(DispatchTime.now() + timeout)
    }

}

extension AsyncType where Self.Value: ResultProtocol {

    public func resultify() -> Future<Self.Value, NoError> {
        let promise = Promise<Self.Value, NoError>()
        _ = self.andThen { result in
            let resultified: Result<Self.Value, NoError> = .success(result)
            promise.complete(resultified)
        }
        return promise.future
    }

    /*public func resultify2() -> Future<Self.Value, NoError> {
        let future: Future<Result<Value.Value, Value.Error>, Value.Error> = self.map {
            return .success($0)
        }

        let noError = future.recover { error -> Result<Value.Value, Value.Error> in
            return .failure(error)
        }

        return noError
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

extension AsyncType where Self.Value: ResultProtocol {

    @discardableResult
    public func onSuccess(_ queue: DispatchQueue, callback: @escaping (Self.Value.Value) -> Swift.Void) -> Self {
        return self.onSuccess(queue.context, callback: callback)
    }

    @discardableResult
    public func onFailure(_ queue: DispatchQueue, callback: @escaping (Self.Value.Error) -> Swift.Void) -> Self {
        return self.onFailure(queue.context, callback: callback)
    }

}
