import Foundation
import RufletProtocol
import SwiftUI
import Testing

@testable import RufletEngine

@Suite("Pinned Flet Page/View navigation and scaffold contract")
@MainActor
struct PageViewNavigationContractTests {
  @Test("all named Flet FAB locations preserve their native axes and variants")
  func namedFloatingActionLocations() {
    let locations:
      [(
        String, RufletFloatingActionLocation.Horizontal, RufletFloatingActionLocation.Vertical, Bool
      )] = [
        ("centerDocked", .center, .docked, false),
        ("centerFloat", .center, .float, false),
        ("centerTop", .center, .top, false),
        ("endContained", .end, .contained, false),
        ("endDocked", .end, .docked, false),
        ("endFloat", .end, .float, false),
        ("endTop", .end, .top, false),
        ("miniCenterDocked", .center, .docked, true),
        ("miniCenterFloat", .center, .float, true),
        ("miniCenterTop", .center, .top, true),
        ("miniEndFloat", .end, .float, true),
        ("miniEndTop", .end, .top, true),
        ("miniStartDocked", .start, .docked, true),
        ("miniStartFloat", .start, .float, true),
        ("miniStartTop", .start, .top, true),
        ("startDocked", .start, .docked, false),
        ("startFloat", .start, .float, false),
        ("startTop", .start, .top, false),
      ]

    for (wire, horizontal, vertical, mini) in locations {
      let decoded = RufletFloatingActionLocation.parse(wire)
      #expect(decoded.horizontal == horizontal)
      #expect(decoded.vertical == vertical)
      #expect(decoded.mini == mini)
      #expect(decoded.customOffset == nil)
    }
  }

  @Test("custom FAB offsets preserve the pinned right/bottom coordinate pair")
  func customFloatingActionLocation() {
    let decoded = RufletFloatingActionLocation.parse(["dx": 12.0, "dy": 34.0])
    #expect(decoded.customOffset == CGSize(width: 12, height: 34))
  }

  @Test("Page owns overlays once above the native navigator")
  func sourceOwnsNavigationAndOverlaySemantics() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let page = try String(
      contentsOf: root.appendingPathComponent("Sources/RufletEngine/Controls/page.swift"),
      encoding: .utf8)
    let view = try String(
      contentsOf: root.appendingPathComponent("Sources/RufletEngine/Controls/view.swift"),
      encoding: .utf8)
    let navigator = try String(
      contentsOf: root.appendingPathComponent("Sources/RufletEngine/Widgets/page_navigator.swift"),
      encoding: .utf8)

