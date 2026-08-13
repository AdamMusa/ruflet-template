func parseExpand(_ value: Any?, _ defaultValue: Int? = nil) -> Int? {
    if let value = value as? Bool {
        return value ? 1 : 0
    }
    return parseInt(value) ?? defaultValue
}
