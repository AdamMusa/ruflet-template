import RufletEngine
@testable import RufletUI
import XCTest

final class TabBarVisibilityResidualTests: XCTestCase {
  func testTabBarExcludesInvisibleStructuralTabs() {
    let first = ControlNode(id: 2, type: "Tab", props: [
      "label": .string("First"),
    ])
    let hidden = ControlNode(id: 3, type: "Tab", props: [
      "label": .string("Hidden"), "visible": .bool(false),
    ])
    let last = ControlNode(id: 4, type: "Tab", props: [
      "label": .string("Last"), "visible": .bool(true),
    ])

    XCTAssertEqual(TabBarPresentation.visibleTabs([first, hidden, last]).map(\.id), [2, 4])
  }

  func testTabBarIndexesFollowVisibleSequence() {
    let hidden = ControlNode(id: 2, type: "Tab", props: [
      "label": .string("Hidden"), "visible": .bool(false),
    ])
    let selected = ControlNode(id: 3, type: "Tab", props: [
      "label": .string("Selected"),
    ])
    let tabs = TabBarPresentation.visibleTabs([hidden, selected])

    XCTAssertEqual(tabs.firstIndex(where: { $0.id == selected.id }), 0)
  }

  func testTabBarKeepsArbitraryVisibleControls() {
    let custom = ControlNode(id: 5, type: "Container", props: [
      "visible": .bool(true),
    ])

    XCTAssertEqual(TabBarPresentation.visibleTabs([custom]).map(\.id), [5])
  }
}
