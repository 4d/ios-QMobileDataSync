import Foundation
import CoreData

extension DataStoreObjectCache {
    convenience init(
        context: NSManagedObjectContext,
        presentedPrimaryKeys: [ObjectIdentifier: Set<DataStoreObjectPrimaryKey>]?
    ) {
        self.init(source: { mapping in
            let primaryKeys: Set<DataStoreObjectPrimaryKey>? = presentedPrimaryKeys?[mapping.uniqueIdentifier]
            if let primaryKeys = primaryKeys, !primaryKeys.isEmpty {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: mapping.entityName ?? "")
                var predicate: NSPredicate?
                predicate = NSPredicate(format: "%K IN %@", mapping.primaryKey ?? "", primaryKeys)
                fetchRequest.predicate = predicate
                fetchRequest.fetchLimit = primaryKeys.count

                var existingObjects: [DataStoreObject]?
                do {
                    existingObjects = try context.fetch(fetchRequest)
                } catch {
                    // TODO make a failed init, maybe too much object?
                    print("\(error)")
                }
                return existingObjects
            }

            return []
        })
    }
}
