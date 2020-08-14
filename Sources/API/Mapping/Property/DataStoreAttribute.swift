import Foundation

public typealias DataStoreMapBlock = (Any?) -> Any?

public class DataStoreAttribute: NSObject, DataStoreProperty {
    private var map: DataStoreMapBlock?
    private var reverseMap: DataStoreMapBlock?
    var keyPath: String?
    var property: String

    // MARK: - Init
    public required init(property: String, keyPath: String = "", map: DataStoreMapBlock? = nil, reverseMap: DataStoreMapBlock? = nil) {
        assert(!property.isEmpty, "Invalid parameter: property name is empty")

        self.property = property
        self.keyPath = keyPath

        self.map = map
        self.reverseMap = reverseMap
    }

    // MARK: - Map

    func mapValue(_ value: Any?) -> Any? {
        if map != nil {
            return map?(value)
        }
        return value
    }

    func reverseMapValue(_ value: Any?) -> Any? {
        if reverseMap != nil {
            return reverseMap?(value)
        }
        return value
    }

    // MARK: - Description
    public override var description: String {
        return "<DataStoreAttribute> property:\(property) keyPath:\(keyPath ?? "")"
    }

}

// MARK: - builder
extension DataStoreAttribute {

    class func mappingOfProperty(_ property: String, toKeyPath keyPath: String = "", map: DataStoreMapBlock? = nil, reverseMap: DataStoreMapBlock? = nil) -> Self {
        return self.init(property: property, keyPath: keyPath, map: map, reverseMap: reverseMap)
    }

    class func mappingOfProperty(_ property: String, toKeyPath keyPath: String, dateFormat: String) -> Self {
        let formatter = DateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale
        formatter.timeZone = NSTimeZone(abbreviation: "UTC") as TimeZone?
        formatter.dateFormat = dateFormat
        // TODO IMPORTANT check date format from database

        return self.mappingOfProperty(property, toKeyPath: keyPath, map: { value in
            if let string = value as? String {
                return formatter.date(from: string)
            }
            return nil
        }, reverseMap: { value in
            if let value = value as? Date {
                return formatter.string(from: value)
            }
            return nil
        })
    }

    class func mappingOfURLProperty(_ property: String, toKeyPath keyPath: String) -> Self {
        return Self.mappingOfProperty(property, toKeyPath: keyPath, map: { value in
            return (value is String) ? URL(string: value as? String ?? "") : nil
        }, reverseMap: { value in
            return (value as! URL).absoluteString // swiftlint:disable:this force_cast
        })
    }
}
