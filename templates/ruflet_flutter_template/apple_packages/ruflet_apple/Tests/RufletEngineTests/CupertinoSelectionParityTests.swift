import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class CupertinoSelectionParityTests: XCTestCase {
  private func checkbox(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: "CupertinoCheckbox", props: props)
  }

  private func radio(_ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 3, type: "CupertinoRadio", props: props)
  }

  func testCheckboxKeepsPinnedConstructorDefaults() {
    let presentation = CupertinoCheckboxPresentation(node: checkbox())
    XCTAssertEqual(presentation.value, false)
    XCTAssertFalse(presentation.tristate)
    XCTAssertFalse(presentation.autofocus)
    XCTAssertFalse(presentation.disabled)
    XCTAssertEqual(presentation.spacing, 10)
    XCTAssertNil(presentation.label)
    XCTAssertEqual(presentation.labelPosition, .right)
    XCTAssertEqual(presentation.cornerRadius, 4)
    XCTAssertEqual(CupertinoCheckboxPresentation.visualSize, 14)
    XCTAssertEqual(CupertinoCheckboxPresentation.focusOutlineWidth, 3.5)
  }

  func testTristateCheckboxRestsMixedAndCyclesExactlyLikeFlet() {
    let node = checkbox(["tristate": .bool(true)])
    let mixed = CupertinoCheckboxPresentation(node: node)
    XCTAssertNil(mixed.value)
    XCTAssertTrue(mixed.selected, "Flutter includes mixed in WidgetState.selected")
    XCTAssertEqual(mixed.symbolName, "minus.square.fill")
    XCTAssertEqual(mixed.nextValue, .bool(false))

    let off = CupertinoCheckboxPresentation(node: node, value: false)
    XCTAssertFalse(off.selected)
    XCTAssertEqual(off.nextValue, .bool(true))

    let on = CupertinoCheckboxPresentation(node: node, value: true)
    XCTAssertTrue(on.selected)
    XCTAssertEqual(on.nextValue, .null)
  }

  func testCheckboxResolvesFillBorderShapeAndSemanticColors() {
    let presentation = CupertinoCheckboxPresentation(
      node: checkbox([
        "value": .bool(true),
        "active_color": .string("blue"),
        "check_color": .string("white"),
        "focus_color": .string("orange"),
        "fill_color": .map([
          "selected": .string("green"),
          "default": .string("grey"),
        ]),
        "border_side": .map([
          "selected": .map(["color": .string("red"), "width": .double(2)]),
          "default": .map(["color": .string("black"), "width": .double(1)]),
        ]),
        "shape": .map(["radius": .double(7)]),
      ]),
      focused: true)

    XCTAssertTrue(presentation.states.contains(.selected))
    XCTAssertTrue(presentation.states.contains(.focused))
    XCTAssertEqual(presentation.fillColorToken, "green")
    XCTAssertEqual(presentation.activeColorToken, "blue")
    XCTAssertEqual(presentation.checkColorToken, "white")
    XCTAssertEqual(presentation.focusColorToken, "orange")
    XCTAssertEqual(presentation.borderSide?.width, 2)
    XCTAssertEqual(presentation.cornerRadius, 7)
  }

  func testCheckboxChangeUpdatesLocalAndWireBeforeValuePayload() {
    var operations: [String] = []
    let control = checkbox(["on_change": .bool(true)])
    let sink = RufletEventSink(
      send: { _, name, data in operations.append("event:\(name):\(data)") },
      setLocal: { _, key, value in operations.append("local:\(key):\(value)") },
      update: { _, props in operations.append("update:\(props["value"]!)") })

    RufletValueControlEvents.commit(
      control, value: .bool(true), payload: .value, to: sink)

    XCTAssertEqual(
      operations,
      ["local:value:true", "update:true", "event:change:true"])
  }

  func testRadioRequiresAndReadsNearestGroupOwnedValue() {
    let outer = ControlNode(id: 10, type: "RadioGroup", props: [
      "value": .string("outer"), "content": .controlRef(11),
    ])
    let column = ControlNode(id: 11, type: "Column", props: [
      "children": .array([.controlRef(12)]),
    ])
    let inner = ControlNode(id: 12, type: "RadioGroup", props: [
      "value": .string("inner"), "content": .controlRef(3),
    ])
    let option = radio(["value": .string("inner")])
    let nodes = [10: outer, 11: column, 12: inner, 3: option]

    let group = RufletRadioGroupResolver.nearestGroup(containing: 3, in: nodes)
    XCTAssertEqual(group?.id, 12)
    XCTAssertTrue(CupertinoRadioPresentation(node: option, group: group).selected)
    XCTAssertNil(CupertinoRadioPresentation(node: option, group: nil).group)
  }

  func testRadioDefaultsAndColorRolesStayDistinct() {
    let group = ControlNode(id: 2, type: "RadioGroup", props: ["value": .string("a")])
    let presentation = CupertinoRadioPresentation(
      node: radio([
        "value": .string("a"),
        "active_color": .string("blue"),
        "inactive_color": .string("grey"),
        "fill_color": .string("white"),
      ]),
      group: group)

    XCTAssertTrue(presentation.selected)
    XCTAssertFalse(presentation.autofocus)
    XCTAssertFalse(presentation.toggleable)
    XCTAssertFalse(presentation.usesCheckmarkStyle)
    XCTAssertEqual(presentation.labelPosition, .right)
    XCTAssertEqual(presentation.activeColorToken, "blue")
    XCTAssertEqual(presentation.inactiveColorToken, "grey")
    XCTAssertEqual(presentation.fillColorToken, "white")
    XCTAssertEqual(CupertinoRadioPresentation.visualSize, 18)
    XCTAssertEqual(CupertinoRadioPresentation.focusOutlineWidth, 3)
  }

  func testRadioToggleableAppliesOnlyToMarkActivation() {
    let group = ControlNode(id: 2, type: "RadioGroup", props: ["value": .string("a")])
    let presentation = CupertinoRadioPresentation(
      node: radio(["value": .string("a"), "toggleable": .bool(true)]),
      group: group)

    XCTAssertEqual(presentation.nextValue(toggleIfSelected: true), .null)
    XCTAssertEqual(presentation.nextValue(toggleIfSelected: false), .string("a"))
  }

  func testRadioSupportsNativeCheckmarkStyleAndLabelPlacement() {
    let presentation = CupertinoRadioPresentation(
      node: radio([
        "value": .string("a"),
        "label": .string("Option A"),
        "label_position": .string("left"),
        "autofocus": .bool(true),
        "use_checkmark_style": .bool(true),
      ]),
      group: ControlNode(id: 2, type: "RadioGroup", props: ["value": .string("a")]))

    XCTAssertEqual(presentation.label, "Option A")
    XCTAssertEqual(presentation.labelPosition, .left)
    XCTAssertTrue(presentation.autofocus)
    XCTAssertTrue(presentation.usesCheckmarkStyle)
    XCTAssertEqual(presentation.symbolName, "checkmark")
  }

  func testCupertinoRadioIntentionallyDoesNotAdvertiseChange() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "CupertinoCheckbox")?.supportedEvents,
      ["blur", "change", "focus"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "CupertinoRadio")?.supportedEvents,
      ["blur", "focus"])
  }
}
