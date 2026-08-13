import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// A mounted Flet `ControlScrollKey` destination.
///
/// The backend retains the target only while its native marker is mounted.
/// Keeping the target native lets `Scrollable.ensureVisible()` map to the
/// platform scroll view without manufacturing screen-specific SwiftUI IDs.
@MainActor
public final class RufletScrollTarget {
  fileprivate weak var viewport: RufletScrollViewport?
  fileprivate let value: ControlKeyValue

  #if os(iOS)
    fileprivate weak var nativeView: UIView?
  #elseif os(macOS)
    fileprivate weak var nativeView: NSView?
  #endif

  fileprivate init(viewport: RufletScrollViewport, value: ControlKeyValue) {
    self.viewport = viewport
    self.value = value
  }

  func reveal(duration: TimeInterval, curve: RufletCurve) {
    guard let nativeView else { return }
    viewport?.reveal(nativeView, duration: duration, curve: curve)
  }
}

/// Imperative controller shared by every Apple scrollable control family.
@MainActor
final class RufletScrollViewport: ObservableObject {
  private(set) var horizontal = false

  #if os(iOS)
    private weak var scrollView: UIScrollView?
  #elseif os(macOS)
    private weak var scrollView: NSScrollView?
  #endif

  func configure(horizontal: Bool) {
    self.horizontal = horizontal
  }

  #if os(iOS)
    fileprivate func attach(_ scrollView: UIScrollView?) {
      guard let scrollView else { return }
      self.scrollView = scrollView
    }
  #elseif os(macOS)
    fileprivate func attach(_ scrollView: NSScrollView?) {
      guard let scrollView else { return }
      self.scrollView = scrollView
    }
  #endif

  func scroll(
    offset: Double?,
    delta: Double?,
    duration: TimeInterval,
    curve: RufletCurve
  ) {
    let metrics = nativeMetrics
    guard
      let target = Self.resolveOffset(
        offset: offset,
        delta: delta,
        current: metrics.current,
        maximum: metrics.maximum)
    else { return }
    setNativeOffset(target, duration: duration, curve: curve)
  }

  func scrollToEnd(duration: TimeInterval, curve: RufletCurve) {
    setNativeOffset(nativeMetrics.maximum, duration: duration, curve: curve)
  }

  static func resolveOffset(
    offset: Double?,
    delta: Double?,
    current: CGFloat,
    maximum: CGFloat
  ) -> CGFloat? {
    if let offset {
      let resolved = offset < 0 ? maximum + CGFloat(offset) + 1 : CGFloat(offset)
      return min(max(resolved, 0), maximum)
    }
    if let delta {
      return min(max(current + CGFloat(delta), 0), maximum)
    }
    return nil
  }

  #if os(iOS)
    fileprivate func reveal(_ view: UIView, duration: TimeInterval, curve: RufletCurve) {
      guard let scrollView else { return }
      let rect = view.convert(view.bounds, to: scrollView)
      let current = nativeMetrics.current
      let viewportExtent = horizontal ? scrollView.bounds.width : scrollView.bounds.height
      let leading = horizontal ? rect.minX : rect.minY
      let trailing = horizontal ? rect.maxX : rect.maxY
      let target: CGFloat
      if leading < current {
        target = leading
      } else if trailing > current + viewportExtent {
        target = trailing - viewportExtent
      } else {
        return
      }
      setNativeOffset(target, duration: duration, curve: curve)
    }

    private var nativeMetrics: (current: CGFloat, maximum: CGFloat) {
      guard let scrollView else { return (0, 0) }
      if horizontal {
        return (
          scrollView.contentOffset.x,
          max(scrollView.contentSize.width - scrollView.bounds.width, 0)
        )
      }
      return (
        scrollView.contentOffset.y,
        max(scrollView.contentSize.height - scrollView.bounds.height, 0)
      )
    }

