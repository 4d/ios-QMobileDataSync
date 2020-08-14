//
//  DataStoreFieldInfo+Attribute.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 25/07/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import QMobileDataStore

private enum DataStoreFieldInfoUserInfoKey: String {
    case keyMapping // original name

    case indexed, identifying, simpleDate
    case integer, duration, image

    case path
}

extension DataStoreFieldInfo {

    fileprivate func userInfo(_ key: DataStoreFieldInfoUserInfoKey) -> String? {
        return self.userInfo?[key.rawValue] as? String
    }
    fileprivate func userInfoAsBool(_ key: DataStoreFieldInfoUserInfoKey) -> Bool? {
        guard let string = self.userInfo(key) else {
            return nil
        }
        return Bool(string)
    }

    public var originalName: String {
        return userInfo(.keyMapping) ?? self.name
    }

    var path: String? {
        return userInfo(.path)
    }

    var simpleDate: Bool {
        return self.userInfoAsBool(.simpleDate) ?? false
    }

    var api: Attribute? {
        // Excluse private fields
        if self.name.contains(keyPrivateCoreDataField+"__") {
            return nil
        }

        if let path = self.path {
            // If relation N to 1 used as Transformable
            assert(self.type == .transformable)
            let originalName = self.originalName
            var attribute = Attribute(
                name: originalName,
                kind: .relatedEntity,
                scope: .public,
                type: AttributeRelativeType(rawValue: path)
            )
            attribute.path = path
            if originalName != self.name {
                attribute.nameTransformer = AttributeNameTransformer(encoded: originalName, decoded: name)
            }
            // foreignKey?

            return attribute
        } else {
            // If normal storage
            let originalName = self.originalName
            var attribute = Attribute(
                name: originalName,
                kind: .storage,
                scope: .public,
                type: self.storageType
            )
            if originalName != self.name {
                attribute.nameTransformer = AttributeNameTransformer(encoded: originalName, decoded: name)
            }

            attribute.indexed = self.userInfoAsBool(.indexed) ?? false
            attribute.identifying = self.userInfoAsBool(.identifying) ?? false
            attribute.simpleDate = self.userInfoAsBool(.simpleDate) ?? (self.type == .date)

            return attribute
        }
    }

}

extension DataStoreFieldInfo {

    var storageType: AttributeStorageType {
        switch self.type {
        case .boolean:
            return .bool
        case .string:
            return .string
        case .date:
            return .date
        case .float:
            return .float
        case .double:
            return .number
        case .binary:
            return .blob
        case .integer32:
            return self.userInfoAsBool(.integer) ?? false ? .word: .long
        case .integer64:
            return self.userInfoAsBool(.duration) ?? false ? .duration: .long64
        case .transformable:
            return self.userInfoAsBool(.image) ?? false ? .image: .object
        case .undefined:
            return .string
        case .objectID:
            return .string
        case .decimal:
            return .float // not used
        case .integer16:
            return .long // not used
        }
    }
}
