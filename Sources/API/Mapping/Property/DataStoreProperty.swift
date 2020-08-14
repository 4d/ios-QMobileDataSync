import Foundation

protocol DataStoreProperty: NSObjectProtocol {
    var property: String { get set }
    var keyPath: String? { get set }
}
