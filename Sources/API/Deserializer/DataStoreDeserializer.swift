import CoreData
import Foundation

@objc protocol DataStoreDeserializerDelegate: NSObjectProtocol {
    @objc optional func deserializer(_ deserializer: DataStoreDeserializer, willMapObjectFromRepresentation representation: Any?, mapping: DataStoreMapping)
    @objc optional func deserializer(_ deserializer: DataStoreDeserializer, didMapObject object: DataStoreObject, fromRepresentation representation: Any?, mapping: DataStoreMapping)
    @objc optional func deserializer(_ deserializer: DataStoreDeserializer, willMapCollectionFromRepresentation representation: [DataStoreRepresentation], mapping: DataStoreMapping)
    @objc optional func deserializer(_ deserializer: DataStoreDeserializer, didMapCollection collection: [DataStoreObject], fromRepresentation representation: [DataStoreRepresentation], mapping: DataStoreMapping)
}

public class DataStoreDeserializer: NSObject {
    private struct DelegateFlags {
        var willMapObject: Bool
        var didMapObject: Bool
        var willMapCollection: Bool
        var didMapCollection: Bool
    }

    private var delegateFlags = DelegateFlags(willMapObject: false, didMapObject: false, willMapCollection: false, didMapCollection: false)

    private(set) var transaction: DataStoreObjectTransaction

    public required init(transaction: DataStoreObjectTransaction = DataStoreObjectTransaction()) {
        self.transaction = transaction
        super.init()
    }

