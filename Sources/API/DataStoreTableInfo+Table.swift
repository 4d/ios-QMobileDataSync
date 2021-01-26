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
    // has global stamp
    case globalStamp

    // - Rest

    /// Limit request
    case limit
    /// Methods of table
    case methods
    /// Filter for table data
    case filter

}

extension DataStoreTableInfo {

    // MARK: helper methods

    fileprivate func userInfo(_ key: DataStoreTableInfoUserInfoKey) -> String? {
        return self.userInfo?[key.rawValue] as? String
    }

    fileprivate mutating func setUserInfo(_ key: DataStoreTableInfoUserInfoKey, _ value: String) {
        if self.userInfo == nil {
            self.userInfo = [:]
        }
        self.userInfo?[key.rawValue] = value
    }

    fileprivate mutating func setUserInfo(_ key: DataStoreTableInfoUserInfoKey, _ value: Bool) {
        if value {
            setUserInfo(key, "YES")
        } else {
            unsetUserInfo(key)
        }
    }

    fileprivate mutating func unsetUserInfo(_ key: DataStoreTableInfoUserInfoKey) {
        self.userInfo?[key.rawValue] = nil
    }

    // MARK: properties

    public var originalName: String {
        return userInfo(.keyMapping) ?? self.name
    }

    public var filter: String? {
        return userInfo(.filter)
    }

    var limit: String? {
        return userInfo(.limit)
    }

    var hasGlobalStamp: Bool {
        get {
            return userInfo(.globalStamp) == "YES"
        }
        set {
            setUserInfo(.globalStamp, newValue)
        }
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

    // return a predicate to match with primary key and passed values
    public func primaryKeyPredicate(value: Any) -> NSPredicate? {
        guard let primaryKey = self.primaryKeyFieldInfo else {
            return nil
        }
        let lhs = NSExpression(forKeyPath: primaryKey.name)
        let rhs = NSExpression(forConstantValue: value)
        return NSComparisonPredicate(leftExpression: lhs, rightExpression: rhs, modifier: .direct, type: .equalTo, options: [])
    }

    var primaryKeyFieldInfo: DataStoreFieldInfo? {
        guard let primaryKey = primaryKey else {
            return nil
        }
        for field in fields where field.originalName == primaryKey {
            return field
        }
        return nil
    }

    var slave: String? {
        return self.userInfo(.slave)
    }

    var isSlave: Bool {
        return slave != nil
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

    /// Convert data store table info into api object.
    public var api: Table {
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
