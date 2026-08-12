import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class CupertinoNavigationDestinationOwnershipResidualTests: XCTestCase {
  func testDestinationDisabledSuppressesTooltipButNotTabSelection() {
    let bar = RufletCupertinoNavigationBarPresentation(node: ControlNode(
      id: 1, type: "CupertinoNavigationBar"))
    let destination = ControlNode(
      id: 2, type: "NavigationDestination",
      props: ["disabled": .bool(true), "tooltip": .string("Settings")])

    XCTAssertTrue(bar.destinationIsInteractive(destination))
    XCTAssertNil(bar.destinationTooltip(destination))
  }

  func testEnabledDestinationKeepsTooltip() {
    let bar = RufletCupertinoNavigationBarPresentation(node: ControlNode(
      id: 3, type: "CupertinoNavigationBar"))
    let destination = ControlNode(
      id: 4, type: "NavigationDestination",
      props: ["tooltip": .string("Home")])

    XCTAssertTrue(bar.destinationIsInteractive(destination))
    XCTAssertEqual(bar.destinationTooltip(destination), "Home")
  }

  func testParentDisabledOwnsInteractionForEveryDestination() {
    let bar = RufletCupertinoNavigationBarPresentation(node: ControlNode(
      id: 5, type: "CupertinoNavigationBar",
      internals: ["_flet_resolved_disabled": .bool(true)]))

    XCTAssertFalse(bar.destinationIsInteractive(ControlNode(
      id: 6, type: "NavigationDestination")))
  }

  func testInheritedDisabledBarSuppressesAllSelectionSideEffects() {
    var calls = 0
    let node = ControlNode(
      id: 7, type: "CupertinoNavigationBar",
      props: ["on_change": .bool(true)],
      internals: ["_flet_resolved_disabled": .bool(true)])
    let events = RufletEventSink(
      send: { _, _, _ in calls += 1 },
      setLocal: { _, _, _ in calls += 1 },
      update: { _, _ in calls += 1 })

    RufletCupertinoNavigationBarEvents.select(index: 1, on: node, to: events)

    XCTAssertEqual(calls, 0)
  }

  func testDestinationDisabledDoesNotChangeEventOwnerOrPayload() {
    var order: [String] = []
    let bar = ControlNode(
      id: 8, type: "CupertinoNavigationBar",
      props: ["on_change": .bool(true)])
    let events = RufletEventSink(
      send: { target, name, value in
        order.append("event:\(target):\(name):\(value.intValue ?? -1)")
      },
      setLocal: { target, key, value in
        order.append("local:\(target):\(key):\(value.intValue ?? -1)")
      },
      update: { target, props in
        order.append("update:\(target):\(props["selected_index"]?.intValue ?? -1)")
      })

    RufletCupertinoNavigationBarEvents.select(index: 2, on: bar, to: events)

    XCTAssertEqual(order, [
      "local:8:selected_index:2",
      "update:8:2",
      "event:8:change:2",
    ])
  }
}
