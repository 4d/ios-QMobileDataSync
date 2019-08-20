//
//  Sequence+Result.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import BrightFutures

extension Sequence where Iterator.Element: ResultProtocol {

    public typealias ResultSequence = Result<[Iterator.Element.Value], Iterator.Element.Error>

    public var result: ResultSequence {
        return reduce(Result(value: [])) { (res, elem) -> ResultSequence in
            switch res {
            case .success(let resultSequence):
                return elem.result.analysis(ifSuccess: {
                    let newSeq = resultSequence + [$0]
                    return Result(value: newSeq)
                }, ifFailure: {
                    return Result(error: $0)
                })
            case .failure:
                return res
            }
        }
    }

    public var errors: [Iterator.Element.Error]? {
        var errors: [Iterator.Element.Error] = []
        for result in self {
            if let error = result.result.error {
                errors.append(error)
            }
        }
        return errors.isEmpty ? nil : errors
    }

    public var values: [Iterator.Element.Value]? {
        var values: [Iterator.Element.Value] = []
        for result in self {
            if let value = result.result.value {
                values.append(value)
            }
        }
        return values.isEmpty ? nil : values
    }

    public func dematerialize() throws -> [Iterator.Element.Value] {
        return try self.result.get()
    }

    public func analysis(ifSuccess: ([Iterator.Element.Value]) -> ResultSequence, ifFailure: (Iterator.Element.Error) -> ResultSequence) -> ResultSequence {
        return self.result.analysis(ifSuccess: ifSuccess, ifFailure: ifFailure)
    }

}
