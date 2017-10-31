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

extension DataStoreTableInfo {

    var originalName: String {
        if let name = self.userInfo?["keyMapping"] as? String {
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
            type: self.type.api
        )
        attribute.indexed = self.userInfo?["indexed"] as? Bool ?? false
        attribute.identifying = self.userInfo?["identifying"] as? Bool ?? false
        attribute.simpleDate = self.userInfo?["simpleDate"] as? Bool ?? (self.type == .date)
        return attribute
    }

}

extension DataStoreFieldType {
    var api: AttributeStorageType {
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
