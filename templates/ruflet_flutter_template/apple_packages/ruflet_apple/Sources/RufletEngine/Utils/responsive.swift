func parseResponsiveNumber(_ value: Any?, _ defaultValue: Double) -> [String: Double] {
    var result: [String: Double] = [:]
    if let value = rufletDictionary(value) {
        for (key, item) in value {
            result[key] = parseDouble(item, 0)!
        }
    } else if value != nil {
        result[""] = parseDouble(value, 0)!
    }
    if result[""] == nil {
        result[""] = defaultValue
    }
    return result
}

func getBreakpointNumber(
    _ value: [String: Double],
    width: Double,
    breakpoints: [String: Double]
) -> Double {
    var selectedValue = value[""]
    var highestMatchedBreakpoint = 0.0
    for (name, candidate) in value where !name.isEmpty {
        guard let breakpointWidth = breakpoints[name] else { continue }
        if width >= breakpointWidth, breakpointWidth >= highestMatchedBreakpoint {
            highestMatchedBreakpoint = breakpointWidth
            selectedValue = candidate
        }
    }
    precondition(selectedValue != nil, "Responsive number not found for width=\(width): \(value)")
    return selectedValue!
}
