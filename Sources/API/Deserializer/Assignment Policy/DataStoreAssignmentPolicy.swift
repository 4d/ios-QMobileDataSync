import Foundation

public enum DataStoreAssignmentPolicy {
    case assign
    case objectMerge
    case collectionMerge
    case objectReplace
    case collectionReplace
    //case custom(DataStoreAssignmentPolicyClosure) // need to implement Equatable if uncommented

    var closure: DataStoreAssignmentPolicyClosure {
        switch self {
        case .assign:
            return DataStoreAssignmentPolicyAssign
        case .objectMerge:
            return DataStoreAssignmentPolicyObjectMerge
        case .collectionMerge:
            return DataStoreAssignmentPolicyCollectionMerge
        case .objectReplace:
            return DataStoreAssignmentPolicyObjectReplace
        case .collectionReplace:
            return DataStoreAssignmentPolicyCollectionReplace
        }
    }
}

public typealias DataStoreAssignmentPolicyClosure = (DataStoreRelationshipAssignmentContext) -> Any?

public var DataStoreAssignmentPolicyAssign: DataStoreAssignmentPolicyClosure = { context in
    return context.targetRelationshipValue
}
public var DataStoreAssignmentPolicyObjectMerge: DataStoreAssignmentPolicyClosure = { context in
    return context.targetRelationshipValue ?? context.sourceRelationshipValue
}
public var DataStoreAssignmentPolicyCollectionMerge: DataStoreAssignmentPolicyClosure = { context in
    if context.targetRelationshipValue == nil {
        return context.sourceRelationshipValue
    }
    assert(context.targetRelationshipValue is DataStoreMergeableCollection, "Collection \(type(of: context.targetRelationshipValue))) should support protocol DataStoreMergeableCollection")
    // var col = (context.targetRelationshipValue as? DataStoreMergeableCollection) // code to use if collection(byMergingObjects is mutating
    return (context.targetRelationshipValue as? DataStoreMergeableCollection)?.collection(byMergingObjects: context.sourceRelationshipValue)
}
public var DataStoreAssignmentPolicyObjectReplace: DataStoreAssignmentPolicyClosure = { context in
    if let sourceRelationshipValue = context.sourceRelationshipValue as? DataStoreObject, !(context.sourceRelationshipValue === context.targetRelationshipValue) {
        context.deleteRelationshipObject(sourceRelationshipValue)
    }

    return context.targetRelationshipValue
}
public var DataStoreAssignmentPolicyCollectionReplace: DataStoreAssignmentPolicyClosure = { context in
    if context.sourceRelationshipValue == nil {
        return context.targetRelationshipValue
    }

    if context.targetRelationshipValue != nil {
        assert(context.sourceRelationshipValue is DataStoreExcludableCollection, "Collection \(type(of: context.targetRelationshipValue)) should support protocol DataStoreExcludableCollection")
        var objectsToDelete = (context.sourceRelationshipValue as? DataStoreExcludableCollection)?.collection(byExcludingObjects: context.targetRelationshipValue)
        if let objectsToDelete = objectsToDelete as? [DataStoreObject] {
            for object in objectsToDelete {
                context.deleteRelationshipObject(object)
            }
        }
    } else {
        if let sourceRelationshipValue = context.sourceRelationshipValue as? [DataStoreObject] {
            for object in sourceRelationshipValue {
                context.deleteRelationshipObject(object)
            }
        }
    }
    return context.targetRelationshipValue
}
