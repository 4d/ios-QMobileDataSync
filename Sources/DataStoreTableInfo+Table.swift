//
//  DataStoreTableInfo+Table.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 10/10/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import QMobileDataStore

private enum DataStoreTableInfoUserInfoKey: String {
    // - Sync

    ///Original name
    case keyMapping
    /// Information about primary key
    case primaryKey
    /// If defined, only slave table (ie. used with relation only)
    case slave

    // - Rest

    /// Limit request
    case limit
    /// Methods of table
    case methods
    /// Filter for table data
    case filter

}

extension DataStoreTableInfo {

    fileprivate func userInfo(_ key: DataStoreTableInfoUserInfoKey) -> String? {
        return self.userInfo?[key.rawValue] as? String
    }

    var originalName: String {
        return userInfo(.keyMapping) ?? self.name
    }

    var filter: String? {
        return userInfo(.filter)
    }

    var limit: String? {
        return userInfo(.limit)
    }

    var methods: [TableMethod] {
        guard let methods = userInfo(.methods) else {
            return []
        }
        return methods.split(separator: ",").map { TableMethod(name: String($0)) }
    }

    var primaryKey: String? {
        return self.userInfo(.primaryKey)
    }

    var slave: String? {
        return self.userInfo(.slave)
    }

    func keys(for table: Table) -> [String: Key] {
        guard let primaryKey = self.primaryKey else {
            assertionFailure("No primary key defined in core data model using key primary_key")
            return [:]
        }
        var keys: [String: Key] = [:]
        let json = JSON(parseJSON: primaryKey)
        if let array = json.array {
            for element in array {
                if let name = element["field_name"].string/*, attributesKey.contains(name)*/ {
                    keys[name] = Key(name: name, attribute: table.attributes[name])
                }
            }
        } else if let name = json["field_name"].string/*, attributesKey.contains(name)*/ {
            keys[name] = Key(name: name, attribute: table.attributes[name])
        } else /*if attributesKey.contains(primaryKey)*/ {
            keys[primaryKey] = Key(name: primaryKey, attribute: table.attributes[primaryKey])  // simple string without json
        }
        return keys
    }

    var api: Table {
        let originalName = self.originalName
        var table = Table(name: originalName)
        table.className = originalName
        table.collectionName = "\(originalName)Collection"
        table.scope = "public"
        table.dataURI = "/\(APIManager.instance.base.path)/\(originalName)"

        let fields = self.fields.compactMap { $0.api }
        let relations = self.relationships.compactMap { $0.api }
        table.attributes = (fields + relations).dictionary { $0.name }
        table.keys = self.keys(for: table)
        table.methods = self.methods

        return table
    }

}

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

    var originalName: String {
        return userInfo(.keyMapping) ?? self.name
    }

    var path: String? {
        return userInfo(.path)
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

private enum DataStoreRelationInfoUserInfoKey: String {
    case keyMapping // original name
    case path, reversePath
    case expand
}

extension DataStoreRelationInfo {

    fileprivate func userInfo(_ key: DataStoreRelationInfoUserInfoKey) -> Any? {
        return self.userInfo?[key.rawValue]
    }

    var originalName: String {
        return self.userInfo(.keyMapping) as? String ?? self.name
    }

    var api: Attribute {
        var type = AttributeRelativeType(rawValue: self.destinationTable?.name ?? "") // FIX it
        type.isToMany = self.isToMany
        type.expand = self.userInfo(.expand) as? String
        let kind: AttributeKind = isToMany ? .relatedEntities: .relatedEntity

        let originalName = self.originalName
        var attribute = Attribute(
            name: originalName,
            kind: kind,
            scope: .public,
            type: type
        )
        attribute.path = self.userInfo(.path) as? String
        attribute.reversePath = self.userInfo(.reversePath) as? Bool ?? false
        if originalName != self.name {
            attribute.nameTransformer = AttributeNameTransformer(encoded: originalName, decoded: name)
        }

        return attribute
    }
}
