import Foundation

public typealias DataStoreObjectPrimaryKey = AnyHashable
public typealias DataStoreObject = NSObject

public typealias DataStoreObjectCacheSourceSequence = [DataStoreObject] //  NSFastEnumeration
public typealias DataStoreObjectCacheSource = (DataStoreMapping) -> DataStoreObjectCacheSourceSequence?

private var DataStoreObjectCacheSourceStub: DataStoreObjectCacheSource = { mapping in
    return []
}

public class DataStoreObjectCache: NSObject {
    private var lookupObjectsMap: [ObjectIdentifier: [DataStoreObjectPrimaryKey: DataStoreObject]] = [:]
    private var source: DataStoreObjectCacheSource?

    // MARK: Init
    required init(source: DataStoreObjectCacheSource? = nil) {
        super.init()
        self.source = source ?? DataStoreObjectCacheSourceStub
    }

    // MARK: objects
    func object(forKey key: DataStoreObjectPrimaryKey, mapping: DataStoreMapping) -> DataStoreObject? {
        assert(mapping.primaryKey != nil, "Invalid parameter not satisfying: mapping.primaryKey != nil")

        return objects(for: mapping)[key]
    }

    func setObject(_ object: DataStoreObject, forKey key: DataStoreObjectPrimaryKey, mapping: DataStoreMapping) {
        assert(mapping.primaryKey != nil, "Invalid parameter not satisfying: mapping.primaryKey != nil")

        _ = objects(for: mapping) // just be sure that is created
        lookupObjectsMap[mapping.uniqueIdentifier]?[key] = object
    }

    func objects(for mapping: DataStoreMapping) -> [DataStoreObjectPrimaryKey: DataStoreObject] {
        var entityObjectsMap: [DataStoreObjectPrimaryKey: DataStoreObject]? = lookupObjectsMap[mapping.uniqueIdentifier]
        if entityObjectsMap == nil { // if not alread done, fetch
            entityObjectsMap = fetchExistingObjects(for: mapping)
            lookupObjectsMap[mapping.uniqueIdentifier] = entityObjectsMap
        }
        return entityObjectsMap ?? [:]
    }

    func fetchExistingObjects(for mapping: DataStoreMapping) -> [DataStoreObjectPrimaryKey: DataStoreObject] {
        var output: [DataStoreObjectPrimaryKey: DataStoreObject] = [:]
        if let objects = source?(mapping) {
            for object in objects {
                if let primaryKey =  mapping.primaryKey, let value = object.value(forKey: primaryKey) as? DataStoreObjectPrimaryKey {
                    output[value] = object
                }
            }
        }
        return output
    }

}