    private func setNativeOffset(
      _ offset: CGFloat,
      duration: TimeInterval,
      curve: RufletCurve
    ) {
      guard let scrollView else { return }
      let metrics = nativeMetrics
      let value = min(max(offset, 0), metrics.maximum)
      var point = scrollView.contentOffset
      if horizontal { point.x = value } else { point.y = value }
      if duration < 0.001 {
        scrollView.setContentOffset(point, animated: false)
      } else {
        UIView.animate(
          withDuration: duration,
          delay: 0,
          options: curve.uiViewAnimationOptions,
          animations: { scrollView.setContentOffset(point, animated: false) })
      }
    }
  #elseif os(macOS)
    fileprivate func reveal(_ view: NSView, duration: TimeInterval, curve: RufletCurve) {
      guard let scrollView, let documentView = scrollView.documentView else { return }
      let rect = view.convert(view.bounds, to: documentView)
      let visible = scrollView.contentView.bounds
      let current = nativeMetrics.current
      let viewportExtent = horizontal ? visible.width : visible.height
      let leading = horizontal ? rect.minX : rect.minY
      let trailing = horizontal ? rect.maxX : rect.maxY
      let target: CGFloat
      if leading < current {
        target = leading
      } else if trailing > current + viewportExtent {
        target = trailing - viewportExtent
      } else {
        return
      }
      setNativeOffset(target, duration: duration, curve: curve)
    }

    private var nativeMetrics: (current: CGFloat, maximum: CGFloat) {
      guard let scrollView, let documentView = scrollView.documentView else { return (0, 0) }
      let visible = scrollView.contentView.bounds
      if horizontal {
        return (visible.origin.x, max(documentView.bounds.width - visible.width, 0))
      }
      return (visible.origin.y, max(documentView.bounds.height - visible.height, 0))
    }

    private func setNativeOffset(
      _ offset: CGFloat,
      duration: TimeInterval,
      curve _: RufletCurve
    ) {
      guard let scrollView else { return }
      let metrics = nativeMetrics
      let value = min(max(offset, 0), metrics.maximum)
      var point = scrollView.contentView.bounds.origin
      if horizontal { point.x = value } else { point.y = value }
      if duration < 0.001 {
        scrollView.contentView.scroll(to: point)
        scrollView.reflectScrolledClipView(scrollView.contentView)
      } else {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = duration
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          scrollView.contentView.animator().setBoundsOrigin(point)
        }
      }
    }
  #endif
}

private struct RufletScrollViewportEnvironmentKey: EnvironmentKey {
  static let defaultValue: RufletScrollViewport? = nil
}

extension EnvironmentValues {
  var rufletScrollViewport: RufletScrollViewport? {
    get { self[RufletScrollViewportEnvironmentKey.self] }
    set { self[RufletScrollViewportEnvironmentKey.self] = newValue }
  }
}

/// Place inside the content of a native SwiftUI `ScrollView` so its enclosing
/// UIKit/AppKit scroll view can be controlled by Flet method calls.
@MainActor
struct RufletScrollViewportAttachment: View {
  @Environment(\.rufletScrollViewport) private var viewport

  var body: some View {
    Group {
      if let viewport {
        RufletNativeScrollViewportAttachment(viewport: viewport)
      }
    }
    .frame(width: 0, height: 0)
  }
}

@MainActor
struct RufletScrollTargetMarker: View {
  let key: ControlKeyValue
  let backend: RufletBackendProtocol
  @Environment(\.rufletScrollViewport) private var viewport

  var body: some View {
    Group {
      if let viewport {
        RufletNativeScrollTargetMarker(key: key, backend: backend, viewport: viewport)
      }
    }
    .frame(width: 0, height: 0)
  }
}

