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

let kkeyMapping = "keyMapping"
extension DataStoreTableInfo {

    var originalName: String {
        if let name = self.userInfo?[kkeyMapping] as? String {
            return name
        }
        return self.name
    }

    var api: Table {
        var table = Table(name: self.originalName)
        table.className = self.originalName
        table.collectionName = "\(self.originalName)Collection"
        table.scope = "public"
        table.dataURI = "/rest/\(self.originalName)"

        let fields = self.fields.map { $0.api }
        let relations = self.relationshipsByName.values.map { $0.api }
        table.attributes = (fields + relations).dictionary { $0.name }

        if let primaryKey = self.userInfo?["primary_key"] as? String {
            let json = JSON(primaryKey)
            if let array = json.array {
                table.keys = [:]
                for element in array {
                    if let name = element["field_name"].string {
                        table.keys[name] = Key(name: name, attribute: table.attributes[name])
                    }
                }
            } else {
                if let name = json["field_name"].string {
                    table.keys[name] = Key(name: name, attribute: table.attributes[name])
                }
            }
        }

        if let methods = self.userInfo?["methods"] as? [String] {
            table.methods = methods.map { TableMethod(name: $0) }
        }

        return table
    }

 }

extension DataStoreFieldInfo {

    var originalName: String {
        if let name = self.userInfo?["keyMapping"] as? String {
            return name
        }
        return self.name
    }
    var api: Attribute {

        // if storage
        var attribute = Attribute(
            name: self.originalName,
            kind: .storage,
            scope: .public,
            type: self.type.api(userInfo: self.userInfo)
        )
        if originalName != self.name {
            attribute.nameTransformer = AttributeNameTransformer(encoded: originalName, decoded: name)
        }

        attribute.indexed = self.userInfo?["indexed"] as? Bool ?? false
        attribute.identifying = self.userInfo?["identifying"] as? Bool ?? false
        attribute.simpleDate = self.userInfo?["simpleDate"] as? Bool ?? (self.type == .date)
        return attribute
    }

}

extension DataStoreFieldType {
    func api(userInfo: [AnyHashable: Any]?) -> AttributeStorageType {
        switch self {
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
            if let isType = userInfo?["integer"] as? Bool, isType {
                return .word
            }
            return .long
        case .integer64:
            if let isType = userInfo?["duration"] as? Bool, isType {
                return .duration
            }
            return .long64
        case .transformable:
            if let isType = userInfo?["image"] as? Bool, isType {
                return .image
            }
            return .object
        case .undefined:
            return .string
        case .objectID:
            return .string
        case .decimal:
            return .float // not used
        case .integer16:
            return .long // not used
        }
        return .string
    }
}

extension DataStoreRelationInfo {
    var originalName: String {
        if let name = self.userInfo?["keyMapping"] as? String {
            return name
        }
        return self.name
    }
    var api: Attribute {
        let type = AttributeRelativeType(rawValue: self.destinationTable?.name ?? "") // FIX it
        let kind: AttributeKind = .relatedEntity // FIX it, according to link could be a .relatedEntities
        // type.many ?
        let attr = Attribute(
            name: self.originalName,
            kind: kind,
            scope: .public,
            type: type
        )
        // attr.path, reversePath ?
        return attr
    }
}
