//
//  Dictionary+KeyPath.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/08/2020.
//  Copyright © 2020 Eric Marchand. All rights reserved.
//

import Foundation

public struct KeyPath {
    var segments: [String]

    var isEmpty: Bool { return segments.isEmpty }
    var path: String {
        return segments.joined(separator: ".")
    }

    func headAndTail() -> (head: String, tail: KeyPath)? {
        guard !isEmpty else { return nil }
        var tail = segments
        let head = tail.removeFirst()
        return (head, KeyPath(segments: tail))
    }
}

/// Initializes a KeyPath with a string of the form "this.is.a.keypath"
extension KeyPath {
    init(_ string: String) {
        segments = string.components(separatedBy: ".")
    }
}

extension KeyPath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
}

// Needed because Swift 3.0 doesn't support extensions with concrete
// same-type requirements (extension Dictionary where Key == String).
public protocol StringProtocol {
    init(string s: String)
}

extension String: StringProtocol {
    public init(string s: String) {
        self = s
    }
}

public extension Dictionary where Key: StringProtocol {
    subscript(keyPath keyPath: KeyPath) -> Any? {
        switch keyPath.headAndTail() {
        case nil:
            // key path is empty.
            return nil
        case let (head, remainingKeyPath)? where remainingKeyPath.isEmpty:
            // Reached the end of the key path.
            let key = Key(string: head)
            return self[key]
        case let (head, remainingKeyPath)?:
            // Key path has a tail we need to traverse.
            let key = Key(string: head)
            switch self[key] {
            case let nestedDict as [Key: Any]:
                // Next nest level is a dictionary.
                // Start over with remaining key path.
                return nestedDict[keyPath: remainingKeyPath]
            default:
                // Next nest level isn't a dictionary.
                // Invalid key path, abort.
                return nil
            }
        }
    }
}
