import Foundation

protocol DataStoreExcludableCollection {
    func collection(byExcludingObjects objects: Any?) -> Any?
}
/*
extension Array: DataStoreExcludableCollection where Element is AnyHashable {
    func collection(byExcludingObjects array: [AnyHashable]) -> [AnyHashable] {
        return collection(byExcludingObjects: array)
    }
}

extension Set<AnyHashable>: DataStoreExcludableCollection where Element == AnyHashable {
    func collection(byExcludingObjects set: Any?) -> Set<AnyHashable> {
        return collection(byExcludingObjects: set)
    }
}


extension [AnyHashable] {
    override func collection(byExcludingObjects objects: [AnyHashable]) -> [AnyHashable] {
        self = self.filter({ !objects.contains($0) })

        return self as? [AnyHashable] ?? []
    }
}

*/
/*
extension Array: DataStoreExcludableCollection {
    mutating func collection(byExcludingObjects objects: Any?) -> Any? {
        if let objects = objects as? [Self.Element] {

            return self.filter({ !objects.contains($0) })
        }
        return self
    }
}*/

extension Set: DataStoreExcludableCollection {
    func collection(byExcludingObjects objects: Any?) -> Any? {
        if let set = objects as? Set<Self.Element> {
            return subtracting(set)
        }
        return self
    }
}

extension NSOrderedSet: DataStoreExcludableCollection {
     @objc func collection(byExcludingObjects objects: Any?) -> Any? {
        return (self.mutableCopy() as! NSMutableOrderedSet).collection(byExcludingObjects: objects)// swiftlint:disable:this force_cast
    }
}

extension NSMutableOrderedSet {
    @objc override func collection(byExcludingObjects objects: Any?) -> Any? {
        if let objects = objects as? NSOrderedSet {
            minus(objects)
        }

        return self
    }
}

extension NSSet: DataStoreExcludableCollection {
     @objc func collection(byExcludingObjects objects: Any?) -> Any? {
        return (self.mutableCopy() as! NSMutableSet).collection(byExcludingObjects: objects)// swiftlint:disable:this force_cast
    }
}

extension NSMutableSet {
    @objc override func collection(byExcludingObjects objects: Any?) -> Any? {
        if let objects = objects as? Set<AnyHashable> {
            self.minus(objects)
        }
        return self
    }
}
