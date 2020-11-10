//
//  Sequence+Result.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

public protocol ResultProtocol {
    associatedtype Value
    associatedtype Error: Swift.Error

    init(value: Value)
    init(error: Error)

    var result: Result<Value, Error> { get }
}

extension Result: ResultProtocol {
    /// Constructs a success wrapping a `value`.
    public init(value: Success) {
        self = .success(value)
    }

    /// Constructs a failure wrapping an `error`.
    public init(error: Failure) {
        self = .failure(error)
    }

    public var result: Result<Success, Failure> {
        return self
    }

    public var value: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }

    public var error: Failure? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }

}

public extension ResultProtocol {

    /// Case analysis for Result.
    ///
    /// Returns the value produced by applying `ifFailure` to `failure` Results, or `ifSuccess` to `success` Results.
    func analysis<Result>(ifSuccess: (Value) -> Result, ifFailure: (Error) -> Result) -> Result {
        switch self.result {
        case .success(let value):
            return ifSuccess(value)
        case .failure(let error):
            return ifFailure(error)
        }
    }

}

extension Sequence where Iterator.Element: ResultProtocol {
    /// Turns a sequence of `Result<T>`'s into a Result with an array of T's (`Result<[T]>`)
    /// If one of the results in the given sequence is a .failure, the returned result is a .failure with the
    /// error from the first failed result from the sequence.
    public func sequence() -> Result<[Iterator.Element.Value], Iterator.Element.Error> {
        return reduce(.success([])) { (res, elem) -> Result<[Iterator.Element.Value], Iterator.Element.Error> in
            switch res {
            case .success(let resultSequence):
                return elem.analysis(ifSuccess: {
                    let newSeq = resultSequence + [$0]
                    return .success(newSeq)
                }, ifFailure: {
                    return .failure($0)
                })
            case .failure:
                return res
            }
        }
    }
}
