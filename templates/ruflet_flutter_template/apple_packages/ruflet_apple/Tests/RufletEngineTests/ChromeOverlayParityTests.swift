@testable import RufletUI
import RufletEngine
import RufletProtocol
import XCTest

final class ChromeOverlayParityTests: XCTestCase {
  func testNativeChromeConsumesPinnedFletAndFlutterDefaults() {
    let appBar = ChromeDefaults.appBar(ControlNode(id: 1, type: "AppBar"))
    XCTAssertEqual(appBar.toolbarHeight, 56)
    XCTAssertEqual(appBar.toolbarOpacity, 1)
    XCTAssertEqual(appBar.titleSpacing, 16)
    XCTAssertEqual(appBar.leadingWidth, 56)
    XCTAssertEqual(appBar.scrolledUnderElevation, 3)
    XCTAssertFalse(appBar.excludeHeaderSemantics)
    XCTAssertFalse(appBar.forceMaterialTransparency)

    let bottom = ChromeDefaults.bottomAppBar(ControlNode(id: 2, type: "BottomAppBar"))
    XCTAssertEqual(bottom.notchMargin, 4)
    XCTAssertEqual(bottom.height, 80)
    XCTAssertEqual(bottom.elevation, 3)
    XCTAssertEqual(bottom.padding.top, 12)
    XCTAssertEqual(bottom.padding.leading, 16)

    let navigation = ChromeDefaults.navigationBar(ControlNode(id: 3, type: "NavigationBar"))
    XCTAssertEqual(navigation.height, 80)
    XCTAssertEqual(navigation.elevation, 3)
    XCTAssertEqual(navigation.labelPadding.top, 4)
    XCTAssertEqual(navigation.labelPadding.bottom, 0)
    XCTAssertTrue(navigation.showsLabel(selected: false))

    let rail = ChromeDefaults.navigationRail(ControlNode(id: 4, type: "NavigationRail"))
    XCTAssertEqual(rail.minWidth, 80)
    XCTAssertEqual(rail.minExtendedWidth, 256)
    XCTAssertEqual(rail.groupAlignment, -1)
    XCTAssertTrue(rail.useIndicator)
    XCTAssertTrue(rail.showsLabel(extended: false, selected: false))
  }

  func testBottomAppBarNotchParsesFletNotchedShapeContract() {
    let absent = ChromeDefaults.bottomAppBarNotch(ControlNode(id: 1, type: "BottomAppBar"))
    XCTAssertEqual(absent.kind, .automatic)
    XCTAssertEqual(absent.margin, 4)

    let circular = ChromeDefaults.bottomAppBarNotch(ControlNode(
      id: 2, type: "BottomAppBar",
      props: [
        "shape": .map(["_type": .string("circular"), "inverted": .bool(true)]),
        "notch_margin": .double(7),
      ]))
    XCTAssertEqual(circular.kind, .circular)
    XCTAssertTrue(circular.inverted)
    XCTAssertEqual(circular.margin, 7)

    let automatic = ChromeDefaults.bottomAppBarNotch(ControlNode(
      id: 3, type: "BottomAppBar",
      props: ["shape": .map(["_type": .string("auto")])]))
    XCTAssertEqual(automatic.kind, .automatic)
  }

  func testBottomAppBarRoundedClipAndExplicitValuesPreserveFletProps() {
    let values = ChromeDefaults.bottomAppBar(ControlNode(
      id: 5, type: "BottomAppBar",
      props: [
        "padding": .double(5), "height": .double(96), "elevation": .double(7),
        "border_radius": .map(["top_left": .double(12), "bottom_right": .double(4)]),
        "clip_behavior": .string("none"),
      ]))
    XCTAssertEqual(values.padding.top, 5)
    XCTAssertEqual(values.height, 96)
    XCTAssertEqual(values.elevation, 7)
    XCTAssertEqual(values.cornerRadii.topLeft, 12)
    XCTAssertEqual(values.cornerRadii.bottomRight, 4)
    // Flet's outer ClipRRect cannot use Clip.none and falls back to antiAlias.
    XCTAssertEqual(values.clipBehavior, "antiAlias")
  }

  func testChromeOutlinedBorderParserCoversEveryFletShapeKind() {
    let cases: [(String, ChromeOutlinedShapeKind)] = [
      ("roundedrectangle", .roundedRectangle), ("stadium", .stadium),
      ("circle", .circle), ("beveledrectangle", .beveledRectangle),
      ("continuousrectangle", .continuousRectangle),
    ]
    for (raw, expected) in cases {
      let value: RufletValue = .map([
        "_type": .string(raw), "radius": .double(9),
        "side": .map(["width": .double(2), "color": .string("red")]),
      ])
      let shape = ChromeDefaults.outlinedShape(value, defaultKind: .stadium)
      XCTAssertEqual(shape.kind, expected, raw)
      XCTAssertEqual(shape.radii.maximum, 9, raw)
      XCTAssertEqual(shape.sideWidth, 2, raw)
      XCTAssertEqual(shape.sideColorToken, "red", raw)
    }
  }

