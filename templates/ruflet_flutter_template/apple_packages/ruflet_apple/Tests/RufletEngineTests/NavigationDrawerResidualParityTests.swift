import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class NavigationDrawerResidualParityTests: XCTestCase {
  func testDrawerFiltersInvisibleChildrenBeforeDestinationIndexing() {
    let nodes = [
      1: ControlNode(id: 1, type: "Text"),
      2: ControlNode(
        id: 2, type: "NavigationDrawerDestination", props: ["visible": .bool(false)]),
      3: ControlNode(id: 3, type: "NavigationDrawerDestination"),
      4: ControlNode(id: 4, type: "Divider", props: ["visible": .bool(false)]),
      5: ControlNode(id: 5, type: "NavigationDrawerDestination"),
    ]

    XCTAssertEqual(
      NavigationDrawerVisibleControls.ids([1, 2, 3, 4, 5], in: nodes),
      [1, 3, 5])
  }

  func testMissingNodeIsNotInventedAsInvisible() {
    XCTAssertEqual(NavigationDrawerVisibleControls.ids([99], in: [:]), [99])
  }
}
