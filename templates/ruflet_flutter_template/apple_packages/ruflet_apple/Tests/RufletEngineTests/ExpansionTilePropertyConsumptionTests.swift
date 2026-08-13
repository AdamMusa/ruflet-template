import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class ExpansionTilePropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedExpandedAndCollapsedAppearance() {
    let control = RufletControl(
      id: 1,
      type: "ExpansionTile",
      properties: [
        "bgcolor": "red",
        "icon_color": "blue",
        "text_color": "green",
        "collapsed_bgcolor": "yellow",
        "collapsed_icon_color": "purple",
        "collapsed_text_color": "orange",
        "shape": [
          "_type": "beveledrectangle",
          "radius": 8,
          "side": ["width": 3, "color": "black"],
        ],
        "collapsed_shape": ["_type": "stadium"],
        "visual_density": "compact",
        "enable_feedback": false,
        "dense": true,
      ],
      backend: ExpansionTilePropertyBackend())

    let presentation = RufletExpansionTilePresentation(control: control)
    XCTAssertNotNil(presentation.resolvedBackgroundColor(expanded: true))
    XCTAssertNotNil(presentation.resolvedBackgroundColor(expanded: false))
    XCTAssertNotNil(presentation.resolvedIconColor(expanded: true))
    XCTAssertNotNil(presentation.resolvedIconColor(expanded: false))
    XCTAssertNotNil(presentation.resolvedTextColor(expanded: true))
    XCTAssertNotNil(presentation.resolvedTextColor(expanded: false))
    XCTAssertEqual(presentation.expandedShape.kind, .beveledRectangle)
    XCTAssertEqual(presentation.expandedShape.radius.topLeft, 8)
    XCTAssertEqual(presentation.expandedShape.side?.width, 3)
    XCTAssertEqual(presentation.collapsedShape.kind, .stadium)
    XCTAssertEqual(presentation.visualDensity, .compact)
    XCTAssertFalse(presentation.enableFeedback)
    XCTAssertEqual(presentation.horizontalTitleGap, 8)
    XCTAssertEqual(presentation.minimumTileHeight, 40)
  }

  func testExplicitMinimumHeightAndDefaultFeedbackMatchPinnedContract() {
    let control = RufletControl(
      id: 2,
      type: "ExpansionTile",
      properties: ["min_tile_height": 63],
      backend: ExpansionTilePropertyBackend())
    let presentation = RufletExpansionTilePresentation(control: control)

    XCTAssertEqual(presentation.minimumTileHeight, 63)
    XCTAssertTrue(presentation.enableFeedback)
    XCTAssertEqual(presentation.horizontalTitleGap, 16)
  }

  func testSourceConsumesEightRealPinnedPropertiesAndLeavesAdaptiveHonest() throws {
    let source = try String(
      contentsOf: packageRoot.appendingPathComponent(
        "Sources/RufletEngine/Controls/expansion_tile.swift"),
      encoding: .utf8)
    for property in [
      "collapsed_bgcolor", "collapsed_icon_color", "collapsed_shape", "collapsed_text_color",
      "enable_feedback", "icon_color", "shape", "visual_density",
    ] {
      XCTAssertTrue(source.contains("\"\(property)\""), property)
    }
    XCTAssertFalse(source.contains("control.adaptive"))
    XCTAssertFalse(source.contains("control.boolean(\"adaptive\""))
  }

  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }
}

@MainActor
private final class ExpansionTilePropertyBackend: RufletBackendProtocol {
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
