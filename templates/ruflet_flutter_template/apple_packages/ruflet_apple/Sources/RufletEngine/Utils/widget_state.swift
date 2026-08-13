enum RufletWidgetState: String, CaseIterable, Hashable, Sendable {
    case disabled
    case dragged
    case error
    case focused
    case hovered
    case pressed
    case scrolledUnder
    case selected
}

struct RufletWidgetStateProperty<Value> {
    private let states: [(String, Value)]
    private let defaultValue: Value?

    init(_ value: Any?, converter: (Any?) -> Value?, defaultValue: Value? = nil) {
        self.defaultValue = defaultValue
        var dictionary: [String: Any]
        if let parsed = rufletDictionary(value) {
            dictionary = parsed
        } else if let value {
            dictionary = ["default": value]
        } else {
            dictionary = [:]
        }

        if let blank = dictionary.removeValue(forKey: "") {
            dictionary["default"] = blank
        }
        let stateNames = Set(RufletWidgetState.allCases.map(\.rawValue)).union(["default"])
        if dictionary.keys.contains(where: { !stateNames.contains($0.lowercased()) }) {
            dictionary = ["default": value as Any]
        }
        states = dictionary.compactMap { key, rawValue in
            converter(rawValue).map { (key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0) }
        }
    }

    func resolve(_ activeStates: Set<RufletWidgetState>) -> Value? {
        for (name, value) in states where name != "default" {
            if activeStates.contains(where: { $0.rawValue.lowercased() == name }) {
                return value
            }
        }
        return states.first(where: { $0.0 == "default" })?.1 ?? defaultValue
    }
}
