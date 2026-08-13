import RufletProtocol
import XCTest
@testable import RufletEngine

final class AppleUtilityModelParityTests: XCTestCase {
  func testCupertinoColorCatalogHasPinnedWireNames() {
    XCTAssertEqual(rufletCupertinoColorNames.count, 46)
    XCTAssertTrue(rufletCupertinoColorNames.contains("systemblue"))
    XCTAssertTrue(rufletCupertinoColorNames.contains("tertiarysystemgroupedbackground"))
    XCTAssertNotNil(parseCupertinoColor("SYSTEM_BLUE"))
    XCTAssertNil(parseCupertinoColor("material_red_500"))
  }

  func testDismissibleParsersPreserveDirectionalThresholds() {
    let thresholds = parseDismissThresholds([
      "startToEnd": 0.25,
      "endToStart": "0.75",
      "none": 1,
    ])
    XCTAssertEqual(thresholds?[.startToEnd], 0.25)
    XCTAssertEqual(thresholds?[.endToStart], 0.75)
    XCTAssertNil(thresholds?[.none])
  }

  func testPaintParsesPinnedStrokeProperties() {
    let paint = parsePaint([
      "color": "#ff0000",
      "anti_alias": false,
      "stroke_width": 3,
      "stroke_miter_limit": 6,
      "stroke_cap": "round",
      "stroke_join": "bevel",
      "style": "stroke",
      "stroke_dash_pattern": [4, 2],
    ])
    XCTAssertEqual(paint?.antiAlias, false)
    XCTAssertEqual(paint?.strokeWidth, 3)
    XCTAssertEqual(paint?.strokeMiterLimit, 6)
    XCTAssertEqual(paint?.strokeCap, .round)
    XCTAssertEqual(paint?.strokeJoin, .bevel)
    XCTAssertEqual(paint?.style, .stroke)
    XCTAssertEqual(
      parsePaintStrokeDashPattern(["stroke_dash_pattern": [4, 2]]), [4, 2])
  }

  func testDragUpdateEventUsesPinnedCompactKeysAndRelativeDeltas() {
    let details = RufletDragUpdateDetails(
      localPosition: .init(x: 12, y: 18),
      globalPosition: .init(x: 120, y: 180),
      previousLocalPosition: .init(x: 10, y: 15),
      previousGlobalPosition: .init(x: 100, y: 150),
      primaryDelta: 3,
      timestamp: 0.5)
    XCTAssertEqual(details.value.map?["ld"]?.map?["x"], .double(2))
    XCTAssertEqual(details.value.map?["ld"]?.map?["y"], .double(3))
    XCTAssertEqual(details.value.map?["gd"]?.map?["x"], .double(20))
    XCTAssertEqual(details.value.map?["pd"], .double(3))
    XCTAssertEqual(details.value.map?["ts"], .double(0.5))
  }

  func testFilePickerModelsUsePinnedEventKeys() {
    let file = FilePickerFile(
      id: 7, name: "report.pdf", path: "/tmp/report.pdf", size: 42,
      bytes: Data([1, 2]))
    let result = FilePickerResultEvent(path: nil, files: [file]).value
    XCTAssertEqual(result.map?["path"], .null)
    XCTAssertEqual(result.map?["files"]?.array?.first?.map?["id"], .int(7))
    XCTAssertEqual(result.map?["files"]?.array?.first?.map?["bytes"], .binary(Data([1, 2])))

    let progress = FilePickerUploadProgressEvent(
      name: "report.pdf", progress: 0.5, error: nil).value
    XCTAssertEqual(progress.map?["file_name"], .string("report.pdf"))
    XCTAssertEqual(progress.map?["progress"], .double(0.5))
    XCTAssertEqual(progress.map?["error"], .null)
  }
}
