import RufletEngine
@testable import RufletUI
import XCTest

final class NavigationRailResidualParityTests: XCTestCase {
  func testStructuralRailDestinationsAreFilteredByVisibility() {
    let first = ControlNode(id: 2, type: "NavigationRailDestination")
    let hidden = ControlNode(id: 3, type: "NavigationRailDestination", props: [
      "visible": .bool(false),
    ])
    let last = ControlNode(id: 4, type: "NavigationRailDestination", props: [
      "visible": .bool(true),
    ])

    XCTAssertEqual(
      ChromeDefaults.visibleNavigationRailDestinations([first, hidden, last]).map(\.id),
      [2, 4])
  }

  func testRailSelectionValidationUsesVisibleDestinationCount() {
    let visible = ControlNode(id: 2, type: "NavigationRailDestination")
    let hidden = ControlNode(id: 3, type: "NavigationRailDestination", props: [
      "visible": .bool(false),
    ])
    let destinations = ChromeDefaults.visibleNavigationRailDestinations([visible, hidden])

    XCTAssertEqual(
      ChromeDefaults.navigationRailValidation(
        destinationCount: destinations.count, selectedIndex: 1,
        minWidth: 80, minExtendedWidth: 256, groupAlignment: -1),
      "NavigationRail.selected_index must be nil or reference a destination")
  }

  func testRailChangeIndexFollowsVisibleOrder() {
    let hidden = ControlNode(id: 2, type: "NavigationRailDestination", props: [
      "visible": .bool(false),
    ])
    let first = ControlNode(id: 3, type: "NavigationRailDestination")
    let second = ControlNode(id: 4, type: "NavigationRailDestination")
    let destinations = ChromeDefaults.visibleNavigationRailDestinations([hidden, first, second])

    XCTAssertEqual(destinations.firstIndex(where: { $0.id == first.id }), 0)
    XCTAssertEqual(destinations.firstIndex(where: { $0.id == second.id }), 1)
  }
}
