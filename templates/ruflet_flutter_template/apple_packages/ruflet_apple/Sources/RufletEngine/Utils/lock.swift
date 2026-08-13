/// A FIFO asynchronous mutex matching the acquire/release contract used by Flet.
public actor Lock {
  private var locked = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init() {}

  public var isLocked: Bool { locked }

  public func acquire() async {
    if !locked {
      locked = true
      return
    }
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  public func release() {
    guard locked else { return }
    if waiters.isEmpty {
      locked = false
    } else {
      let next = waiters.removeFirst()
      next.resume()
    }
  }
}
