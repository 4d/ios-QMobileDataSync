import Foundation

protocol DataStoreMergeableCollection/*: NSObjectProtocol */{
    func collection(byMergingObjects object: Any?) -> Any?
}

/*

extension Array where Element == AnyHashable  {
    func collection(byMergingObjects array: [AnyHashable]) -> [AnyHashable] {
        if array.count == 0 {
            return self
        }

        var appendingObjectsSet = Set<AnyHashable>(array: array)
        appendingObjectsSet.subtract(Set<AnyHashable>(self))

        append(contentsOf: Array(appendingObjectsSet))

        return self
    }
}
}*/

extension Set: DataStoreMergeableCollection {
    func collection(byMergingObjects objects: Any?) -> Any? {
        if let set = objects as? Set<Self.Element> {
            return union(set) // alternative is mutating function and use fromUnion (test perf?)
        }
        return self
    }
}

extension NSOrderedSet: DataStoreMergeableCollection {
     @objc func collection(byMergingObjects objects: Any?) -> Any? {
        return (self.mutableCopy() as! NSMutableOrderedSet).collection(byMergingObjects: objects) // swiftlint:disable:this force_cast
    }
}

extension NSMutableOrderedSet {
    @objc override func collection(byMergingObjects objects: Any?) -> Any? {
        if let objects = objects as? NSOrderedSet {
            union(objects)
        }

        return self
    }
}

extension NSSet: DataStoreMergeableCollection {
     @objc func collection(byMergingObjects objects: Any?) -> Any? {
        return (self.mutableCopy() as! NSMutableSet).collection(byMergingObjects: objects) // swiftlint:disable:this force_cast
    }
}

extension NSMutableSet {
    @objc override func collection(byMergingObjects objects: Any?) -> Any? {
        if let objects = objects as? Set<AnyHashable> {
            self.union(objects)
        }
        return self
    }
}