    #expect(page.contains("RufletPageNavigator("))
    #expect(page.contains("private struct RufletPageTopLayers"))
    #expect(page.contains("@ObservedObject var dialogs: RufletControl"))
    #expect(page.contains("dialogs.addListener { topLayersRevision &+= 1 }"))
    #expect(page.contains(".id(ObjectIdentifier(control))"))
    #expect(page.contains("revision: topLayersRevision"))
    #expect(!page.contains(".transition(.opacity)"))
    #expect(!view.contains("RufletPageMedia(control: page)"))
    #expect(!view.contains("page.child(\"_dialogs\""))
    #expect(!view.contains(".id(slotRevision)"))
    #expect(navigator.contains("UINavigationController"))
    #expect(navigator.contains("fullscreen_dialog"))
    #expect(navigator.contains("animationControllerFor operation:"))
    #expect(navigator.contains("RufletFletPageTransitionAnimator"))
    #expect(!navigator.contains("CATransition()"))
    #expect(navigator.contains("@Environment(\\.rufletSafeAreaInsets) private var safeAreaInsets"))
    #expect(navigator.contains(".environment(\\.rufletSafeAreaInsets, safeAreaInsets)"))
    #expect(navigator.contains("safeAreaRegions = []"))
    #expect(navigator.contains("requestedControllers.last?.prepareForNavigation()"))
    #expect(navigator.contains("setInteractiveController(\n          requestedControllers.last,"))
  }

  @Test("ordinary iOS routes use the pinned flat Flet slide geometry")
  func pinnedFlatRouteTransitionGeometry() {
    let push = rufletPageTransitionOffsets(
      operation: .push,
      style: .standard,
      width: 390,
      height: 844,
      rightToLeft: false)
    #expect(push.fromStart == .zero)
    #expect(push.fromEnd == CGSize(width: -130, height: 0))
    #expect(push.toStart == CGSize(width: 390, height: 0))
    #expect(push.toEnd == .zero)

    let pop = rufletPageTransitionOffsets(
      operation: .pop,
      style: .standard,
      width: 390,
      height: 844,
      rightToLeft: false)
    #expect(pop.fromStart == .zero)
    #expect(pop.fromEnd == CGSize(width: 390, height: 0))
    #expect(pop.toStart == CGSize(width: -130, height: 0))
    #expect(pop.toEnd == .zero)
    #expect(rufletPageTransitionDuration == 0.3)
  }

  @Test("RTL and fullscreen routes preserve their pinned transition axes")
  func pinnedRouteTransitionAxes() {
    let rtlPush = rufletPageTransitionOffsets(
      operation: .push,
      style: .standard,
      width: 300,
      height: 700,
      rightToLeft: true)
    #expect(rtlPush.fromEnd == CGSize(width: 100, height: 0))
    #expect(rtlPush.toStart == CGSize(width: -300, height: 0))

    let fullscreenPush = rufletPageTransitionOffsets(
      operation: .push,
      style: .fullscreenDialog,
      width: 300,
      height: 700,
      rightToLeft: false)
    #expect(fullscreenPush.fromEnd == .zero)
    #expect(fullscreenPush.toStart == CGSize(width: 0, height: 700))

    let fullscreenPop = rufletPageTransitionOffsets(
      operation: .pop,
      style: .fullscreenDialog,
      width: 300,
      height: 700,
      rightToLeft: false)
    #expect(fullscreenPop.fromEnd == CGSize(width: 0, height: 700))
    #expect(fullscreenPop.toStart == .zero)
  }

  @Test("window gesture monitors honor covered route interaction ownership")
  func windowGestureMonitorHonorsNavigationOwnership() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let gestureDetector = try String(
      contentsOf: root.appendingPathComponent(
        "Sources/RufletEngine/Controls/gesture_detector.swift"),
      encoding: .utf8)

    #expect(
      gestureDetector.contains(
        "guard isEffectivelyInteractive(surface), belongsToTopNavigationRoute(surface) else"))
    #expect(gestureDetector.contains("current.isUserInteractionEnabled"))
    #expect(gestureDetector.contains("if current === window { return true }"))
    #expect(gestureDetector.contains("belongsToTopNavigationRoute(surface)"))
    #expect(gestureDetector.contains("navigationController.topViewController ==="))
  }

  @Test("navigation identity follows stable routes across rebuilt wire controls")
  func stableRouteNavigationIdentity() {
    let original = rufletPageNavigationIdentities([
      "/", "/studio", "/gallery/layout", "/gallery/layout/example/responsive-row",
    ])
    let rebuilt = rufletPageNavigationIdentities([
      "/", "/studio", "/gallery/layout", "/gallery/layout/example/responsive-row",
    ])
    let popped = rufletPageNavigationIdentities(["/", "/studio", "/gallery/layout"])

    #expect(rebuilt == original)
    #expect(original.starts(with: popped))
  }

  @Test("duplicate routes remain distinct navigation positions")
  func duplicateRouteNavigationIdentity() {
    let identities = rufletPageNavigationIdentities(["/", "/dialog", "/dialog"])

    #expect(identities[1].route == "/dialog")
    #expect(identities[1].occurrence == 0)
    #expect(identities[2].occurrence == 1)
    #expect(identities[1] != identities[2])
  }

  @Test("only the visible route refreshes while hidden routes stage their next tree")
  func hiddenRouteRefreshDisposition() {
    let identities = rufletPageNavigationIdentities([
      "/", "/gallery", "/gallery/components",
    ])

    #expect(
      rufletPageNavigationUpdateDisposition(
        for: identities[0], topIdentity: identities.last) == .stage)
    #expect(
      rufletPageNavigationUpdateDisposition(
        for: identities[1], topIdentity: identities.last) == .stage)
    #expect(
      rufletPageNavigationUpdateDisposition(
        for: identities[2], topIdentity: identities.last) == .activate)
  }

  @Test("only the shown native route accepts interaction")
  func nativeRouteInteractionOwnership() {
    #expect(
      rufletPageNavigationInteractionStates(count: 3, activeIndex: 2)
        == [false, false, true])
    #expect(
      rufletPageNavigationInteractionStates(count: 3, activeIndex: 0)
        == [true, false, false])
    #expect(
      rufletPageNavigationInteractionStates(count: 3, activeIndex: nil)
        == [false, false, false])
    #expect(
      rufletPageNavigationInteractionStates(count: 3, activeIndex: 3)
        == [false, false, false])
  }

  @Test("only a completed native pop gesture may report a View removal")
  func nativeViewRemovalRequiresUserGesture() {
    let expected = rufletPageNavigationIdentities(["/", "/device"])
    let actual = rufletPageNavigationIdentities(["/"])

    #expect(
      rufletShouldReportNativeViewRemoval(
        interactivePopStarted: true,
        synchronizing: false,
        expected: expected,
        actual: actual))
    #expect(
      !rufletShouldReportNativeViewRemoval(
        interactivePopStarted: false,
        synchronizing: false,
        expected: expected,
        actual: actual))
    #expect(
      !rufletShouldReportNativeViewRemoval(
        interactivePopStarted: true,
        synchronizing: true,
        expected: expected,
        actual: actual))
    #expect(
      !rufletShouldReportNativeViewRemoval(
        interactivePopStarted: true,
        synchronizing: false,
        expected: expected,
        actual: expected))
  }

  @Test("pending native pops identify one wire View occurrence, not every matching route")
  func pendingPopUsesWireControlIdentity() {
    var state = RufletPagePopState()

    let firstMark = state.mark(viewID: 22)
    let repeatedMark = state.mark(viewID: 22)
    #expect(firstMark)
    #expect(!repeatedMark)
    #expect(!state.isPending(viewID: 11))
    #expect(state.isPending(viewID: 22))
    #expect(!state.isPending(viewID: 33))

    state.reconcile(publishedViewIDs: [11, 33])
    #expect(!state.isPending(viewID: 22))
    let nextMark = state.mark(viewID: 33)
    #expect(nextMark)
  }
}
