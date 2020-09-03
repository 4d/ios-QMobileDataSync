import Foundation

public class DataStoreRelationship: NSObject, DataStoreProperty {
    public var property: String
    public var keyPath: String
    private var mappingRef: ObjectRef<DataStoreMapping>?

    public var mapping: DataStoreMapping? {
        get {
            return mappingRef?.value
        }
        set(mapping) {
            if mapping != nil {
                mappingRef = ObjectRef(value: mapping)
                mappingRef?.useWeakOwnership = mapping == owner
            } else {
                mappingRef = nil
            }
        }
    }

    public var toMany = false

    weak var owner: DataStoreMapping? {
        didSet {
            mappingRef?.useWeakOwnership = mapping == owner
        }
    }
    var `weak` = false
    public var assignmentPolicy: DataStoreAssignmentPolicy? {
        didSet {
            assignmentPolicyClosure = self.assignmentPolicy?.closure
        }
    }
    var assignmentPolicyClosure: DataStoreAssignmentPolicyClosure?

    public var isRecursive: Bool {
        return owner?.entityName == mapping?.entityName
    }

    // MARK: - Init
    public required init(property: String, keyPath: String, mapping: DataStoreMapping, assignmentPolicy: DataStoreAssignmentPolicy? = nil, toMany: Bool) {
        self.property = property
        self.keyPath = keyPath
        super.init()
        self.mapping = mapping
        self.toMany = toMany
        if let assignmentPolicy = assignmentPolicy {
            self.assignmentPolicy = assignmentPolicy
        } else {
            self.assignmentPolicy = .assign //  self.toMany ? .collectionReplace: .objectReplace
        }
    }

    // MARK: - mapping
    func setMapping(_ mapping: DataStoreMapping, forKeyPath keyPath: String) {
        self.mapping = mapping
        self.keyPath = keyPath
    }

    // MARK: - description
    public override var description: String {
        if isRecursive {
            return "<\(NSStringFromClass(DataStoreRelationship.self)) \(self)>\n {\nproperty:\(property) keyPath:\(keyPath) toMany:\(toMany)\nrecursive}\n"
        } else {
            return "<\(NSStringFromClass(DataStoreRelationship.self)) \(self)>\n {\nproperty:\(property) keyPath:\(keyPath) toMany:\(toMany)\n}\n"
        }
    }

}
