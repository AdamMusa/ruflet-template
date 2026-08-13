enum RufletDismissDirection: String, CaseIterable, RufletStringEnum {
    case vertical
    case horizontal
    case endToStart
    case startToEnd
    case up
    case down
    case none
}

func parseDismissDirection(
    _ value: String?,
    _ defaultValue: RufletDismissDirection? = nil
) -> RufletDismissDirection? {
    parseEnum(RufletDismissDirection.self, value, defaultValue)
}

func parseDismissThresholds(
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
