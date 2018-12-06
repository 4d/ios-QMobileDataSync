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

    public func `import`(attribute: Attribute, value: Any?, with mapper: AttributeValueMapper) {
        guard attribute.storageType != nil else {
            return
        }
        let key = attribute.safeName
        if has(key: key) {
            let transformedValue = mapper.map(value, with: attribute)
            self.setValue(transformedValue, forKey: key)
        } else {
            logger.debug("Trying to set unknown property \(key) to \(self.tableName) object")
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
