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

    public var isToMany = false

    weak var owner: DataStoreMapping? {
        didSet {
            mappingRef?.useWeakOwnership = mapping == owner
        }
    }
    var `weak` = false

    /*#if DEBUG
    public var assignmentPolicy: DataStoreAssignmentPolicy
    var assignmentPolicyClosure: DataStoreAssignmentPolicyClosure {
        return self.assignmentPolicy.closure
    }
    #else*/
    public var assignmentPolicy: DataStoreAssignmentPolicy {
        didSet {
            assignmentPolicyClosure = self.assignmentPolicy.closure
        }
    }
    var assignmentPolicyClosure: DataStoreAssignmentPolicyClosure = DataStoreAssignmentPolicy.assign.closure
   /* #endif*/

    public var isRecursive: Bool {
        return owner?.entityName == mapping?.entityName
    }

    // MARK: - Init
    public required init(property: String, keyPath: String, mapping: DataStoreMapping, assignmentPolicy: DataStoreAssignmentPolicy? = nil, isToMany: Bool) {
        self.property = property
        self.keyPath = keyPath
        if let assignmentPolicy = assignmentPolicy {
            self.assignmentPolicy = assignmentPolicy
        } else {
            self.assignmentPolicy = isToMany ? .collectionReplace: .objectReplace
        }
        super.init()
        self.mapping = mapping
        self.isToMany = isToMany
    }

    // MARK: - mapping
    func setMapping(_ mapping: DataStoreMapping, forKeyPath keyPath: String) {
        self.mapping = mapping
        self.keyPath = keyPath
    }

    // MARK: - description
    public override var description: String {
        if isRecursive {
            return "<\(NSStringFromClass(DataStoreRelationship.self)) \(self)>\n {\nproperty:\(property) keyPath:\(keyPath) toMany:\(isToMany)\nrecursive}\n"
        } else {
            return "<\(NSStringFromClass(DataStoreRelationship.self)) \(self)>\n {\nproperty:\(property) keyPath:\(keyPath) toMany:\(isToMany)\n}\n"
        }
    }

}
