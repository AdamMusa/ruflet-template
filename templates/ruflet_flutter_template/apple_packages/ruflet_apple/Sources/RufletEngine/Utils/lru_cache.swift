/// A bounded least-recently-used cache.
public struct LruCache<Key: Hashable, Value> {
  public let capacity: Int
  private var values: [Key: Value] = [:]
  private var recency: [Key] = []

  public init(_ capacity: Int) {
    precondition(capacity > 0, "LruCache capacity must be positive")
    self.capacity = capacity
  }

  public var count: Int { values.count }

  public mutating func get(_ key: Key) -> Value? {
    guard let value = values[key] else { return nil }
    markMostRecentlyUsed(key)
    return value
  }

  public mutating func set(_ key: Key, _ value: Value) {
    if values[key] == nil, values.count >= capacity, let leastRecent = recency.first {
      values.removeValue(forKey: leastRecent)
      recency.removeFirst()
    }
    values[key] = value
    markMostRecentlyUsed(key)
  }

  private mutating func markMostRecentlyUsed(_ key: Key) {
    if let index = recency.firstIndex(of: key) {
      recency.remove(at: index)
    }
    recency.append(key)
  }
}
