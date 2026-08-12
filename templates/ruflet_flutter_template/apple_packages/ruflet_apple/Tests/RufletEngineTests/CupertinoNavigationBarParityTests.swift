import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class CupertinoNavigationBarParityTests: XCTestCase {
  func testPinnedCupertinoTabBarDefaultsAndDestinationOrder() {
    let presentation = RufletCupertinoNavigationBarPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoNavigationBar",
        props: [
          "destinations": .array([.controlRef(2), .controlRef(3), .controlRef(2)])
        ]))

    XCTAssertEqual(presentation.destinationIDs, [2, 3])
    XCTAssertEqual(presentation.selectedIndex, 0)
    XCTAssertEqual(presentation.iconSize, 30)
    XCTAssertFalse(presentation.disabled)
    XCTAssertNil(presentation.activeColorToken)
    XCTAssertNil(presentation.indicatorColorToken)
    XCTAssertNil(presentation.inactiveColorToken)
    XCTAssertNil(presentation.topBorder)
    XCTAssertEqual(RufletCupertinoNavigationBarDefaults.height, 50)
    XCTAssertEqual(RufletCupertinoNavigationBarDefaults.itemBottomPadding, 4)
  }

  func testAdaptiveIndicatorColorFallbackAndExplicitValuesArePreserved() {
    let presentation = RufletCupertinoNavigationBarPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoNavigationBar",
        props: [
          "selected_index": .int(1),
          "icon_size": .double(42),
          "disabled": .bool(true),
          "active_color": .string("red"),
          "indicator_color": .string("green"),
          "inactive_color": .string("blue"),
        ]))

    XCTAssertEqual(presentation.selectedIndex, 1)
    XCTAssertEqual(presentation.iconSize, 42)
    XCTAssertTrue(presentation.disabled)
    XCTAssertEqual(presentation.activeColorToken, "red")
    XCTAssertEqual(presentation.indicatorColorToken, "green")
    XCTAssertEqual(presentation.inactiveColorToken, "blue")
  }

  func testExactConstructorValidation() {
    let tooFew = RufletCupertinoNavigationBarPresentation(
      node: ControlNode(id: 1, type: "CupertinoNavigationBar"))
    XCTAssertEqual(
      tooFew.validationError(destinationCount: 1),
      "Tabs need at least 2 items to conform to Apple's HIG")

    let invalidSelection = RufletCupertinoNavigationBarPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoNavigationBar",
        props: ["selected_index": .int(3)]))
    XCTAssertEqual(
      invalidSelection.validationError(destinationCount: 2),
      "CupertinoNavigationBar.selected_index must be between 0 and 1")

    let invalidIcon = RufletCupertinoNavigationBarPresentation(
      node: ControlNode(
        id: 1, type: "CupertinoNavigationBar",
        props: ["icon_size": .double(-1)]))
    XCTAssertEqual(
      invalidIcon.validationError(destinationCount: 2),
      "CupertinoNavigationBar.icon_size must be greater than or equal to 0")
  }

  func testTopBorderSupportsHairlineAndNone() {
    XCTAssertNil(RufletCupertinoNavigationBarBorder(nil))
    XCTAssertNil(RufletCupertinoNavigationBarBorder(.map([
      "top": .map(["style": .string("none")])
    ])))
    let border = RufletCupertinoNavigationBarBorder(.map([
      "top": .map(["color": .string("red"), "width": .double(0)])
    ]))
    XCTAssertEqual(border?.colorToken, "red")
    XCTAssertEqual(border?.width, 0)
  }

  func testSelectionUpdatesLocalAndBackendBeforeChange() {
    let node = ControlNode(
      id: 7, type: "CupertinoNavigationBar", props: ["on_change": .bool(true)])
    var order: [String] = []
    var data: RufletValue?
    let events = RufletEventSink(
      send: { _, name, value in order.append(name); data = value },
      setLocal: { _, key, value in
        order.append("local:\(key):\(value.intValue ?? -1)")
      },
      update: { _, props in
        order.append("update:\(props["selected_index"]?.intValue ?? -1)")
      })

    RufletCupertinoNavigationBarEvents.select(index: 2, on: node, to: events)

    XCTAssertEqual(order, ["local:selected_index:2", "update:2", "change"])
    XCTAssertEqual(data, .int(2))
  }

  func testSelectionStillSynchronizesWithoutHandler() {
    let node = ControlNode(id: 7, type: "CupertinoNavigationBar")
    var local: RufletValue?
    var update: RufletValue?
    var fired = false
    let events = RufletEventSink(
      send: { _, _, _ in fired = true },
      setLocal: { _, _, value in local = value },
      update: { _, props in update = props["selected_index"] })

    RufletCupertinoNavigationBarEvents.select(index: 1, on: node, to: events)

    XCTAssertEqual(local, .int(1))
    XCTAssertEqual(update, .int(1))
    XCTAssertFalse(fired)
  }
}
