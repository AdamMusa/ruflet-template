import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletUI

final class CupertinoSegmentedBehaviorResidualTests: XCTestCase {
  func testSlidingDefaultsPreservePinnedDynamicColorContract() {
    let configuration = RufletCupertinoSegmentedConfiguration(node: ControlNode(
      id: 1, type: "CupertinoSlidingSegmentedButton"))

    XCTAssertNil(configuration.backgroundColorToken)
    XCTAssertNil(configuration.thumbColorToken)
    XCTAssertEqual(
      RufletCupertinoSegmentedConfiguration.defaultBackgroundToken,
      "tertiarySystemFill")
    XCTAssertEqual(
      RufletCupertinoSegmentedConfiguration.defaultThumbLightARGB,
      0xFFFFFFFF)
    XCTAssertEqual(
      RufletCupertinoSegmentedConfiguration.defaultThumbDarkARGB,
      0xFF636366)
  }

  func testExplicitSlidingColorsRemainSeparateFromRegularColorNamespace() {
    let sliding = RufletCupertinoSegmentedConfiguration(node: ControlNode(
      id: 2, type: "CupertinoSlidingSegmentedButton",
      props: ["bgcolor": .string("red"), "thumb_color": .string("blue")]))
    let regular = RufletCupertinoSegmentedConfiguration(node: ControlNode(
      id: 3, type: "CupertinoSegmentedButton",
      props: ["bgcolor": .string("red"), "thumb_color": .string("blue")]))

    XCTAssertEqual(sliding.backgroundColorToken, "red")
    XCTAssertEqual(sliding.thumbColorToken, "blue")
    XCTAssertNil(regular.backgroundColorToken)
    XCTAssertNil(regular.thumbColorToken)
  }

  func testSelectionWritesLocalAndWireStateBeforeChangeEvent() {
    var calls: [String] = []
    let node = ControlNode(
      id: 4, type: "CupertinoSlidingSegmentedButton",
      props: ["on_change": .bool(true)])
    let sink = RufletEventSink(
      send: { _, name, value in calls.append("event:\(name):\(value.intValue ?? -1)") },
      setLocal: { _, key, value in calls.append("local:\(key):\(value.intValue ?? -1)") },
      update: { _, props in
        calls.append("update:selected_index:\(props["selected_index"]?.intValue ?? -1)")
      })

    RufletCupertinoSegmentedEvents.select(index: 2, on: node, to: sink)

    XCTAssertEqual(calls, [
      "local:selected_index:2",
      "update:selected_index:2",
      "event:change:2",
    ])
  }

  func testSelectionStillUpdatesRubyWithoutAChangeHandler() {
    var calls: [String] = []
    let node = ControlNode(id: 5, type: "CupertinoSegmentedButton")
    let sink = RufletEventSink(
      send: { _, _, _ in calls.append("event") },
      setLocal: { _, _, _ in calls.append("local") },
      update: { _, _ in calls.append("update") })

    RufletCupertinoSegmentedEvents.select(index: 1, on: node, to: sink)

    XCTAssertEqual(calls, ["local", "update"])
  }

  func testInheritedDisabledStateSuppressesSelectionCompletely() {
    var calls = 0
    let node = ControlNode(
      id: 6, type: "CupertinoSegmentedButton",
      props: ["on_change": .bool(true)],
      internals: ["_flet_resolved_disabled": .bool(true)])
    let sink = RufletEventSink(
      send: { _, _, _ in calls += 1 },
      setLocal: { _, _, _ in calls += 1 },
      update: { _, _ in calls += 1 })

    RufletCupertinoSegmentedEvents.select(index: 1, on: node, to: sink)

    XCTAssertEqual(calls, 0)
  }
}
