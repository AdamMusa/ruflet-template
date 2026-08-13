#if os(iOS)
import UIKit

public final class MultiTouchGestureRecognizer: UIGestureRecognizer {
  public var onMultiTap: ((Bool) -> Void)?
  public var minimumNumberOfTouches = 0
  private var trackedTouches: Set<ObjectIdentifier> = []

  public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    trackedTouches.formUnion(touches.map(ObjectIdentifier.init))
    if trackedTouches.count == minimumNumberOfTouches {
      onMultiTap?(true)
      state = .recognized
      trackedTouches.removeAll()
    }
  }

  public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
    removeTouches(touches)
  }

  public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesCancelled(touches, with: event)
    removeTouches(touches)
  }

  private func removeTouches(_ touches: Set<UITouch>) {
    touches.forEach { trackedTouches.remove(ObjectIdentifier($0)) }
    onMultiTap?(false)
    trackedTouches.removeAll()
    state = .cancelled
  }
}
#elseif os(macOS)
import AppKit

/// AppKit equivalent used for touch-capable trackpads on macOS.
public final class MultiTouchGestureRecognizer: NSGestureRecognizer {
  public var onMultiTap: ((Bool) -> Void)?
  public var minimumNumberOfTouches = 0

  public func updateTouchCount(_ count: Int) {
    if count == minimumNumberOfTouches {
      onMultiTap?(true)
      state = .recognized
    } else if state == .began || state == .changed || state == .recognized {
      onMultiTap?(false)
      state = .cancelled
    }
  }
}
#endif
