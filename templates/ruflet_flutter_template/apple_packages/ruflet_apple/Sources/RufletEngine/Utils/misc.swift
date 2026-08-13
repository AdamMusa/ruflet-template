import Foundation

func rufletDictionary(_ value: Any?) -> [String: Any]? {
    if let value = value as? [String: Any] {
        return value
    }
    if let value = value as? [AnyHashable: Any] {
        return Dictionary(uniqueKeysWithValues: value.map { (String(describing: $0.key), $0.value) })
    }
    return nil
}

func rufletArray(_ value: Any?) -> [Any]? {
    value as? [Any]
}
