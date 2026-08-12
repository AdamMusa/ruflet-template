import RufletEngine
@testable import RufletUI
import XCTest

final class PageViewVisibilityResidualTests: XCTestCase {
  func testPagesComeOnlyFromVisibleControlsSlot() {
    let pageView = ControlNode(id: 1, type: "PageView", props: [
      "controls": .array([.controlRef(10), .controlRef(11), .controlRef(12)]),
    ])
    let nodes = [
      10: ControlNode(id: 10, type: "Text"),
      11: ControlNode(id: 11, type: "Text", props: ["visible": .bool(false)]),
      12: ControlNode(id: 12, type: "Text", props: ["visible": .bool(true)]),
    ]

    XCTAssertEqual(PageViewParity.visibleControlIDs(pageView, in: nodes), [10, 12])
    XCTAssertEqual(
      PageViewParity.pages(PageViewParity.visibleControlIDs(pageView, in: nodes)),
      [.init(index: 0, id: 10), .init(index: 1, id: 12)])
  }

  func testSelectedAndCommandIndicesUseVisiblePageCount() {
    let pageView = ControlNode(id: 1, type: "PageView", props: [
      "controls": .array([.controlRef(10), .controlRef(11), .controlRef(12)]),
    ])
    let nodes = [
      10: ControlNode(id: 10, type: "Text", props: ["visible": .bool(false)]),
      11: ControlNode(id: 11, type: "Text"),
      12: ControlNode(id: 12, type: "Text"),
    ]
    let count = PageViewParity.visibleControlIDs(pageView, in: nodes).count

    XCTAssertEqual(count, 2)
    XCTAssertEqual(CollectionParity.clampedIndex(5, count: count), 1)
    XCTAssertEqual(CollectionParity.clampedIndex(-1, count: count), 0)
  }

  func testAuxiliaryChildReferencesCannotBecomePages() {
    let pageView = ControlNode(id: 1, type: "PageView", props: [
      "controls": .array([.controlRef(10)]),
      "unrelated_slot": .controlRef(20),
    ])
    let nodes = [
      10: ControlNode(id: 10, type: "Text"),
      20: ControlNode(id: 20, type: "Text"),
    ]

    XCTAssertEqual(PageViewParity.visibleControlIDs(pageView, in: nodes), [10])
  }
}
