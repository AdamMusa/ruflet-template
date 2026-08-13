func arrayIndexOf(_ haystack: [UInt8], _ needle: [UInt8]) -> Int {
    guard !needle.isEmpty else { return 0 }
    guard needle.count <= haystack.count else { return -1 }
    for index in 0...(haystack.count - needle.count) {
        if haystack[index..<(index + needle.count)].elementsEqual(needle) {
            return index
        }
    }
    return -1
}
