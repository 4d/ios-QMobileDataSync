//
//  NSManagedObject+Importable.swift
//  QMobileAPI
//
//  Created by Eric Marchand on 30/03/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import QMobileDataStore

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
            logger.warning("Trying to set unknown property \(key) to \(self.tableName) object")
            return
        }
        if let type = attribute.type as? AttributeRelativeType, isRelation(key: key) { // AND destination is related entity on core data!!!
            guard let context = self.managedObjectContext else { return }
            let relationTableName = type.relationTable
            guard let relationBuilder = DataSyncBuilder(tableName: relationTableName, context: context) else {
                logger.warning("Cannot get info for relation table \(relationTableName)")
                return
            }
            relationBuilder.isRelation = true

            if let value = value {
                var json = JSON(value)
                if !json.isNull {
                    let parser = relationBuilder.table.parser
                    if type.isToMany {
                        do {
                            json[ImportKey.entityModel] = JSON(relationBuilder.table.name) // add missing value
                            let relationEntities = try parser.parseArray(json: json, using: mapper, with: relationBuilder).map { $0.store /* get core data object */ }
                            if relationEntities.count != json[ImportKey.count].intValue {
                                logger.warning("Import relation of type \(relationBuilder.table.name) into \(tableName): \(relationEntities.count) , but expected \(json[ImportKey.count])")
                            }
                            logger.debug("Import relation of type \(relationBuilder.table.name) into \(tableName): \(relationEntities.count) , expected \(json[ImportKey.count])")
                            if logger.isEnabledFor(level: .verbose) {
                                logger.verbose("json \(json)")
                            }
                            let set = self.mutableSetValue(forKey: key)
                            set.removeAllObjects() // maybe before remove, make a conciliation for perd
                            for relationEntity in relationEntities {
                                set.add(relationEntity)
                            }
                            // or maybe change the set?
                            // self.setValue(NSSet(array: relationEntities), forKey: key) // tips: if ordered NSOrderedSet
                        } catch {
                            logger.warning("Failed to import relation of type \(relationBuilder.table.name) into \(tableName): \(error)")
                        }
                    } else {
                        if let first = json[ImportKey.entities].array?.first {
                            logger.warning("Trying to import toMany relation to a toOne relation. Only the first one will be imported: \(tableName) -> \(relationBuilder.table.name))")
                            json = first
                        }

                        if let importable = relationBuilder.recordInitializer(relationTableName, json) {
                            parser.parse(json: json, into: importable, using: mapper, tableName: relationTableName)
                            self.setValue(importable.store, forKey: key)
                        }
                    }
                } else {
                    // XXX remove link?
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

extension JSON {
    var isNull: Bool {
        return self.type == .null
    }
}
