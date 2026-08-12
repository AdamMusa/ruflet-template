import CoreGraphics
import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

/// Translated from Flet 0.80.5's `context_menu.dart` state machine.
final class MaterialMenuContextParityTests: XCTestCase {
  func testMenuBarValidationCountsOnlyVisibleControls() {
    let node = ControlNode(
      id: 9, type: "MenuBar",
      props: ["controls": .array([.controlRef(10), .controlRef(11), .controlRef(10)])])
    let visibility = [10: false, 11: true]

    XCTAssertEqual(
      MaterialMenuDefaults.visibleControlIDs(node, key: "controls") { visibility[$0] },
      [11])

    // A missing explicit `visible` property resolves to Flet's base-control
    // default of true, not to hidden.
    XCTAssertEqual(
      MaterialMenuDefaults.visibleControlIDs(node, key: "controls") { _ in nil },
      [10, 11])
  }

  func testNamedMenuCollectionsDoNotAbsorbGenericChildren() {
    let node = ControlNode(
      id: 8, type: "PopupMenuButton",
      props: [
        "items": .array([.controlRef(20), .controlRef(20)]),
        "controls": .array([.controlRef(30)]),
      ])

    XCTAssertEqual(MaterialMenuDefaults.controlIDs(node, key: "items"), [20])
    XCTAssertEqual(MaterialMenuDefaults.controlIDs(node, key: "controls"), [30])
  }

  func testPointerTriggerDefaultsMatchFletConstructor() {
    let node = ControlNode(id: 1, type: "ContextMenu")

    XCTAssertEqual(RufletContextMenuDefaults.trigger(node, button: "primary"), "disabled")
    XCTAssertEqual(RufletContextMenuDefaults.trigger(node, button: "secondary"), "down")
    XCTAssertEqual(RufletContextMenuDefaults.trigger(node, button: "tertiary"), "down")
    XCTAssertNil(RufletContextMenuDefaults.trigger(node, button: nil))
    XCTAssertFalse(RufletContextMenuDefaults.permitsGesture(
      node, button: "primary", gesture: "long_press"))
    XCTAssertTrue(RufletContextMenuDefaults.permitsGesture(
      node, button: "secondary", gesture: "down"))
  }

  func testLongPressWireSpellingsNormalizeToFletEnumName() {
    for spelling in ["longPress", "long_press", "long-press"] {
      let node = ControlNode(
        id: 2, type: "ContextMenu", props: ["primary_trigger": .string(spelling)])

      XCTAssertEqual(RufletContextMenuDefaults.trigger(node, button: "primary"), "longPress")
      XCTAssertTrue(RufletContextMenuDefaults.permitsGesture(
        node, button: "primary", gesture: "long_press"))
    }
  }

  func testNativePointerEventsRespectEachFletButtonTrigger() {
    let defaults = ControlNode(id: 22, type: "ContextMenu")
    XCTAssertEqual(
      RufletContextMenuDefaults.pointerAction(defaults, nativeEvent: "secondary_tap_down"),
      .init(button: "secondary", gesture: "down"))
    XCTAssertEqual(
      RufletContextMenuDefaults.pointerAction(defaults, nativeEvent: "tertiary_tap_down"),
      .init(button: "tertiary", gesture: "down"))
    XCTAssertNil(RufletContextMenuDefaults.pointerAction(
      defaults, nativeEvent: "secondary_long_press_start"))

    let longPress = ControlNode(
      id: 23, type: "ContextMenu",
      props: [
        "secondary_trigger": .string("long_press"),
        "tertiary_trigger": .string("disabled"),
      ])
    XCTAssertNil(RufletContextMenuDefaults.pointerAction(
      longPress, nativeEvent: "secondary_tap_down"))
    XCTAssertEqual(
      RufletContextMenuDefaults.pointerAction(
        longPress, nativeEvent: "secondary_long_press_start"),
      .init(button: "secondary", gesture: "longPress"))
    XCTAssertNil(RufletContextMenuDefaults.pointerAction(
      longPress, nativeEvent: "tertiary_tap_down"))
  }

