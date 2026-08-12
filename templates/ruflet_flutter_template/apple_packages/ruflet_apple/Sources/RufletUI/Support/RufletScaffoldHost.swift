import RufletEngine
import RufletProtocol
import SwiftUI

/// The route state Flutter's `Navigator` exposes to an AppBar.
///
/// Keeping this in the environment lets an AppBar remain a patchable control
/// while its implied leading button still belongs to the enclosing Page/View
/// navigator, just as it does in Flet's Scaffold.
struct RufletNavigationContext {
  var canPop = false
  var requestPop: () -> Void = {}
  var confirmPop: (Bool) -> Void = { _ in }
}

/// Source-derived Page/View pop protocol used by both the platform back action
/// and AppBar's implied leading action.
enum RufletPageNavigation {
  static func canImplyLeading(viewCount: Int) -> Bool { viewCount > 1 }

  static func commitPop(page: ControlNode, view: ControlNode, events: RufletEventSink) {
    let route = view.string("route") ?? String(view.id)
    // Flet intentionally sends Page.view_pop even without a Ruby subscriber.
    events.send(page.id, "view_pop", .map(["route": .string(route)]))
  }
}

/// The completer owned by Flet's `ViewControlState`, expressed as a native
/// host object so the AppBar/back action and `View.confirm_pop()` command share
/// one lifecycle. A second request aborts the first, and an unanswered request
/// is rejected after the same five-minute timeout as the Dart engine.
@MainActor
final class RufletViewPopCoordinator: ObservableObject {
  private struct Pending {
    let page: ControlNode
    let view: ControlNode
    let events: RufletEventSink
    let timeout: DispatchWorkItem
  }

  private var pending: Pending?

  func request(page: ControlNode, view: ControlNode, events: RufletEventSink) {
    pending?.timeout.cancel()
    pending = nil

    if view.bool("on_confirm_pop") == true {
      let timeout = DispatchWorkItem { [weak self] in self?.pending = nil }
      pending = Pending(page: page, view: view, events: events, timeout: timeout)
      events.fire(view, "confirm_pop")
      DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: timeout)
      return
    }

    guard view.bool("can_pop") != false else { return }
    RufletPageNavigation.commitPop(page: page, view: view, events: events)
  }

  func confirm(shouldPop: Bool) {
    guard let pending else { return }
    pending.timeout.cancel()
    self.pending = nil
    guard shouldPop else { return }
    RufletPageNavigation.commitPop(
      page: pending.page, view: pending.view, events: pending.events)
  }

  var isAwaitingConfirmation: Bool { pending != nil }
}

private struct RufletNavigationContextKey: EnvironmentKey {
  static let defaultValue = RufletNavigationContext()
}

extension EnvironmentValues {
  var rufletNavigationContext: RufletNavigationContext {
    get { self[RufletNavigationContextKey.self] }
    set { self[RufletNavigationContextKey.self] = newValue }
  }
}

/// Shared geometry and scroll state owned by one material Scaffold.
///
/// Flutter passes the FAB rectangle and the body scroll notifications through
/// `ScaffoldGeometry`. This is the Apple host equivalent: controls only report
/// their real geometry/offset; AppBar and BottomAppBar consume it without
/// knowing anything about a particular screen.
@MainActor
final class RufletScaffoldHostState: ObservableObject {
  @Published private(set) var scrolledUnder = false
  @Published private(set) var fabFrame: CGRect = .null
  @Published private(set) var bottomBarFrame: CGRect = .null

  private var scrolledSources: Set<Int> = []

  func reportScroll(sourceID: Int, offset: CGFloat) {
    if offset > 0.5 {
      scrolledSources.insert(sourceID)
    } else {
      scrolledSources.remove(sourceID)
    }
    let next = !scrolledSources.isEmpty
    if scrolledUnder != next { scrolledUnder = next }
  }

  func removeScrollSource(_ sourceID: Int) {
    scrolledSources.remove(sourceID)
    let next = !scrolledSources.isEmpty
    if scrolledUnder != next { scrolledUnder = next }
  }

  func reportFAB(frame: CGRect) {
    if fabFrame != frame { fabFrame = frame }
  }

  func reportBottomBar(frame: CGRect) {
    if bottomBarFrame != frame { bottomBarFrame = frame }
  }

  var fabFrameInBottomBar: CGRect? {
    guard !fabFrame.isNull, !bottomBarFrame.isNull else { return nil }
    return fabFrame.offsetBy(dx: -bottomBarFrame.minX, dy: -bottomBarFrame.minY)
  }
}

private struct RufletScaffoldHostStateKey: EnvironmentKey {
  static let defaultValue: RufletScaffoldHostState? = nil
}

extension EnvironmentValues {
  var rufletScaffoldHost: RufletScaffoldHostState? {
    get { self[RufletScaffoldHostStateKey.self] }
    set { self[RufletScaffoldHostStateKey.self] = newValue }
  }
}

/// Reads the offset already computed by a renderer-owned scroll surface.
/// Reporting is independent of `on_scroll`: Material's AppBar consumes scroll
/// notifications even when Ruby did not subscribe to them.
struct RufletScrollUnderReporter: ViewModifier {
  let sourceID: Int
  let offset: CGFloat
  @Environment(\.rufletScaffoldHost) private var scaffold

  func body(content: Content) -> some View {
    content
      .onChange(of: offset) { scaffold?.reportScroll(sourceID: sourceID, offset: $0) }
      .onAppear { scaffold?.reportScroll(sourceID: sourceID, offset: offset) }
      .onDisappear { scaffold?.removeScrollSource(sourceID) }
  }
}
