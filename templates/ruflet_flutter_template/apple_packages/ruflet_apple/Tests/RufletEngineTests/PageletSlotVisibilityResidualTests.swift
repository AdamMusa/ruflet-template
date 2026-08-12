import XCTest

import RufletEngine
import RufletProtocol

@testable import RufletUI

final class PageletSlotVisibilityResidualTests: XCTestCase {
  private func child(_ id: Int, visible: Bool = true, type: String = "Container") -> ControlNode {
    ControlNode(id: id, type: type, props: ["visible": .bool(visible)])
  }

  func testEveryWidgetSlotRequiresAResolvedVisibleControl() {
    let pagelet = PageletPresentation(node: ControlNode(
      id: 1, type: "Pagelet",
      props: [
        "appbar": .controlRef(2),
        "bottom_sheet": .controlRef(3),
        "floating_action_button": .controlRef(4),
      ]))
    let children = [
      2: child(2, visible: false, type: "AppBar"),
      3: child(3),
    ]

    XCTAssertNil(pagelet.visibleID(forKey: "appbar", nodeForID: { children[$0] }))
    XCTAssertEqual(pagelet.visibleID(forKey: "bottom_sheet", nodeForID: { children[$0] }), 3)
    XCTAssertNil(
      pagelet.visibleID(forKey: "floating_action_button", nodeForID: { children[$0] }))
  }

  func testHiddenNavigationBarFallsBackToVisibleBottomAppBar() {
    let pagelet = PageletPresentation(node: ControlNode(
      id: 1, type: "Pagelet",
      props: [
        "navigation_bar": .controlRef(2),
        "bottom_appbar": .controlRef(3),
      ]))
    let children = [2: child(2, visible: false), 3: child(3)]

    XCTAssertEqual(pagelet.bottomBarID(nodeForID: { children[$0] }), 3)
  }

  func testInvisibleDrawersAreRemovedFromScaffoldOwnership() {
    let pagelet = PageletPresentation(node: ControlNode(
      id: 1, type: "Pagelet",
      props: ["drawer": .controlRef(2), "end_drawer": .controlRef(3)]))
    let children = [2: child(2, visible: false), 3: child(3)]
    let resolved = pagelet.visibleScaffoldNode(nodeForID: { children[$0] })

    XCTAssertNil(resolved.controlID(forKey: "drawer"))
    XCTAssertEqual(resolved.controlID(forKey: "end_drawer"), 3)
  }

  func testOnlyPinnedAppBarTypesCanOwnThePageletBarSlot() {
    let pagelet = PageletPresentation(node: ControlNode(id: 1, type: "Pagelet"))
    XCTAssertTrue(pagelet.supportsAppBar(child(2, type: "AppBar")))
    XCTAssertTrue(pagelet.supportsAppBar(child(3, type: "CupertinoAppBar")))
    XCTAssertFalse(pagelet.supportsAppBar(child(4, type: "Text")))
  }
}
