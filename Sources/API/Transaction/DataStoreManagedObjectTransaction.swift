import Foundation
import CoreData

// Core data transaction
public class DataStoreManagedObjectTransaction: DataStoreObjectTransaction {
    private var cache: DataStoreObjectCache?

    public required init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
    }

    private(set) var context: NSManagedObjectContext
    var saveContextOnCommit = false

    override func begin(_ presentedPrimaryKeys: [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>]?) {
        cache = DataStoreObjectCache(context: context, presentedPrimaryKeys: presentedPrimaryKeys)
    }

    override func commit() throws {
        cache = nil
        if saveContextOnCommit {
            if context.hasChanges {
                try context.save()
            }
        }
    }

    override class func requiresPrefetch() -> Bool {
        return true
    }

    override func newObject(for mapping: DataStoreMapping) -> DataStoreObject? {
        assert(mapping.entityName != nil, "Entity name can't be nil") // wrong type of mapping for core data
        guard let entityName = mapping.entityName else { return nil }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }

    override func object(forPrimaryKey primaryKey: DataStoreObjectPrimaryKey, mapping: DataStoreMapping) -> DataStoreObject? {
        assert(mapping.entityName != nil, "Entity name can't be nil")
        return cache?.object(forKey: primaryKey, mapping: mapping)
    }

    override func addObject(_ object: DataStoreObject, forPrimaryKey primaryKey: DataStoreObjectPrimaryKey, mapping: DataStoreMapping) {
        assert(mapping.entityName != nil, "Entity name can't be nil")
        guard let manageObject = object as? NSManagedObject else { return }
        if manageObject.isInserted {
            cache?.setObject(object, forKey: primaryKey, mapping: mapping)
        }
    }

    override func objects(for mapping: DataStoreMapping) -> [DataStoreObjectPrimaryKey: DataStoreObject] {
        assert(mapping.entityName != nil, "Entity name can't be nil")
        return cache?.objects(for: mapping) ?? [:]
    }

    override public func assignmentContext(_ context: DataStoreRelationshipAssignmentContext, deletedObject object: DataStoreObject?) {
        if let object = object {
            if let object = object as? NSManagedObject {
                //self.context.delete(object)
            } else if !(object is NSNull) {
                assert((object is NSManagedObject), "Wrong class")
            }
        }
    }
}
