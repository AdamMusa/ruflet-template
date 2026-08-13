import Foundation

struct AutoCompleteSuggestion: Equatable, Hashable, Sendable, CustomStringConvertible {
    let key: String
    let value: String

    var description: String { value }
    var selectionString: String { key }
    var map: [String: String] { ["key": key, "value": value] }
}

func parseAutoCompleteSuggestions(
    _ value: Any?,
    _ defaultValue: [AutoCompleteSuggestion]? = nil
) -> [AutoCompleteSuggestion]? {
    guard let items = value as? [Any] else { return value == nil ? defaultValue : [] }
    return items.compactMap { item in
        guard let item = rufletDictionary(item) else { return nil }
        let key = autoCompleteString(item["key"])
        let value = autoCompleteString(item["value"])
        guard key?.isEmpty == false || value?.isEmpty == false else { return nil }
        return AutoCompleteSuggestion(key: key ?? value!, value: value ?? key!)
    }
}

private func autoCompleteString(_ value: Any?) -> String? {
    guard let value, !(value is NSNull) else { return nil }
    return String(describing: value)
}