  func testProgrammaticOpenUsesSharedItemsWhilePointerUsesSpecificItems() {
    let node = ControlNode(
      id: 3,
      type: "ContextMenu",
      props: [
        "items": .array([.controlRef(10), .controlRef(11)]),
        "primary_items": .array([.controlRef(20)]),
        "secondary_items": .array([.controlRef(30), .controlRef(31)]),
        "tertiary_items": .array([.controlRef(40)]),
      ])

    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: nil), [10, 11])
    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: "primary"), [20])
    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: "secondary"), [30, 31])
    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: "tertiary"), [40])
  }

  func testExplicitEmptyButtonCollectionDoesNotFallBackToSharedItems() {
    let node = ControlNode(
      id: 4,
      type: "ContextMenu",
      props: ["items": .array([.controlRef(10)])])

    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: nil), [10])
    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: "primary"), [])
    XCTAssertEqual(RufletContextMenuDefaults.itemIDs(node, button: "secondary"), [])
  }

  func testOnlyPopupMenuItemsBecomeEntriesLikeBuildPopupMenuEntries() {
    let node = ControlNode(
      id: 40,
      type: "ContextMenu",
      props: ["items": .array([.controlRef(10), .controlRef(11), .controlRef(12)])])
    let types = [10: "PopupMenuItem", 11: "Text", 12: "PopupMenuItem"]

    XCTAssertEqual(
      RufletContextMenuDefaults.popupItemIDs(node, button: nil) { types[$0] },
      [10, 12])
  }

  func testOpenPositionConversionAndCenterFallbackMatchFlet() {
    let frame = CGRect(x: 100, y: 200, width: 80, height: 40)

    let fromLocal = RufletContextMenuDefaults.positions(
      global: nil, local: CGPoint(x: 5, y: 7), frame: frame)
    XCTAssertEqual(fromLocal.global, CGPoint(x: 105, y: 207))
    XCTAssertEqual(fromLocal.local, CGPoint(x: 5, y: 7))

    let fromGlobal = RufletContextMenuDefaults.positions(
      global: CGPoint(x: 130, y: 225), local: nil, frame: frame)
    XCTAssertEqual(fromGlobal.global, CGPoint(x: 130, y: 225))
    XCTAssertEqual(fromGlobal.local, CGPoint(x: 30, y: 25))

    let centered = RufletContextMenuDefaults.positions(
      global: nil, local: nil, frame: frame)
    XCTAssertEqual(centered.global, CGPoint(x: 140, y: 220))
    XCTAssertEqual(centered.local, CGPoint(x: 40, y: 20))
  }

  func testContextMenuEventPayloadPreservesFletCompactSchemaAndNulls() {
    let node = ControlNode(id: 5, type: "ContextMenu")
    let programmatic = RufletContextMenuDefaults.eventPayload(
      node: node,
      button: nil,
      global: CGPoint(x: 12, y: 34),
      local: CGPoint(x: 2, y: 4),
      itemCount: 3)

    XCTAssertEqual(programmatic["b"], .null)
    XCTAssertEqual(programmatic["tr"], .null)
    XCTAssertEqual(programmatic["id"], .null)
    XCTAssertEqual(programmatic["idx"], .null)
    XCTAssertEqual(programmatic["ic"], .int(3))
    XCTAssertEqual(programmatic["g"], .map(["x": .double(12), "y": .double(34)]))
    XCTAssertEqual(programmatic["l"], .map(["x": .double(2), "y": .double(4)]))

    let selection = RufletContextMenuDefaults.eventPayload(
      node: node,
      button: "secondary",
      global: .zero,
      local: nil,
      itemID: 91,
      itemIndex: 1,
      itemCount: 2)
    XCTAssertEqual(selection["b"], .string("secondary"))
    XCTAssertEqual(selection["tr"], .string("down"))
    XCTAssertEqual(selection["id"], .int(91))
    XCTAssertEqual(selection["idx"], .int(1))
    XCTAssertEqual(selection["l"], .null)
  }

  func testPointDecoderAcceptsOnlyCompleteOffsets() {
    XCTAssertEqual(
      RufletContextMenuDefaults.point(.map(["x": .double(1.5), "y": .int(2)])),
      CGPoint(x: 1.5, y: 2))
    XCTAssertNil(RufletContextMenuDefaults.point(.map(["x": .double(1.5)])))
    XCTAssertNil(RufletContextMenuDefaults.point(.string("1,2")))
  }
}
