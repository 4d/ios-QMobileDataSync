import Foundation

/// Simple class to define transtaction and object storing during the process.
public class DataStoreObjectTransaction: NSObject, DataStoreRelationshipAssignmentContextDelegate {

    func begin(_ presentedPrimaryKeys: [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>]?) {
        // must be overriden
    }

    func commit() throws {
        // must be overriden
    }

    class func requiresPrefetch() -> Bool {
        return false
    }

    func newObject(for mapping: DataStoreMapping) -> DataStoreObject? {
        guard let clazz = mapping.objectClass else {
            return nil
        }
        return clazz.init() // by default try to create from class using default init
    }

    func addObject(_ object: DataStoreObject, forPrimaryKey primaryKey: DataStoreObjectPrimaryKey, mapping: DataStoreMapping) {
        // must be overriden
    }

    func objects(for mapping: DataStoreMapping) -> [DataStoreObjectPrimaryKey: DataStoreObject] {
        return [:]
    }

    func object(forPrimaryKey primaryKey: DataStoreObjectPrimaryKey, mapping: DataStoreMapping) -> DataStoreObject? {
        return nil
    }

    // MARK: - DataStoreRelationshipAssignmentContextDelegate
    public func assignmentContext(_ context: DataStoreRelationshipAssignmentContext, deletedObject object: DataStoreObject?) {
        // must be overriden
    }

    func newAssignmentContext() -> DataStoreRelationshipAssignmentContext {
        return DataStoreRelationshipAssignmentContext(transaction: self)
    }

}
