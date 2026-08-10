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

  func testFoundationalControlsResolveThroughGeneratedContract() {
    let page = ControlNode(id: 1, type: "Page")
    XCTAssertEqual(page.fletString("title"), "")
    XCTAssertEqual(page.fletBool("rtl"), false)

    let view = ControlNode(id: 2, type: "View")
    XCTAssertEqual(view.fletString("vertical_alignment"), "start")
    XCTAssertEqual(view.fletString("horizontal_alignment"), "start")
    XCTAssertEqual(view.fletDouble("spacing"), 10)

    let appBar = ControlNode(id: 3, type: "AppBar")
    XCTAssertEqual(appBar.fletBool("automatically_imply_leading"), true)
    XCTAssertEqual(appBar.fletDouble("toolbar_opacity"), 1)

    let column = ControlNode(id: 4, type: "Column")
    XCTAssertEqual(column.fletString("alignment"), "start")
    XCTAssertEqual(column.fletString("horizontal_alignment"), "start")
    XCTAssertEqual(column.fletDouble("spacing"), 10)

    let container = ControlNode(id: 5, type: "Container")
    XCTAssertEqual(container.fletBool("ignore_interactions"), false)
    XCTAssertEqual(container.fletBool("ink"), false)
  }

  func testExplicitFoundationalValuesWinOverGeneratedDefaults() {
    let column = ControlNode(
      id: 1, type: "Column",
      props: [
        "alignment": .string("end"),
        "horizontal_alignment": .string("stretch"),
        "spacing": .double(24),
      ])

    XCTAssertEqual(column.fletString("alignment"), "end")
    XCTAssertEqual(column.fletString("horizontal_alignment"), "stretch")
    XCTAssertEqual(column.fletDouble("spacing"), 24)
  }
}
