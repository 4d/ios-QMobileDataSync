//
//  NSManagedObject+Importable.swift
//  QMobileAPI
//
//  Created by Eric Marchand on 30/03/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI

// CLEAN move else where ???
import CoreData

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

    public func isRelationship(key: String) -> Bool {
        return self.entity.relationshipsByName[key] != nil
    }

    public func isAttribute(key: String) -> Bool {
        return self.entity.attributesByName[key] != nil
    }

    public func `import`(attribute: Attribute, value: Any?, with mapper: AttributeValueMapper, parse: (JSON, RecordImportable, AttributeValueMapper, String?) -> Void) {
        let key = attribute.safeName
        if let type = attribute.type as? AttributeRelativeType, isRelationship(key: key) { // AND destination is related entity on core data!!!

           /* guard let context = self.managedObjectContext else { return }
            let relationTableName = type.relationTable
            guard let relationTable = DataSync.instance.table(for: relationTableName) else { return }
            guard let relationTableInfo = DataSync.instance.tablesInfoByTable[relationTable] else { return }
            //guard let relationTableInfo = context.tableInfo(for: tableName) else { return }

            let initializer = DataSync.instance.recordInitializer(table: relationTable, tableInfo: relationTableInfo, context: context)

            if let value = value {
                let entity = JSON(value)
                if let importable = initializer(tableName, entity) {
                    parse(entity, importable, mapper, tableName)
                }
            } else {
                // XXX remove link?
            }*/
        } else {
            if has(key: key) {
                let transformedValue = mapper.map(value, with: attribute)
                self.setValue(transformedValue, forKey: key)
            } else {
                logger.debug("Trying to set unknown property \(key) to \(self.tableName) object")
            }
        }
    }

    public func importPrivateAttribute(key: String, value: Any?) {
        let newKey = keyPrivateCoreDataField + key
        if self.entity.propertiesByName[newKey] != nil {
            self.setValue(value, forKey: newKey)
        } else if !key.hasPrefix("__") {
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
        if self.entity.propertiesByName[newKey] != nil {
            return self.value(forKey: newKey)
        }
        return nil
    }

}
