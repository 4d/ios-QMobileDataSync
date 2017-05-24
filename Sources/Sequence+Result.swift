//
//  Sequence+Result.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Result

extension Sequence where Iterator.Element: ResultProtocol {
    public func sequence() -> Result<[Iterator.Element.Value], Iterator.Element.Error> {
        return reduce(Result(value: [])) { (res, elem) -> Result<[Iterator.Element.Value], Iterator.Element.Error> in
            switch res {
            case .success(let resultSequence):
                return elem.analysis(ifSuccess: {
                    let newSeq = resultSequence + [$0]
                    return Result(value: newSeq)
                }, ifFailure: {
                    return Result(error: $0)
                })
            case .failure(_):
                return res
            }
        }
    }
}
