//
//  Array+Dictionary.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Moya

extension Array {

    var indexedDictionary: [Int: Element] {
        var result: [Int: Element] = [:]
        enumerated().forEach({ result[$0.offset] = $0.element })
        return result
    }

    func dictionary<T: Hashable>(key: (Element) -> T) -> [T: Element] {
        var result: [T: Element] = [:]
        self.forEach({ result[key($0)] = $0 })
        return result
    }

    /// Create a dictionary from this array.
    ///
    /// - parameter key: A closure to get hashing key from array values.
    ///
    /// - returns: the dictionary
    func dictionaryBy<T: Hashable>(key: (Element) -> T) -> [T: [Element]] {
        var result: [T: [Element]] = [:]
        self.forEach {
            let keyValue = key($0)
            if result[keyValue] == nil {
                result[keyValue] = []
            }
            result[keyValue]?.append($0)
        }
        return result
    }
}

extension Array where Element: Hashable {

    var hashDictionary: [Int: Element] {
        var result: [Int: Element] = [:]
        self.forEach({ result[$0.hashValue] = $0 })
        return result
    }

}

extension Array {
    var slice: ArraySlice<Element> {
        return self[self.indices]
    }
}

func dict<K, V>(_ tuples: [(K, V)]) -> [K: V] {
    var dict: [K: V] = [K: V]()
    tuples.forEach {dict[$0.0] = $0.1}
    return dict
}
