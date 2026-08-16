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
    #expect(navigator.contains("requestedControllers.last?.prepareForNavigation()"))
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
}
