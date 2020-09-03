import Foundation

public class DataStoreMapping: NSObject {

    public var objectClass: DataStoreObject.Type? {
        didSet {
            if objectClass != nil {
                entityName = nil
            }
        }
    }

    public var entityName: String? {
        didSet {
            if entityName != nil {
                objectClass = nil
            }
        }
    }

    public var rootPath: String?
    public var primaryKey: String?

    private var attributeMap: [String: DataStoreAttribute]?
    private var relationshipMap: [String: DataStoreRelationship]?

    private(set) var uniqueIdentifier: ObjectIdentifier

    public required init(objectClass: DataStoreObject.Type) {
        uniqueIdentifier = ObjectIdentifier(objectClass)
        super.init()
        attributeMap = [:]
        relationshipMap = [:]

        self.objectClass = objectClass
    }

    public convenience init(objectClass: DataStoreObject.Type, rootPath: String) {
        self.init(objectClass: objectClass)
        self.rootPath = rootPath
    }

    public required init(entityName: String) {
        uniqueIdentifier = ObjectIdentifier(entityName as NSString)
        super.init()
        attributeMap = [:]
        relationshipMap = [:]

        self.entityName = entityName
    }

    /// - Returns: New instance of the DataStoreMapping.
    public convenience init(entityName: String, rootPath: String) {
        self.init(entityName: entityName)
        self.rootPath = rootPath
    }

    public var primaryKeyAttribute: DataStoreAttribute? {
        guard let primaryKey = primaryKey else {
            return nil
        }
        return attributeMap?[primaryKey]
    }

    public var attributes: [DataStoreAttribute]? {
        guard let values = attributeMap?.values else {
            return []
        }
        return Array(values)
    }

    public func add(_ attribute: DataStoreAttribute) {
        addPropertyMapping(attribute, toMap: &attributeMap!)
    }

    public func attribute(forProperty property: String) -> DataStoreAttribute {
        return attributeMap![property]!
    }

    public var relationships: [DataStoreRelationship]? {
        guard let values = relationshipMap?.values else {
            return []
        }
        return Array(values)
    }

    public func add(_ relationship: DataStoreRelationship) {
        relationship.owner = self
        addPropertyMapping(relationship, toMap: &relationshipMap!)
    }

    public func relationship(forProperty property: String) -> DataStoreRelationship {
        return relationshipMap![property]!
    }

    public func flatten() -> Set<DataStoreMapping> {
        var set: Set<DataStoreMapping> = []
        flatten(inCollection: &set)
        return set
    }
    func flatten(inCollection collection: inout Set<DataStoreMapping>) {
        let (inserted, _) = collection.insert(self)

        if inserted {
            for relationship in relationships ?? [] where !relationship.isRecursive {
                relationship.mapping?.flatten(inCollection: &collection)
            }
        }
    }

    func addPropertyMapping<T: DataStoreProperty>(_ propertyMapping: T, toMap map: inout [String: T]) {
        #if DEBUG
        let existingMapping = map[propertyMapping.property] as? DataStoreAttribute
        if existingMapping != nil {
            if let existingMapping = existingMapping {
                print("\(NSStringFromClass(DataStoreMapping.self)) replacing \(existingMapping) with \(propertyMapping)")
            }
        }
        #endif
        map[propertyMapping.property] = propertyMapping
    }

    public override var description: String {
        var description = "<\(DataStoreMapping.self) >\n<\(self)> {\nrootPath:\(rootPath ?? "")\n"
        description += "attributes {\n"
        for mapping in attributes ?? [] {
            description += "\t(\(mapping.description)),\n"
        }
        description += "}\n"

        description += "relationships {\n"
        for relationshipMapping in relationships ?? [] {
            description += "\t(\(relationshipMapping.description)),"
        }
        description+="}\n"

        return description
    }

    public func addAttributes(fromDictionary attributesToKeyPath: [AnyHashable: Any]) {
        (attributesToKeyPath as NSDictionary).enumerateKeysAndObjects({ attribute, keyPath, _ in
            self.add(DataStoreAttribute.mappingOfProperty(attribute as? String ?? "", toKeyPath: keyPath as? String ?? ""))
        })
    }

    public func addAttributes(fromArray attributes: [String]) {
        for attribute in attributes {
            add(DataStoreAttribute.mappingOfProperty(attribute, toKeyPath: attribute))
        }
    }

    public func addAttribute(withProperty property: String, keyPath: String, map: DataStoreMapBlock? = nil, reverseMap: DataStoreMapBlock? = nil) {
        add(DataStoreAttribute.mappingOfProperty(property, toKeyPath: keyPath, map: map, reverseMap: reverseMap))
    }

    public func addAttribute(withProperty property: String, keyPath: String, dateFormat: String) {
        add(DataStoreAttribute.mappingOfProperty(property, toKeyPath: keyPath, dateFormat: dateFormat))
    }

    public func addRelationshipMapping(_ mapping: DataStoreMapping, forProperty property: String, keyPath: String) {
        add(DataStoreRelationship(property: property, keyPath: keyPath, mapping: mapping, toMany: false))
    }

    public func addRecursiveRelationshipMapping(forProperty property: String, keypath keyPath: String) {
        add(DataStoreRelationship(property: property, keyPath: keyPath, mapping: self, toMany: false))
    }

    public func add(toManyRelationshipMapping mapping: DataStoreMapping, forProperty property: String, keyPath: String) {
        let relationship = DataStoreRelationship(property: property, keyPath: keyPath, mapping: mapping, toMany: true)
        add(relationship)
    }

    public func addRecursiveToManyRelationship(forProperty property: String, keypath keyPath: String?) {
        let relationship = DataStoreRelationship(property: property, keyPath: keyPath ?? "", mapping: self, toMany: true)
        relationship.toMany = true
        add(relationship)
    }
}