  func testNavigationDrawerUsesPinnedFlutterGeometry() {
    let values = ChromeDefaults.navigationDrawer(ControlNode(id: 6, type: "NavigationDrawer"))
    XCTAssertEqual(values.elevation, 1)
    XCTAssertEqual(values.tilePadding.leading, 12)
    XCTAssertEqual(values.tileHeight, 56)
    XCTAssertEqual(values.indicatorWidth, 336)
    XCTAssertEqual(values.indicatorHeight, 56)
  }

  func testPageNavigationUsesFletViewPopAndConfirmProtocols() {
    let page = ControlNode(id: 1, type: "Page")
    let ordinary = ControlNode(
      id: 9, type: "View", props: ["route": .string("/details")])
    var sent: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { sent.append(($0, $1, $2)) })

    XCTAssertFalse(RufletPageNavigation.canImplyLeading(viewCount: 1))
    XCTAssertTrue(RufletPageNavigation.canImplyLeading(viewCount: 2))
    RufletPageNavigation.commitPop(page: page, view: ordinary, events: sink)
    XCTAssertEqual(sent.first?.0, 1)
    XCTAssertEqual(sent.first?.1, "view_pop")
    XCTAssertEqual(sent.first?.2, .map(["route": .string("/details")]))

  }

  @MainActor
  func testViewConfirmPopWaitsForCommandAndThenUsesPageViewPopProtocol() {
    let page = ControlNode(id: 1, type: "Page")
    let view = ControlNode(
      id: 10, type: "View",
      props: ["route": .string("/guarded"), "on_confirm_pop": .bool(true)])
    var sent: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { sent.append(($0, $1, $2)) })
    let coordinator = RufletViewPopCoordinator()

    coordinator.request(page: page, view: view, events: sink)
    XCTAssertTrue(coordinator.isAwaitingConfirmation)
    XCTAssertEqual(sent.map(\.1), ["confirm_pop"])

    coordinator.confirm(shouldPop: false)
    XCTAssertFalse(coordinator.isAwaitingConfirmation)
    XCTAssertEqual(sent.map(\.1), ["confirm_pop"])

    coordinator.request(page: page, view: view, events: sink)
    coordinator.confirm(shouldPop: true)
    XCTAssertEqual(sent.last?.0, page.id)
    XCTAssertEqual(sent.last?.1, "view_pop")
    XCTAssertEqual(sent.last?.2, .map(["route": .string("/guarded")]))
  }

  func testViewDeclaresEveryFletScaffoldCommand() throws {
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "View")).supportedMethods,
      Set(["close_drawer", "close_end_drawer", "confirm_pop", "show_drawer", "show_end_drawer"]))
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "View")).supportedEvents,
      ["confirm_pop", "scroll"])
  }

  @MainActor
  func testScaffoldHostAggregatesRealScrollAndGeometrySources() {
    let host = RufletScaffoldHostState()
    host.reportScroll(sourceID: 1, offset: 12)
    host.reportScroll(sourceID: 2, offset: 0)
    XCTAssertTrue(host.scrolledUnder)
    host.removeScrollSource(1)
    XCTAssertFalse(host.scrolledUnder)

    host.reportBottomBar(frame: CGRect(x: 0, y: 500, width: 390, height: 80))
    host.reportFAB(frame: CGRect(x: 300, y: 472, width: 56, height: 56))
    XCTAssertEqual(host.fabFrameInBottomBar, CGRect(x: 300, y: -28, width: 56, height: 56))
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

  func testTabEventsAndMethodsStayOnTheirFletOwners() {
    XCTAssertEqual(events("Tabs"), ["change"])
    XCTAssertEqual(methods("Tabs"), ["move_to"])
    XCTAssertEqual(events("TabBar"), ["click", "hover"])
    XCTAssertEqual(methods("TabBar"), [])
    XCTAssertEqual(events("TabBarView"), [])
    XCTAssertEqual(methods("TabBarView"), [])
  }

  func testAlertDialogPreservesAdaptiveWireFlagButAlwaysUsesNativeApplePresentation() {
    let material = ControlNode(id: 70, type: "AlertDialog")
    let adaptive = ControlNode(
      id: 71, type: "AlertDialog", props: ["adaptive": .bool(true)])
    let cupertino = ControlNode(id: 72, type: "CupertinoAlertDialog")

    XCTAssertFalse(RufletOverlaySemantics.usesCupertinoDialog(material))
    XCTAssertTrue(RufletOverlaySemantics.usesCupertinoDialog(adaptive))
    XCTAssertTrue(RufletOverlaySemantics.usesCupertinoDialog(cupertino))
    XCTAssertTrue(RufletOverlaySemantics.usesNativeAppleDialog(material))
    XCTAssertTrue(RufletOverlaySemantics.usesNativeAppleDialog(adaptive))
    XCTAssertTrue(RufletOverlaySemantics.usesNativeAppleDialog(cupertino))
  }

  func testOverlayBarrierDismissalUsesTheControlsOwnFletFlag() {
    XCTAssertEqual(
      RufletOverlaySemantics.defaultBarrierOpacity(
        ControlNode(id: 79, type: "AlertDialog")), 0.54)
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
    // Flet's Cupertino popup API has no `dismissible` prop; it maps `modal`
    // to showCupertinoModalPopup.barrierDismissible instead.
    XCTAssertTrue(
      RufletOverlaySemantics.allowsBarrierDismiss(
        ControlNode(id: 84, type: "CupertinoBottomSheet",
                    props: ["dismissible": .bool(false)])))
    XCTAssertFalse(
      RufletOverlaySemantics.allowsBarrierDismiss(
        ControlNode(id: 85, type: "CupertinoBottomSheet", props: ["modal": .bool(true)])))
  }

  func testNativeDialogConsumesPinnedFletAndFlutterDefaults() {
    let defaults = OverlayDefaults.dialog(ControlNode(id: 100, type: "AlertDialog"))
    XCTAssertEqual(defaults.radius, 28)
    XCTAssertEqual(defaults.elevation, 6)
    XCTAssertEqual(defaults.inset.leading, 40)
    XCTAssertEqual(defaults.inset.top, 24)
    XCTAssertEqual(defaults.content.leading, 24)
    XCTAssertEqual(defaults.content.top, 20)
    XCTAssertEqual(defaults.actions.bottom, 24)

    let explicit = OverlayDefaults.dialog(ControlNode(
      id: 101, type: "AlertDialog",
      props: ["elevation": .double(9), "inset_padding": .double(7)]))
    XCTAssertEqual(explicit.elevation, 9)
    XCTAssertEqual(explicit.inset.leading, 7)
  }

  func testNativeBottomSheetConsumesPinnedFletDefaults() {
    let defaults = OverlayDefaults.sheet(ControlNode(id: 110, type: "BottomSheet"))
    XCTAssertEqual(defaults.radius, 28)
    XCTAssertEqual(defaults.elevation, 1)
    XCTAssertEqual(defaults.maximumWidth, 640)
    XCTAssertEqual(defaults.dragHandleWidth, 32)
    XCTAssertEqual(defaults.dragHandleHeight, 4)
    XCTAssertTrue(defaults.useSafeArea)
    XCTAssertTrue(defaults.dismissible)

    let explicit = OverlayDefaults.sheet(ControlNode(
      id: 111, type: "BottomSheet",
      props: ["use_safe_area": .bool(false), "dismissible": .bool(false)]))
    XCTAssertFalse(explicit.useSafeArea)
    XCTAssertFalse(explicit.dismissible)
  }

  func testNativeSnackBarConsumesPinnedFletDefaults() {
    let fixed = OverlayDefaults.snackBar(ControlNode(id: 120, type: "SnackBar"))
    XCTAssertEqual(fixed.elevation, 6)
    XCTAssertEqual(fixed.radius, 0)
    XCTAssertEqual(fixed.horizontalPadding, 24)
    XCTAssertEqual(fixed.durationMilliseconds, 4000)
    XCTAssertEqual(fixed.dismissDirection, "down")
    XCTAssertEqual(fixed.actionOverflowThreshold, 0.25)

    let floating = OverlayDefaults.snackBar(ControlNode(
      id: 121, type: "SnackBar", props: ["behavior": .string("floating")]))
    XCTAssertEqual(floating.radius, 4)
    XCTAssertEqual(floating.horizontalPadding, 16)
    XCTAssertEqual(floating.inset.leading, 15)
    XCTAssertEqual(floating.inset.top, 5)
    XCTAssertEqual(floating.inset.bottom, 10)
  }

  func testBannerPaddingUsesPinnedFletActionLayout() {
    let single = ControlNode(
      id: 130, type: "Banner", props: ["actions": .array([.controlRef(1)])])
    let singlePadding = OverlayDefaults.bannerContentPadding(single)
    XCTAssertEqual(singlePadding.leading, 16)
    XCTAssertEqual(singlePadding.top, 2)
    XCTAssertEqual(singlePadding.trailing, 0)

    let multi = ControlNode(
      id: 131, type: "Banner",
      props: ["actions": .array([.controlRef(1), .controlRef(2)])])
    let multiPadding = OverlayDefaults.bannerContentPadding(multi)
    XCTAssertEqual(multiPadding.leading, 16)
    XCTAssertEqual(multiPadding.top, 24)
    XCTAssertEqual(multiPadding.trailing, 16)
    XCTAssertEqual(multiPadding.bottom, 4)
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

  func testCupertinoPresentationDefaultsMatchPinnedFlutterConstructors() {
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionSheetEdgePadding, 8)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionSheetCancelPadding, 8)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionSheetContentHorizontalPadding, 16)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionSheetContentVerticalPadding, 13.5)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionSheetActionMinimumHeight, 57.17)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionSheetCornerRadius, 12)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.contextMenuActionMinimumHeight, 43)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.contextMenuActionPadding.top, 8)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.contextMenuActionPadding.leading, 15.5)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.contextMenuActionPadding.trailing, 17.5)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.alertInsetDurationMilliseconds, 100)
    XCTAssertEqual(RufletCupertinoPresentationDefaults.bottomSheetPickerHeight, 220)
  }

  func testCupertinoContextMenuRequiresContentAndAtLeastOneAction() {
    let missingContent = ControlNode(
      id: 140, type: "CupertinoContextMenu",
      props: ["actions": .array([.controlRef(2)])])
    let missingActions = ControlNode(
      id: 141, type: "CupertinoContextMenu",
      props: ["content": .controlRef(1)])
    let complete = ControlNode(
      id: 142, type: "CupertinoContextMenu",
      props: [
        "content": .controlRef(1),
        "actions": .array([.controlRef(2), .controlRef(3)]),
      ])

    XCTAssertFalse(RufletCupertinoPresentationDefaults.isValidContextMenu(missingContent))
    XCTAssertFalse(RufletCupertinoPresentationDefaults.isValidContextMenu(missingActions))
    XCTAssertTrue(RufletCupertinoPresentationDefaults.isValidContextMenu(complete))
    XCTAssertEqual(RufletCupertinoPresentationDefaults.actionIDs(complete), [2, 3])
  }

  func testCupertinoAlertValidationAndActionFlagsUseFletWireNames() {
    XCTAssertFalse(RufletCupertinoPresentationDefaults.hasAlertContent(
      ControlNode(id: 150, type: "CupertinoAlertDialog")))
    XCTAssertTrue(RufletCupertinoPresentationDefaults.hasAlertContent(ControlNode(
      id: 151, type: "CupertinoAlertDialog",
      props: ["actions": .array([.controlRef(2)])])))
    XCTAssertTrue(RufletCupertinoPresentationDefaults.hasAlertContent(ControlNode(
      id: 154, type: "CupertinoAlertDialog",
      props: ["title": .string("Plain string title")])))

    let action = ControlNode(
      id: 152, type: "CupertinoDialogAction",
      props: ["default": .bool(true), "destructive": .bool(true)])
    XCTAssertTrue(RufletCupertinoPresentationDefaults.isDefaultAction(action))
    XCTAssertTrue(RufletCupertinoPresentationDefaults.isDestructiveAction(action))

    // The old Android-style aliases are not part of Flet's Cupertino wire API.
    let aliases = ControlNode(
      id: 153, type: "CupertinoDialogAction",
      props: ["is_default_action": .bool(true), "is_destructive_action": .bool(true)])
    XCTAssertFalse(RufletCupertinoPresentationDefaults.isDefaultAction(aliases))
    XCTAssertFalse(RufletCupertinoPresentationDefaults.isDestructiveAction(aliases))
  }

  func testCupertinoOverlayDescriptorsExposeOnlySourceEventsAndNoMaterialCommands() {
    XCTAssertEqual(events("CupertinoAlertDialog"), ["dismiss", "visible"])
    XCTAssertEqual(events("CupertinoBottomSheet"), ["dismiss", "visible"])
    XCTAssertEqual(events("CupertinoActionSheetAction"), ["click"])
    XCTAssertEqual(events("CupertinoContextMenuAction"), ["click"])
    XCTAssertEqual(methods("CupertinoContextMenu"), [])
  }

  private func events(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedEvents ?? []
  }

  private func methods(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedMethods ?? []
  }
}