#if os(iOS)
  @MainActor
  private struct RufletNativeScrollViewportAttachment: UIViewRepresentable {
    let viewport: RufletScrollViewport

    func makeUIView(context: Context) -> RufletScrollAttachmentUIView {
      RufletScrollAttachmentUIView(viewport: viewport)
    }

    func updateUIView(_ view: RufletScrollAttachmentUIView, context: Context) {
      view.viewport = viewport
      view.attach()
    }
  }

  @MainActor
  private final class RufletScrollAttachmentUIView: UIView {
    weak var viewport: RufletScrollViewport?

    init(viewport: RufletScrollViewport) {
      self.viewport = viewport
      super.init(frame: .zero)
      isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      attach()
    }

    fileprivate func attach() {
      var ancestor = superview
      while let view = ancestor {
        if let scrollView = view as? UIScrollView {
          viewport?.attach(scrollView)
          return
        }
        ancestor = view.superview
      }
    }
  }

  @MainActor
  private struct RufletNativeScrollTargetMarker: UIViewRepresentable {
    let key: ControlKeyValue
    let backend: RufletBackendProtocol
    let viewport: RufletScrollViewport

    final class Coordinator {
      let backend: RufletBackendProtocol
      let key: ControlKeyValue
      let target: RufletScrollTarget

      @MainActor
      init(key: ControlKeyValue, backend: RufletBackendProtocol, viewport: RufletScrollViewport) {
        self.backend = backend
        self.key = key
        target = RufletScrollTarget(viewport: viewport, value: key)
        backend.registerScrollTarget(target, for: key.description)
      }

      @MainActor
      func dispose() {
        backend.unregisterScrollTarget(target, for: key.description)
      }
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(key: key, backend: backend, viewport: viewport)
    }

    func makeUIView(context: Context) -> UIView {
      let view = UIView(frame: .zero)
      view.isUserInteractionEnabled = false
      context.coordinator.target.nativeView = view
      return view
    }

    func updateUIView(_ view: UIView, context: Context) {
      context.coordinator.target.viewport = viewport
      context.coordinator.target.nativeView = view
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
      coordinator.dispose()
    }
  }
#elseif os(macOS)
  @MainActor
  private struct RufletNativeScrollViewportAttachment: NSViewRepresentable {
    let viewport: RufletScrollViewport

    func makeNSView(context: Context) -> RufletScrollAttachmentNSView {
      RufletScrollAttachmentNSView(viewport: viewport)
    }

    func updateNSView(_ view: RufletScrollAttachmentNSView, context: Context) {
      view.viewport = viewport
      view.attach()
    }
  }

  @MainActor
  private final class RufletScrollAttachmentNSView: NSView {
    weak var viewport: RufletScrollViewport?

    init(viewport: RufletScrollViewport) {
      self.viewport = viewport
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      attach()
    }

    fileprivate func attach() {
      var ancestor = superview
      while let view = ancestor {
        if let scrollView = view as? NSScrollView {
          viewport?.attach(scrollView)
          return
        }
        ancestor = view.superview
      }
    }
  }

  @MainActor
  private struct RufletNativeScrollTargetMarker: NSViewRepresentable {
    let key: ControlKeyValue
    let backend: RufletBackendProtocol
    let viewport: RufletScrollViewport

    final class Coordinator {
      let backend: RufletBackendProtocol
      let key: ControlKeyValue
      let target: RufletScrollTarget

      @MainActor
      init(key: ControlKeyValue, backend: RufletBackendProtocol, viewport: RufletScrollViewport) {
        self.backend = backend
        self.key = key
        target = RufletScrollTarget(viewport: viewport, value: key)
        backend.registerScrollTarget(target, for: key.description)
      }

      @MainActor
      func dispose() {
        backend.unregisterScrollTarget(target, for: key.description)
      }
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(key: key, backend: backend, viewport: viewport)
    }

    func makeNSView(context: Context) -> NSView {
      let view = NSView(frame: .zero)
      context.coordinator.target.nativeView = view
      return view
    }

    func updateNSView(_ view: NSView, context: Context) {
      context.coordinator.target.viewport = viewport
      context.coordinator.target.nativeView = view
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
      coordinator.dispose()
    }
  }
#endif

#if os(iOS)
  extension RufletCurve {
    fileprivate var uiViewAnimationOptions: UIView.AnimationOptions {
      switch self {
      case .linear: .curveLinear
      case .easein, .easeinback, .easeincirc, .easeincubic, .easeinexpo, .easeinquad,
        .easeinquart, .easeinquint, .easeinsine, .easeintolinear, .decelerate:
        .curveEaseIn
      case .easeout, .easeoutback, .easeoutcirc, .easeoutcubic, .easeoutexpo, .easeoutquad,
        .easeoutquart, .easeoutquint, .easeoutsine, .fastlineartosloweasein, .lineartoeaseout:
        .curveEaseOut
      default: .curveEaseInOut
      }
    }
  }
#endif
