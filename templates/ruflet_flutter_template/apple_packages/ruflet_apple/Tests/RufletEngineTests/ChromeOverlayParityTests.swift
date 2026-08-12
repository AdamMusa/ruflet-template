@testable import RufletUI
import RufletEngine
import RufletProtocol
import XCTest

final class ChromeOverlayParityTests: XCTestCase {
  func testMaterialChromeUsesPinnedFletAndFlutterConstructorDefaults() {
    let appBar = ChromeDefaults.appBar(ControlNode(id: 1, type: "AppBar"))
    XCTAssertEqual(appBar.toolbarHeight, 56)
    XCTAssertEqual(appBar.toolbarOpacity, 1)
    XCTAssertFalse(appBar.excludeHeaderSemantics)
    XCTAssertFalse(appBar.forceMaterialTransparency)

    let bottom = ChromeDefaults.bottomAppBar(ControlNode(id: 2, type: "BottomAppBar"))
    XCTAssertEqual(bottom.notchMargin, 4)
    XCTAssertNil(bottom.height)

    let navigation = ChromeDefaults.navigationBar(ControlNode(id: 3, type: "NavigationBar"))
    XCTAssertEqual(navigation.height, 80)
    XCTAssertTrue(navigation.showsLabel(selected: false))

    let rail = ChromeDefaults.navigationRail(ControlNode(id: 4, type: "NavigationRail"))
    XCTAssertEqual(rail.minWidth, 72)
    XCTAssertEqual(rail.groupAlignment, -1)
    XCTAssertTrue(rail.useIndicator)
    XCTAssertTrue(rail.showsLabel(extended: false, selected: false))
  }

  func testNavigationRailLabelTypeAndExplicitGeometryArePreserved() {
    let selectedOnly = ChromeDefaults.navigationRail(ControlNode(
      id: 4, type: "NavigationRail",
      props: [
        "label_type": .string("selected"), "min_width": .double(88),
        "group_alignment": .double(0.5), "use_indicator": .bool(false),
      ]))
    XCTAssertFalse(selectedOnly.showsLabel(extended: false, selected: false))
    XCTAssertTrue(selectedOnly.showsLabel(extended: false, selected: true))
    XCTAssertTrue(selectedOnly.showsLabel(extended: true, selected: false))
    XCTAssertEqual(selectedOnly.minWidth, 88)
    XCTAssertEqual(selectedOnly.groupAlignment, 0.5)
    XCTAssertFalse(selectedOnly.useIndicator)
  }

  func testMaterialMenuDefaultsMatchPinnedFletConstructors() {
    let popup = ControlNode(id: 10, type: "PopupMenuButton")
    XCTAssertEqual(MaterialMenuDefaults.popupIconSize(popup), 24)
    XCTAssertEqual(MaterialMenuDefaults.popupPadding(popup).top, 8)
    XCTAssertEqual(MaterialMenuDefaults.popupPadding(popup).leading, 8)
    XCTAssertEqual(MaterialMenuDefaults.popupClipBehavior(popup), "none")

    XCTAssertEqual(
      MaterialMenuDefaults.submenuClipBehavior(ControlNode(id: 11, type: "SubmenuButton")),
      "hardEdge")
    let item = ControlNode(id: 12, type: "MenuItemButton")
    XCTAssertEqual(MaterialMenuDefaults.menuItemClipBehavior(item), "none")
    XCTAssertTrue(MaterialMenuDefaults.menuItemClosesOnClick(item))
    XCTAssertTrue(MaterialMenuDefaults.menuItemFocusesOnHover(item))
    XCTAssertEqual(
      MaterialMenuDefaults.popupItemHeight(ControlNode(id: 13, type: "PopupMenuItem")), 48)
  }

  func testMaterialMenuLifecycleCallbacksAreEnabledAndDisabledLikeFlet() {
    let listening = ControlNode(
      id: 20, type: "SubmenuButton",
      props: ["on_open": .bool(true), "on_close": .bool(true), "on_hover": .bool(true)])
    XCTAssertTrue(MaterialMenuDefaults.shouldEmit(listening, event: "open"))
    XCTAssertTrue(MaterialMenuDefaults.shouldEmit(listening, event: "close"))
    XCTAssertTrue(MaterialMenuDefaults.shouldEmit(listening, event: "hover"))
    XCTAssertFalse(MaterialMenuDefaults.shouldEmit(listening, event: "click"))

    let disabled = ControlNode(
      id: 21, type: "MenuItemButton",
      props: ["on_click": .bool(true), "disabled": .bool(true)])
    XCTAssertFalse(MaterialMenuDefaults.shouldEmit(disabled, event: "click"))
  }

