import RufletEngine
import RufletProtocol
import XCTest

final class FletControlDefaultsTests: XCTestCase {
  func testRowUsesPinnedFletDefaultsWhenPropertiesAreAbsent() {
    let row = ControlNode(id: 1, type: "Row")

    XCTAssertEqual(row.double("spacing"), 10)
    XCTAssertEqual(row.string("alignment"), "start")
    XCTAssertEqual(row.string("vertical_alignment"), "center")
    XCTAssertEqual(row.bool("tight"), false)
  }

  func testExplicitWirePropertyAlwaysWins() {
    let row = ControlNode(
      id: 1, type: "Row",
      props: ["spacing": .double(24), "vertical_alignment": .string("end")])

    XCTAssertEqual(row.double("spacing"), 24)
    XCTAssertEqual(row.string("vertical_alignment"), "end")
  }

  func testNullMatchesFletAndFallsBackToDefault() {
    let view = ControlNode(
      id: 1, type: "View",
      props: ["spacing": .null, "can_pop": .null])

    XCTAssertEqual(view.double("spacing"), 10)
    XCTAssertEqual(view.bool("can_pop"), true)
  }

  func testCommonDefaultsApplyToEveryControl() {
    let unknown = ControlNode(id: 1, type: "CustomExtensionControl")

    XCTAssertEqual(unknown.bool("visible"), true)
    XCTAssertEqual(unknown.bool("disabled"), false)
    XCTAssertEqual(unknown.double("opacity"), 1)
    XCTAssertNil(unknown.string("property_flet_does_not_define"))
  }
}
