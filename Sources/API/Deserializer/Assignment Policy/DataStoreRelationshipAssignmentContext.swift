import Foundation

public protocol DataStoreRelationshipAssignmentContextDelegate: NSObjectProtocol {
    func assignmentContext(_ context: DataStoreRelationshipAssignmentContext, deletedObject object: DataStoreObject?)
}

public class DataStoreRelationshipAssignmentContext: NSObject {
    init(transaction: DataStoreObjectTransaction) {
        super.init()
        self.transaction = transaction
        delegate = transaction
    }

    private(set) var transaction: DataStoreObjectTransaction?
    var destinationObject: DataStoreObject?
    var relationship: DataStoreRelationship?
    var sourceRelationshipValue: AnyObject?
    var targetRelationshipValue: AnyObject?

    private weak var delegate: DataStoreRelationshipAssignmentContextDelegate?

    func deleteRelationshipObject(_ object: DataStoreObject?) {
        delegate?.assignmentContext(self, deletedObject: object)
    }
}
