/// A dictionary whose values do not participate in object ownership.
public final class WeakValueMap<Key: Hashable, Value: AnyObject> {
  private final class WeakBox {
    weak var value: Value?
    init(_ value: Value) { self.value = value }
  }

  private var values: [Key: WeakBox] = [:]

  public init() {}

  public func set(_ key: Key, _ value: Value) {
    compact()
    values[key] = WeakBox(value)
  }

  public func get(_ key: Key) -> Value? {
    guard let box = values[key] else { return nil }
    guard let value = box.value else {
      values.removeValue(forKey: key)
      return nil
    }
    return value
  }

  public func remove(_ key: Key) {
    values.removeValue(forKey: key)
  }

  public var length: Int {
    compact()
    return values.count
  }

  private func compact() {
    values = values.filter { $0.value.value != nil }
  }
}
