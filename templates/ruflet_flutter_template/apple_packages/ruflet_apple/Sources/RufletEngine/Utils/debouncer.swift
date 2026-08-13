import Foundation

/// Coalesces a burst of calls and invokes only the most recently submitted action.
///
/// This is the Apple concurrency equivalent of Flet's timer-backed `Debouncer`.
@MainActor
public final class Debouncer {
  public let milliseconds: Int
  private var pending: Task<Void, Never>?

  public init(milliseconds: Int) {
    self.milliseconds = milliseconds
  }

  public func run(_ action: @escaping @MainActor () -> Void) {
    pending?.cancel()
    let delay = UInt64(max(0, milliseconds)) * 1_000_000
    pending = Task { @MainActor in
      do {
        try await Task<Never, Never>.sleep(nanoseconds: delay)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      action()
    }
  }

  public func dispose() {
    pending?.cancel()
    pending = nil
  }

  deinit {
    pending?.cancel()
  }
}
