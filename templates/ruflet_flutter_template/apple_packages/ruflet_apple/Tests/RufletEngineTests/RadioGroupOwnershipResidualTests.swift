import RufletEngine
@testable import RufletUI
import XCTest

final class RadioGroupOwnershipResidualTests: XCTestCase {
  func testRadioGroupRejectsMissingDanglingAndInvisibleContent() {
    let missing = ControlNode(id: 1, type: "RadioGroup")
    let dangling = ControlNode(id: 2, type: "RadioGroup", props: [
      "content": .controlRef(99),
    ])
    let invisible = ControlNode(id: 3, type: "RadioGroup", props: [
      "content": .controlRef(4),
    ])
    let nodes = [
      4: ControlNode(id: 4, type: "Column", props: ["visible": .bool(false)]),
    ]

    XCTAssertNil(RufletRadioGroupResolver.visibleContentID(of: missing, in: nodes))
    XCTAssertNil(RufletRadioGroupResolver.visibleContentID(of: dangling, in: nodes))
    XCTAssertNil(RufletRadioGroupResolver.visibleContentID(of: invisible, in: nodes))
    XCTAssertEqual(
      RufletRadioGroupResolver.missingContentError,
      "RadioGroup.content must be provided and visible")
  }

  func testRadioGroupAcceptsResolvedVisibleContent() {
    let group = ControlNode(id: 1, type: "RadioGroup", props: [
      "content": .controlRef(2),
    ])
    let nodes = [2: ControlNode(id: 2, type: "Column")]

    XCTAssertEqual(RufletRadioGroupResolver.visibleContentID(of: group, in: nodes), 2)
  }

  func testRadioSelectionUpdatesGroupBeforeChangeEvent() {
    let group = ControlNode(id: 1, type: "RadioGroup", props: [
      "on_change": .bool(true),
    ])
    var operations: [String] = []
    let sink = RufletEventSink(
      send: { id, name, data in operations.append("event:\(id):\(name):\(data)") },
      setLocal: { id, key, value in operations.append("local:\(id):\(key):\(value)") },
      update: { id, props in operations.append("update:\(id):\(props["value"]!)") })

    RufletValueControlEvents.commit(
      group, value: .string("swift"), payload: .value, to: sink)

    XCTAssertEqual(operations, [
      "local:1:value:\"swift\"",
      "update:1:\"swift\"",
      "event:1:change:\"swift\"",
    ])
  }
}
