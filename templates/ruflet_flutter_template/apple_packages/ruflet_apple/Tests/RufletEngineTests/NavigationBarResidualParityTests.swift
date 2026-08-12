import RufletEngine
@testable import RufletUI
import XCTest

final class NavigationBarResidualParityTests: XCTestCase {
  func testStructuralDestinationsAreFilteredByVisibility() {
    let first = ControlNode(id: 2, type: "NavigationBarDestination")
    let hidden = ControlNode(id: 3, type: "NavigationBarDestination", props: [
      "visible": .bool(false),
    ])
    let last = ControlNode(id: 4, type: "NavigationBarDestination", props: [
      "visible": .bool(true),
    ])

    XCTAssertEqual(
      ChromeDefaults.visibleNavigationBarDestinations([first, hidden, last]).map(\.id),
      [2, 4])
  }

  func testValidationCountsVisibleDestinationsOnly() {
    let visible = ControlNode(id: 2, type: "NavigationBarDestination")
    let hidden = ControlNode(id: 3, type: "NavigationBarDestination", props: [
      "visible": .bool(false),
    ])
    let destinations = ChromeDefaults.visibleNavigationBarDestinations([visible, hidden])

    XCTAssertEqual(
      ChromeDefaults.navigationBarValidation(
        destinationCount: destinations.count, selectedIndex: 0),
      "NavigationBar.destinations requires at least two destinations")
  }

  func testSelectedIndexUsesVisibleDestinationOrder() {
    let hidden = ControlNode(id: 2, type: "NavigationBarDestination", props: [
      "visible": .bool(false),
    ])
    let first = ControlNode(id: 3, type: "NavigationBarDestination")
    let second = ControlNode(id: 4, type: "NavigationBarDestination")
    let destinations = ChromeDefaults.visibleNavigationBarDestinations([hidden, first, second])

    XCTAssertEqual(destinations.firstIndex(where: { $0.id == first.id }), 0)
    XCTAssertEqual(destinations.firstIndex(where: { $0.id == second.id }), 1)
    XCTAssertNil(
      ChromeDefaults.navigationBarValidation(
        destinationCount: destinations.count, selectedIndex: 1))
  }
}
