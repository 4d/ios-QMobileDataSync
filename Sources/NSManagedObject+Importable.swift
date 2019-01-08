//
//  NSManagedObject+Importable.swift
//  QMobileAPI
//
//  Created by Eric Marchand on 30/03/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI

import CoreData

// key to previx private fields (start with __ on rest 4d api)
let keyPrivateCoreDataField = "qmobile"

extension NSManagedObject: RecordImportable {

    public var tableName: String {
        if let name = self.entity.userInfo?["keyMapping"] as? String {
            return name
        }
        return self.entity.name ?? ""
    }

    public func has(key: String) -> Bool {
        return self.entity.propertiesByName[key] != nil
    }

    public func isRelation(key: String) -> Bool {
        return self.entity.relationshipsByName[key] != nil
    }

    public func isField(key: String) -> Bool {
        return self.entity.attributesByName[key] != nil
    }

    public func set(attribute: Attribute, value: Any?, with mapper: AttributeValueMapper) {
        let key = attribute.safeName
        guard has(key: key) else {
            logger.debug("Trying to set unknown property \(key) to \(self.tableName) object")
            return
        }
        if let type = attribute.type as? AttributeRelativeType, isRelation(key: key) { // AND destination is related entity on core data!!!

            let relationTableName = type.relationTable
            //guard let relationTableInfo = context.tableInfo(for: relationTableName) else { return }
            //let relationTable = relationTableInfo.api
            guard let relationTable = DataSync.instance.table(for: relationTableName) else { return }
            guard let relationTableInfo = DataSync.instance.tablesInfoByTable[relationTable] else { return }

            guard let context = self.managedObjectContext else { return }
            let initializer = DataSync.recordInitializer(table: relationTable, tableInfo: relationTableInfo, context: context)

            if let value = value {
                let parser = relationTable.parser
                let json = JSON(value)
                if type.many {
                   // parser.parseArray(json: json, using: mapper,with : initializer)
                } else {
                    if let importable = initializer(relationTableName, json) {
                        parser.parse(json: json, into: importable, using: mapper, tableName: relationTableName)
                        self.setValue(importable.store, forKey: key)
                    }
                }
            } else {
                // XXX remove link?
            }
        } else {
            let transformedValue = mapper.map(value, with: attribute)
            self.setValue(transformedValue, forKey: key)
        }
    }

    public func setPrivateAttribute(key: String, value: Any?) {
        /// prefix private key with a constant. could not start with __
        let newKey = keyPrivateCoreDataField + key
        if has(key: newKey) {
            self.setValue(value, forKey: newKey)
        } else if !key.hasPrefix(RestKey.reserved) {
            logger.verbose {"Skipped property \(key) for \(self.tableName) object. Not defined in model. You can add it" }
        }
    }

    public func get(attribute: Attribute, with mapper: AttributeValueMapper) -> Any? {
        let key = attribute.safeName
        if has(attribute: attribute), attribute.storageType != nil {
            let value = self.value(forKey: key)
            let transformedValue = mapper.unmap(value, with: attribute)
            return transformedValue
        } else {
            return nil
        }
    }

    public func getPrivateAttribute(key: String) -> Any? {
        let newKey = keyPrivateCoreDataField + key
        if has(key: newKey) {
            return self.value(forKey: newKey)
        }
        return nil
    }

}
