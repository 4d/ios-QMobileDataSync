import Foundation
import ObjectiveC

public typealias DataStoreRepresentation = [String: Any]

class DataStoreRepresentationUtility {

    static func rootForKeyPath(_ representation: Any?, _ keyPath: String?) -> Any? {
        if let keyPath = keyPath, !keyPath.isEmpty {
            if let object = (representation as? NSObject) {
                return object.value(forKeyPath: keyPath)
            }
            /*if let object = representation as? NSDictionary { // CHECK perf, conversion ?
             return object.value(forKeyPath: keyPath)
             }*/
            if let object = representation as? [String: Any] {
                return object[keyPath: KeyPath(keyPath)]
            }
        }
        return representation
    }

    static func collectPresentedPrimaryKeys(_ representation: Any, _ mapping: DataStoreMapping) -> [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>] {
        let flattenMappings = mapping.flatten()

        var map = [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>](minimumCapacity: flattenMappings.count)

        for key in flattenMappings {
            let uniqueIdentifier = key.uniqueIdentifier
            if map[uniqueIdentifier] == nil {
                map[uniqueIdentifier] = Set<DataStoreObjectPrimaryKey>()
            }
        }

        if let root = rootForKeyPath(representation, mapping.rootPath) {
            collectPresentedPrimaryKeys(root, mapping, &map)
        }

        return map
    }

    static func valueForAttribute(_ representation: Any?, _ attribute: DataStoreAttribute) -> Any? {
        var value = representation
        if let representation = representation as? NSObject {
            value = representation.value(forKeyPath: attribute.keyPath)
        }
        if let value = value {
            return attribute.mapValue(value)
        }
        return nil

    }

    static func rootForKeyPath(_ representation: NSObject?, _ keyPath: String?) -> Any? {
        if let keyPath = keyPath, !keyPath.isEmpty {
            return representation?.value(forKeyPath: keyPath)
        }
        return representation
    }

    static func collectPresentedPrimaryKeys(_ representation: Any, _ mapping: DataStoreMapping, _ container: inout [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>]) {
        if let representations = representation as? [DataStoreObject] {
            for object in representations {
                collectObjectPrimaryKeys(object, mapping, &container)
            }
        } else if representation is NSNull {
            // ignore
        } else if (representation is DataStoreObject) || (representation is NSNumber) || (representation is String) {
            collectObjectPrimaryKeys(representation as! NSObject, mapping, &container) // swiftlint:disable:this force_cast
        } else {
            assert(false, "Expected NSArray, NSDictionary, NSNumber or NSString but got: \(type(of: representation))")
        }
    }

    static func collectObjectPrimaryKeys(_ object: NSObject, _ mapping: DataStoreMapping, _ container: inout [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>]) {

        var value: Any?
        if let primaryKeyAttribute1 = mapping.primaryKeyAttribute {
            value = valueForAttribute(object, primaryKeyAttribute1)
        }
        if let value = value as? DataStoreObjectPrimaryKey {
            container[mapping.uniqueIdentifier]?.insert(value)
        }

        for relationship in mapping.relationships ?? [] {

            if let relationshipRepresentation = rootForKeyPath(object, relationship.keyPath), let relationMapping = relationship.mapping {
                collectPresentedPrimaryKeys(relationshipRepresentation, relationMapping, &container)
            }
        }
    }

    static func collectPresentedPrimaryKeys(_ representation: NSObject?, _ mapping: DataStoreMapping) -> [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>] {
        let flattenMappings = mapping.flatten()
        var map = [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>](minimumCapacity: flattenMappings.count)
        for key in flattenMappings {
            let uniqueIdentifier = key.uniqueIdentifier
            if map[uniqueIdentifier] == nil {
                map[uniqueIdentifier] = Set<DataStoreObjectPrimaryKey>()
            }
        }
        if let root = rootForKeyPath(representation, mapping.rootPath ?? "") {
            collectPresentedPrimaryKeys(root, mapping, &map)
        }
        return map
    }

    class func stringRepresentation(_ property: objc_property_t) -> String? {
        guard let propertyType = property_copyAttributeValue(property, "T") else { return nil }
        return String(utf8String: propertyType)
    }

    class func isScalar(_ object: AnyObject, _ propertyName: String) -> Bool {
        // implement it to not set nil to scalar value
        guard let property = class_getProperty(type(of: object), propertyName) else {
            return false
        }
        let type = stringRepresentation(property)
        switch type {
        case "@\"NSDate\"":
            return false
        default:
            logger.verbose("type \(type ?? "")")
            return true
        }
    }
}

extension Array {
    func fromPropertyRepresentation(_ property: objc_property_t?) -> Any {
        var convertedObject: Any = self
        if let property = property, let type = DataStoreRepresentationUtility.stringRepresentation(property) {
            switch type {
            case "@\"NSSet\"":
                convertedObject = NSSet(array: self)
            case "@\"NSMutableSet\"":
                convertedObject = NSMutableSet(array: self)
            case "@\"NSOrderedSet\"":
                convertedObject = NSOrderedSet(array: self)
            case "@\"NSMutableOrderedSet\"":
                convertedObject = NSMutableOrderedSet(array: self)
            case "@\"NSMutableArray\"":
                convertedObject = NSMutableArray(array: self)
            default:
                return convertedObject
            }
        }
        return convertedObject
    }
}
