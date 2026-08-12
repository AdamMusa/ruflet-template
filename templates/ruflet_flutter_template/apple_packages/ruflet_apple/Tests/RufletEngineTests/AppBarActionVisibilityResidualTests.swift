import RufletEngine
@testable import RufletUI
import XCTest

final class AppBarActionVisibilityResidualTests: XCTestCase {
  func testAppBarFiltersInvisibleActionChildren() {
    let nodes = actionNodes()

    XCTAssertEqual(
      ChromeDefaults.visibleAppBarActionIDs([2, 3, 4], in: nodes),
      [2, 4])
  }

  func testHiddenActionsDoNotOccupyAppleTitleCenteringSlots() {
    let appBar = ControlNode(id: 1, type: "AppBar")
    let visibleActions = ChromeDefaults.visibleAppBarActionIDs(
      [2, 3], in: actionNodes())

    XCTAssertEqual(visibleActions, [2])
    XCTAssertTrue(ChromeDefaults.appBarCentersTitle(
      appBar, visibleActionCount: visibleActions.count))
  }

  func testExplicitCenterTitleOverridesVisibleActionCount() {
    let leading = ControlNode(id: 1, type: "AppBar", props: [
      "center_title": .bool(false),
    ])
    let centered = ControlNode(id: 2, type: "AppBar", props: [
      "center_title": .bool(true),
    ])

    XCTAssertFalse(ChromeDefaults.appBarCentersTitle(leading, visibleActionCount: 0))
    XCTAssertTrue(ChromeDefaults.appBarCentersTitle(centered, visibleActionCount: 3))
  }

  private func actionNodes() -> [Int: ControlNode] {
    [
      2: ControlNode(id: 2, type: "IconButton"),
      3: ControlNode(id: 3, type: "IconButton", props: ["visible": .bool(false)]),
      4: ControlNode(id: 4, type: "TextButton", props: ["visible": .bool(true)]),
    ]
  }
}
