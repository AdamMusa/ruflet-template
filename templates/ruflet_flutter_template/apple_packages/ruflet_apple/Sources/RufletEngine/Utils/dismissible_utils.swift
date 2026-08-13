public enum RufletDismissDirection: String, CaseIterable, RufletStringEnum {
    case vertical
    case horizontal
    case endToStart
    case startToEnd
    case up
    case down
    case none
}

public func parseDismissDirection(
    _ value: String?,
    _ defaultValue: RufletDismissDirection? = nil
) -> RufletDismissDirection? {
    parseEnum(RufletDismissDirection.self, value, defaultValue)
}

public func parseDismissThresholds(
    _ value: Any?,
    _ defaultValue: [RufletDismissDirection: Double]? = nil
) -> [RufletDismissDirection: Double]? {
    guard let dictionary = rufletDictionary(value) else { return defaultValue }
    return dictionary.reduce(into: [:]) { result, entry in
        let direction = parseDismissDirection(entry.key, RufletDismissDirection.none)!
        if direction != .none {
            result[direction] = parseDouble(entry.value, 0)!
        }
    }
}

public extension RufletControl {
    func dismissDirection(
        _ propertyName: String,
        default defaultValue: RufletDismissDirection? = nil
    ) -> RufletDismissDirection? {
        parseDismissDirection(string(propertyName), defaultValue)
    }

    func dismissThresholds(
        _ propertyName: String,
        default defaultValue: [RufletDismissDirection: Double]? = nil
    ) -> [RufletDismissDirection: Double]? {
        parseDismissThresholds(dynamicValue(propertyName), defaultValue)
    }
}