    weak var delegate: DataStoreDeserializerDelegate? {
        didSet {
            delegateFlags.willMapObject = delegate?.responds(to: #selector(DataStoreDeserializerDelegate.deserializer(_:willMapObjectFromRepresentation:mapping:))) ?? false
            delegateFlags.didMapObject = delegate?.responds(to: #selector(DataStoreDeserializerDelegate.deserializer(_:didMapObject:fromRepresentation:mapping:))) ?? false
            delegateFlags.willMapCollection = delegate?.responds(to: #selector(DataStoreDeserializerDelegate.deserializer(_:willMapCollectionFromRepresentation:mapping:))) ?? false
            delegateFlags.didMapCollection = delegate?.responds(to: #selector(DataStoreDeserializerDelegate.deserializer(_:didMapCollection:fromRepresentation:mapping:))) ?? false
        }
    }

    public func object(fromRepresentation representation: [AnyHashable: Any], mapping: DataStoreMapping) -> DataStoreObject? {
        beginTransaction(for: mapping, representation: [representation])

        let root = DataStoreRepresentationUtility.rootForKeyPath(representation, mapping.rootPath)
        var object: DataStoreObject?
        if let root = root as? [AnyHashable: Any] {
            object = _object(fromRepresentation: root, mapping: mapping, allocateIfNeeded: true)
        }

        commitTransaction()

        return object
    }

    func fillObject(_ object: DataStoreObject, fromRepresentation representation: [AnyHashable: Any], mapping: DataStoreMapping) -> DataStoreObject? {
        if delegateFlags.willMapObject {
            delegate?.deserializer?(self, willMapObjectFromRepresentation: representation, mapping: mapping)
        }

        beginTransaction(for: mapping, representation: [representation])

        let root = DataStoreRepresentationUtility.rootForKeyPath(representation, mapping.rootPath)

        if let root = root as? [AnyHashable: Any] {
            applyAttributes(toObject: object, representation: root, mapping: mapping, allocated: false)
            applyRelationships(toObject: object, representation: root, mapping: mapping)
        } else {
            logger.warning("Cannot found data representation for \(representation) and mapping.rootPath \(mapping.rootPath)")
        }

        commitTransaction()

        if delegateFlags.didMapObject {
            delegate?.deserializer?(self, didMapObject: object, fromRepresentation: representation, mapping: mapping)
        }

        return object
    }

    public func collection(fromRepresentation representation: [Any], mapping: DataStoreMapping) -> [DataStoreObject] {
        beginTransaction(for: mapping, representation: representation)

        let root = DataStoreRepresentationUtility.rootForKeyPath(representation, mapping.rootPath)
        var objects: [DataStoreObject]?
        if let root = root as? [DataStoreRepresentation] {
            objects = _collection(fromRepresentation: root, mapping: mapping, allocateIfNeeded: true)
        }

        commitTransaction()

        return objects ?? []
    }

    func applyAttributes(toObject object: DataStoreObject, representation: [AnyHashable: Any], mapping: DataStoreMapping, allocated: Bool) {
        for attribute in mapping.attributes ?? [] {
            let newValue = DataStoreRepresentationUtility.valueForAttribute(representation, attribute)
            if newValue == nil || newValue is NSNull {
                if !DataStoreRepresentationUtility.isScalar(object, attribute.property) {
                    object.setNilValueForKey(attribute.property)
                }
            } else {
                object.setValue(newValue, forKey: attribute.property)
            }
            // OPTI: use allocated=false to check or not if old value is the same (maybe there is no diff)
        }
    }

    func applyRelationships(toObject object: DataStoreObject, representation: [AnyHashable: Any], mapping: DataStoreMapping) {

        for relationship in mapping.relationships ?? [] {

            guard let relationshipRepresentation = DataStoreRepresentationUtility.rootForKeyPath(representation, relationship.keyPath) else {
                //logger.warning("Cannot found data representation for \(representation) and mapping.rootPath \(mapping.rootPath)")
                continue
            }

            var targetValue: Any?
            if relationship.isToMany {
                if let relationshipRepresentation = relationshipRepresentation as? [DataStoreRepresentation], let relationshipMapping = relationship.mapping {
                    targetValue = _collection(
                        fromRepresentation: relationshipRepresentation,
                        mapping: relationshipMapping,
                        allocateIfNeeded: !relationship.weak)
                }

                // OPTI? get info from mapping relationship ? (if core data we already kwnow type if ordered or not)
                let property = class_getProperty(type(of: object), relationship.property)
                if let property = property {
                    targetValue = (targetValue as? [DataStoreObject])?.fromPropertyRepresentation(property)
                }
            } else {
                if let relationshipRepresentation = relationshipRepresentation as? DataStoreRepresentation, let relationshipMapping = relationship.mapping {
                    targetValue = _object(
                        fromRepresentation: relationshipRepresentation,
                        mapping: relationshipMapping,
                        allocateIfNeeded: !relationship.weak)
                }
            }

            if relationship.assignmentPolicy != DataStoreAssignmentPolicy.assign {
                let context = transaction.newAssignmentContext()
                context.destinationObject = object
                context.relationship = relationship
                context.sourceRelationshipValue = object.value(forKey: relationship.property) as AnyObject
                context.targetRelationshipValue = targetValue as AnyObject

                let assignmentValue = relationship.assignmentPolicyClosure(context)
                //logger.debug("Setting \(assignmentValue) to \(object) for relation \(relationship.property)")

                if let assignmentValue = assignmentValue, !(assignmentValue is NSNull) {
                    object.setValue(assignmentValue, forKey: relationship.property)
                } else {
                    object.setNilValueForKey(relationship.property)
                }
            } else if let targetValue = targetValue, !(targetValue is NSNull) {
                object.setValue(targetValue, forKeyPath: relationship.property)
            } else {
                object.setNilValueForKey(relationship.property)
            }
        }
    }

    func _object(fromRepresentation representation: [AnyHashable: Any], mapping: DataStoreMapping, allocateIfNeeded: Bool) -> DataStoreObject? {
        var object: DataStoreObject?
        var primaryKey: DataStoreObjectPrimaryKey?

        let primaryKeyAttribute = mapping.primaryKeyAttribute
        if primaryKeyAttribute != nil {
            if let primaryKeyAttribute = primaryKeyAttribute {
                primaryKey = DataStoreRepresentationUtility.valueForAttribute(representation, primaryKeyAttribute) as? DataStoreObjectPrimaryKey
            }
            if let primaryKey = primaryKey {
                object = transaction.object(forPrimaryKey: primaryKey, mapping: mapping)
            }
        }

        var allocated = false
        if object == nil && allocateIfNeeded {
            object = transaction.newObject(for: mapping)
            allocated = true
        }

         guard let theObject = object else {
            return nil
        }

        if delegateFlags.willMapObject {
            delegate?.deserializer?(self, willMapObjectFromRepresentation: representation, mapping: mapping)
        }

        applyAttributes(toObject: theObject, representation: representation, mapping: mapping, allocated: allocated)

        if allocated, let primaryKey = primaryKey {
            transaction.addObject(theObject, forPrimaryKey: primaryKey, mapping: mapping)
        }

        applyRelationships(toObject: theObject, representation: representation, mapping: mapping)

        if delegateFlags.didMapObject {
            delegate?.deserializer?(self, didMapObject: theObject, fromRepresentation: representation, mapping: mapping)
        }

        return object
    }

    func _collection(fromRepresentation representation: [DataStoreRepresentation], mapping: DataStoreMapping, allocateIfNeeded: Bool) -> [DataStoreObject] {
        if delegateFlags.willMapCollection {
            delegate?.deserializer?(self, willMapCollectionFromRepresentation: representation, mapping: mapping)
        }

        var output = [DataStoreObject]()
        for objectRepresentation in representation {
            autoreleasepool {
                if let object = _object(fromRepresentation: objectRepresentation, mapping: mapping, allocateIfNeeded: allocateIfNeeded) {
                    output.append(object)
                }
            }
        }

        if delegateFlags.didMapCollection {
            delegate?.deserializer?(self, didMapCollection: output, fromRepresentation: representation, mapping: mapping)
        }

        return output
    }

    // MARK: - Transaction
    public func beginTransaction(for mapping: DataStoreMapping, representation: Any) {
        let requiresPrefetch = type(of: self.transaction).requiresPrefetch()

        var presentedPrimaryKeys: [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>]?
        if requiresPrefetch {
            presentedPrimaryKeys = DataStoreRepresentationUtility.collectPresentedPrimaryKeys(representation, mapping)
        }
        transaction.begin(presentedPrimaryKeys)
    }

    public func commitTransaction() {
        do {
            try transaction.commit()
        } catch {
            print("Failed to commit transaction: \(error)")
        }
    }
}

extension DataStoreDeserializer {

    public class func object(fromRepresentation representation: [AnyHashable: Any], mapping: DataStoreMapping, context: NSManagedObjectContext) -> DataStoreObject? {
        let transaction = DataStoreManagedObjectTransaction(context: context)
        let deserializer = DataStoreDeserializer(transaction: transaction)
        return deserializer.object(fromRepresentation: representation, mapping: mapping)
    }

    public class func object(fromRepresentation representation: [AnyHashable: Any], mapping: DataStoreMapping) -> DataStoreObject? {
        let transaction = DataStoreObjectTransaction()
        let deserializer = DataStoreDeserializer(transaction: transaction)
        return deserializer.object(fromRepresentation: representation, mapping: mapping)
    }

    public class func fillObject(_ object: DataStoreObject, fromRepresentation representation: [AnyHashable: Any], mapping: DataStoreMapping) -> Any? {
        var transaction: DataStoreObjectTransaction
        if object is NSManagedObject {
            if let managed = (object as? NSManagedObject)?.managedObjectContext {
                transaction = DataStoreManagedObjectTransaction(context: managed)
            } else {
                return nil
            }
        } else {
            transaction = DataStoreObjectTransaction()
        }
        let deserializer = DataStoreDeserializer(transaction: transaction)
        return deserializer.fillObject(object, fromRepresentation: representation, mapping: mapping)
    }

    public class func collection(fromRepresentation representation: [NSObject], mapping: DataStoreMapping, context: NSManagedObjectContext) -> [AnyHashable] {
        let transaction = DataStoreManagedObjectTransaction(context: context)
        let deserializer = DataStoreDeserializer(transaction: transaction)
        return deserializer.collection(fromRepresentation: representation, mapping: mapping)
    }

    public class func collection(fromRepresentation representation: [NSObject], mapping: DataStoreMapping) -> [AnyHashable] {
        let transaction = DataStoreObjectTransaction()
        let deserializer = DataStoreDeserializer(transaction: transaction)
        return deserializer.collection(fromRepresentation: representation, mapping: mapping)
    }
}
