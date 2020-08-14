import Foundation

public class DataStoreRelationship: NSObject, DataStoreProperty {
    public var property: String
    public var keyPath: String?
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

    public var recursive: Bool {
        return owner == mapping
    }

    // MARK: - Init
    public required init(property: String, keyPath: String = "", mapping: DataStoreMapping) {
        self.property = property
        super.init()
        self.keyPath = keyPath
        self.mapping = mapping
        self.assignmentPolicy = DataStoreAssignmentPolicy.assign
    }

    public convenience init(property: String, keyPath: String, mapping: DataStoreMapping, assignmentPolicy: DataStoreAssignmentPolicy) {
        self.init(property: property, keyPath: keyPath, mapping: mapping)
        self.assignmentPolicy = assignmentPolicy
    }

    // MARK: - mapping
    func setMapping(_ mapping: DataStoreMapping, forKeyPath keyPath: String?) {
        self.mapping = mapping
        self.keyPath = keyPath
    }

    // MARK: - description
    public override var description: String {
        if recursive {
            return "<\(NSStringFromClass(DataStoreRelationship.self)) \(self)>\n {\nproperty:\(property) keyPath:\(keyPath ?? "") toMany:\(toMany)\nrecursive}\n"
        } else {
            return "<\(NSStringFromClass(DataStoreRelationship.self)) \(self)>\n {\nproperty:\(property) keyPath:\(keyPath ?? "") toMany:\(toMany)\n}\n"
        }
    }

}
