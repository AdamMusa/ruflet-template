import RufletProtocol
import SwiftUI

enum RufletScrollMode: String, CaseIterable, RufletStringEnum {
  case none, auto, adaptive, always, hidden
}

/// Pinned Flet `scroll_to` arguments after applying the wire parsers used by
/// `ScrollableControl._invokeMethod`.
struct RufletScrollToArguments: Equatable {
  let offset: Double?
  let delta: Double?
  let scrollKey: ControlKey?
  let duration: TimeInterval
  let curve: RufletCurve

  init(_ arguments: RufletValue) throws {
    let values = arguments.map ?? [:]
    offset = parseDouble(values["offset"])
    delta = parseDouble(values["delta"])
    scrollKey = parseKey(values["scroll_key"])
    if let rawKey = values["scroll_key"], !rawKey.isNull, scrollKey == nil {
      throw RufletScrollableError.invalidScrollKey
    }
    duration = parseRufletWireDuration(values["duration"], 0) ?? 0
    curve = parseCurve(values["curve"]?.text, .ease)!
  }
}

@MainActor
protocol RufletScrollViewportDriving: AnyObject {
  func scroll(
    offset: Double?,
    delta: Double?,
    duration: TimeInterval,
    curve: RufletCurve)
  func scrollToEnd(duration: TimeInterval, curve: RufletCurve)
}

extension RufletScrollViewport: RufletScrollViewportDriving {}

/// Owns the imperative lifecycle of pinned Flet's stateful
/// `ScrollableControl`. Keeping the listener tokens outside transient View
/// state guarantees one registration per native mount and exact removal on
/// unmount.
@MainActor
final class RufletScrollableCoordinator: ObservableObject {
  private weak var control: RufletControl?
  private weak var viewport: (any RufletScrollViewportDriving)?
  private var invokeListener: UUID?
  private var updateListener: UUID?

  func mount(control: RufletControl, viewport: any RufletScrollViewportDriving) {
    if self.control !== control { unmount() }
    self.control = control
    self.viewport = viewport
    guard invokeListener == nil else { return }

    invokeListener = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      // Pinned Flet returns null for every method name and only performs work
      // for `scroll_to`.
      guard name == "scroll_to" else { return .null }
      perform(try RufletScrollToArguments(arguments))
      return .null
    }
    updateListener = control.addListener { [weak self] in
      self?.scheduleAutoScrollIfNeeded()
    }
    scheduleAutoScrollIfNeeded()
  }

  func unmount() {
    if let control, let invokeListener {
      control.removeInvokeMethodListener(invokeListener)
    }
    if let control, let updateListener {
      control.removeListener(updateListener)
    }
    invokeListener = nil
    updateListener = nil
    control = nil
    viewport = nil
  }

  private func perform(_ arguments: RufletScrollToArguments) {
    guard let viewport else { return }
    if let scrollKey = arguments.scrollKey,
      let target = control?.backend.scrollTarget(for: scrollKey.description)
    {
      target.reveal(duration: arguments.duration, curve: arguments.curve)
    } else {
      viewport.scroll(
        offset: arguments.offset,
        delta: arguments.delta,
        duration: arguments.duration,
        curve: arguments.curve)
    }
  }

  private func scheduleAutoScrollIfNeeded() {
    guard control?.boolean("auto_scroll", default: false) == true else { return }
    Task { @MainActor [weak self] in
      // Dart uses addPostFrameCallback. Yielding lets SwiftUI commit the new
      // native content metrics before resolving maxScrollExtent.
      await Task.yield()
      guard let self, self.control != nil else { return }
      viewport?.scrollToEnd(duration: 1, curve: .ease)
    }
  }
}

private enum RufletScrollableError: Error {
  case invalidScrollKey
}

/// Apple-native port of pinned Flet's shared `ScrollableControl`.
@MainActor
struct ScrollableControl<Content: View>: View {
  @ObservedObject var control: RufletControl
  @StateObject private var viewport = RufletScrollViewport()
  @StateObject private var coordinator = RufletScrollableCoordinator()

  let child: Content
  let scrollDirection: Axis.Set
  let wrapIntoScrollableView: Bool

  init(
    control: RufletControl,
    scrollDirection: Axis.Set,
    wrapIntoScrollableView: Bool = false,
    @ViewBuilder child: () -> Content
  ) {
    self.control = control
    self.scrollDirection = scrollDirection
    self.wrapIntoScrollableView = wrapIntoScrollableView
    self.child = child()
  }

  var body: some View {
    rendered
      .environment(\.rufletScrollViewport, viewport)
      .onAppear {
        viewport.configure(horizontal: scrollDirection == .horizontal)
        coordinator.mount(control: control, viewport: viewport)
      }
      .onDisappear { coordinator.unmount() }
  }

  @ViewBuilder
  private var rendered: some View {
    if wrapIntoScrollableView, mode != .none {
      ScrollView(scrollDirection, showsIndicators: mode != .hidden) {
        child.background(RufletScrollViewportAttachment())
      }
    } else {
      child
    }
  }

  private var mode: RufletScrollMode {
    parseEnum(RufletScrollMode.self, control.string("scroll"), RufletScrollMode.none)!
  }
}