  func testMaterialMenuUsesExplicitSlotsAndDeduplicatesLegacyChildren() {
    let node = ControlNode(
      id: 30, type: "MenuBar",
      props: ["controls": .array([.controlRef(2), .controlRef(3), .controlRef(2)])])
    XCTAssertEqual(MaterialMenuDefaults.controlIDs(node, key: "controls"), [2, 3])
  }

  func testChromeAndMenuDescriptorsExposeFletEvents() throws {
    XCTAssertEqual(events("CupertinoNavigationBar"), ["change"])
    XCTAssertEqual(events("MenuItemButton"), ["click", "hover"])
    XCTAssertEqual(events("SubmenuButton"), ["close", "hover", "open"])
    XCTAssertEqual(events("SnackBar"), ["action", "dismiss", "visible"])
    XCTAssertEqual(events("SnackBarAction"), ["click"])
  }

  func testNavigationChangeCommitsIntegerIndexBeforeReporting() {
    let node = ControlNode(
      id: 41, type: "CupertinoNavigationBar", props: ["on_change": .bool(true)])
    var local: (String, RufletValue)?
    var sent: (String, RufletValue)?
    let sink = RufletEventSink(
      send: { _, name, value in sent = (name, value) },
      setLocal: { _, key, value in local = (key, value) })

    sink.commit(node, key: "selected_index", value: .int(2))

    XCTAssertEqual(local?.0, "selected_index")
    XCTAssertEqual(local?.1, .int(2))
    XCTAssertEqual(sent?.0, "change")
    XCTAssertEqual(sent?.1, .int(2))
  }

  func testHoverPayloadIsFletBooleanAndActionClickBelongsToChild() {
    let item = ControlNode(
      id: 5, type: "MenuItemButton", props: ["on_hover": .bool(true)])
    let action = ControlNode(
      id: 6, type: "SnackBarAction", props: ["on_click": .bool(true)])
    var events: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { events.append(($0, $1, $2)) })

    sink.fire(item, "hover", data: .bool(true))
    sink.fire(action, "click")

    XCTAssertEqual(events.count, 2)
    XCTAssertEqual(events[0].0, 5)
    XCTAssertEqual(events[0].1, "hover")
    XCTAssertEqual(events[0].2, .bool(true))
    XCTAssertEqual(events[1].0, 6)
    XCTAssertEqual(events[1].1, "click")
    XCTAssertEqual(events[1].2, .null)
  }

  func testTabsAlreadyExposeStructuralEventsAndMoveTo() {
    for type in ["Tabs", "TabBar", "TabBarView"] {
      XCTAssertEqual(events(type), ["change", "click", "hover"], type)
      XCTAssertEqual(methods(type), ["move_to"], type)
    }
  }

  func testAlertDialogOnlyUsesCupertinoDesignWhenExplicitOrAdaptive() {
    let material = ControlNode(id: 70, type: "AlertDialog")
    let adaptive = ControlNode(
      id: 71, type: "AlertDialog", props: ["adaptive": .bool(true)])
    let cupertino = ControlNode(id: 72, type: "CupertinoAlertDialog")

    XCTAssertFalse(RufletOverlaySemantics.usesCupertinoDialog(material))
    XCTAssertTrue(RufletOverlaySemantics.usesCupertinoDialog(adaptive))
    XCTAssertTrue(RufletOverlaySemantics.usesCupertinoDialog(cupertino))
  }

  func testOverlayBarrierDismissalUsesTheControlsOwnFletFlag() {
    XCTAssertTrue(
      RufletOverlaySemantics.allowsBarrierDismiss(ControlNode(id: 80, type: "AlertDialog")))
    XCTAssertFalse(
      RufletOverlaySemantics.allowsBarrierDismiss(
        ControlNode(id: 81, type: "AlertDialog", props: ["modal": .bool(true)])))
    XCTAssertTrue(
      RufletOverlaySemantics.allowsBarrierDismiss(ControlNode(id: 82, type: "BottomSheet")))
    XCTAssertFalse(
      RufletOverlaySemantics.allowsBarrierDismiss(
        ControlNode(id: 83, type: "BottomSheet", props: ["dismissible": .bool(false)])))
  }

  func testOverlayDismissUpdatesOpenBeforeSendingDismiss() {
    let node = ControlNode(
      id: 90, type: "SnackBar", props: ["on_dismiss": .bool(true)])
    var operations: [String] = []
    let sink = RufletEventSink(
      send: { _, name, _ in operations.append("event:\(name)") },
      setLocal: { _, key, value in operations.append("local:\(key)=\(value == .bool(false))") },
      update: { _, values in operations.append("update:\(values["open"] == .bool(false))") })

    RufletOverlaySemantics.dismiss(node, through: sink)

    XCTAssertEqual(operations, ["local:open=true", "update:true", "event:dismiss"])
  }

  private func events(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedEvents ?? []
  }

  private func methods(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedMethods ?? []
  }
}
