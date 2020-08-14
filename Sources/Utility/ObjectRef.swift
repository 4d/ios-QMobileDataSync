import Foundation

/// Keep a reference on an object and choose if it is a strong or weak one.
class ObjectRef<ValueType: NSObject>: NSObject {

    private var strongValue: ValueType?
    private weak var weakValue: ValueType?

    var useWeakOwnership = false {
        didSet {
            if oldValue == useWeakOwnership {
                return
            }
            if useWeakOwnership {
                weakValue = strongValue
                strongValue = nil
            } else {
                strongValue = weakValue
                weakValue = nil
            }
        }
    }

    init(value: ValueType?) {
        super.init()
        strongValue = value
    }

    /// Return the value.
    var value: ValueType? {
        return strongValue ?? weakValue
    }
}
