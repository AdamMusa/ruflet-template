import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class NavigationBarPropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedIndicatorAndStateOverlayContract() {
    let control = makeControl(
      properties: [
        "indicator_color": "blue",
        "indicator_shape": [
          "_type": "roundedRectangle",
          "radius": 13.0,
        ],
        "overlay_color": [
          "hovered": "green",
          "pressed": "red",
        ],
      ])
    let presentation = RufletNavigationBarPresentation(control: control)
    let hovered = presentation.states(
      selected: true,
      hovered: true,
      pressed: false,
      disabled: false)

    XCTAssertNotNil(presentation.indicatorColor)
    XCTAssertEqual(presentation.indicatorShape.kind, .roundedRectangle)
    XCTAssertEqual(presentation.indicatorShape.radius.topLeft, 13)
    XCTAssertTrue(hovered.contains(.selected))
    XCTAssertTrue(hovered.contains(.hovered))
    XCTAssertNotNil(presentation.overlay(hovered))
  }

  func testIndicatorShapeDefaultsToPinnedStadiumAndSupportsAppleNativeVariants() {
    XCTAssertEqual(
      RufletNavigationIndicatorShapeDescription(nil).kind,
      .stadium)
    XCTAssertEqual(
      RufletNavigationIndicatorShapeDescription(["_type": "circle"]).kind,
      .circle)
    XCTAssertEqual(
      RufletNavigationIndicatorShapeDescription(["_type": "beveledRectangle"]).kind,
      .beveledRectangle)
    XCTAssertEqual(
      RufletNavigationIndicatorShapeDescription(["_type": "continuousRectangle"]).kind,
      .continuousRectangle)
  }

  func testAdaptiveNavigationUsesCupertinoBranchAndDestinationPropertyIsDirect() throws {
    let source = try String(contentsOf: sourceURL(), encoding: .utf8)

    XCTAssertTrue(source.contains("control.adaptive == true ? .cupertino : .navigationBar"))
    XCTAssertTrue(source.contains("rufletNavigationChildren(control, property: \"destinations\")"))
    XCTAssertTrue(source.contains("event: \"change\""))
    XCTAssertFalse(source.contains("surface_tint_color"))
  }

  private func makeControl(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "NavigationBar",
      properties: properties,
      backend: NavigationBarBackend())
  }

  private func sourceURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletEngine/Controls/navigation_bar.swift")
  }
}

@MainActor
private final class NavigationBarBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
