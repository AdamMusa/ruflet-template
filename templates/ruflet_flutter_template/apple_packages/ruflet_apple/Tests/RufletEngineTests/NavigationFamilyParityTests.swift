import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class NavigationFamilyParityTests: XCTestCase {
  func testNavigationBarUsesPinnedDefaultsAndValidatesFlutterInvariants() {
    let values = ChromeDefaults.navigationBar(ControlNode(id: 1, type: "NavigationBar"))

    XCTAssertEqual(values.height, 80)
    XCTAssertEqual(values.elevation, 3)
    XCTAssertEqual(values.labelPadding.top, 4)
    XCTAssertTrue(values.showsLabel(selected: false))
    XCTAssertEqual(
      ChromeDefaults.navigationBarValidation(destinationCount: 1, selectedIndex: 0),
      "NavigationBar.destinations requires at least two destinations")
    XCTAssertEqual(
      ChromeDefaults.navigationBarValidation(destinationCount: 2, selectedIndex: 2),
      "NavigationBar.selected_index must reference a destination")
    XCTAssertNil(ChromeDefaults.navigationBarValidation(destinationCount: 2, selectedIndex: 1))
    XCTAssertEqual(ControlNode(id: 9, type: "NavigationBarDestination").string("label"), "")
  }

  func testNavigationBarStateColorsMatchPinnedMaterialStates() {
    XCTAssertEqual(
      ChromeDefaults.navigationBarItemPalette(selected: true, disabled: false),
      .init(iconToken: "onsecondarycontainer", labelToken: "onsurface"))
    XCTAssertEqual(
      ChromeDefaults.navigationBarItemPalette(selected: false, disabled: false),
      .init(iconToken: "onsurfacevariant", labelToken: "onsurfacevariant"))
    XCTAssertEqual(
      ChromeDefaults.navigationBarItemPalette(selected: true, disabled: true),
      .init(iconToken: "onsurfacevariant,0.38", labelToken: "onsurfacevariant,0.38"))
  }

  func testStandardDestinationsCanUseNativeAppleTabBarItems() throws {
    let parent = ControlNode(
      id: 1, type: "NavigationBar",
      props: ["label_behavior": .string("only_show_selected")])
    let destinations = [
      ControlNode(id: 2, type: "NavigationBarDestination", props: [
        "icon": .string("home"), "selected_icon": .string("home_filled"),
        "label": .string("Home"),
      ]),
      ControlNode(id: 3, type: "NavigationBarDestination", props: [
        "icon": .string("search"), "label": .string("Search"),
      ]),
    ]
    let items = try XCTUnwrap(ChromeDefaults.nativeNavigationItems(
      destinations, parent: parent, selected: 1, nodeForID: { _ in nil }))
    XCTAssertNil(items[0].title)
    XCTAssertEqual(items[0].symbol, "house")
    XCTAssertEqual(items[0].selectedSymbol, "house.fill")
    XCTAssertEqual(items[1].title, "Search")
    XCTAssertEqual(items[1].symbol, "magnifyingglass")

    let customIcon = ControlNode(id: 9, type: "Container")
    let customDestination = ControlNode(
      id: 4, type: "NavigationBarDestination", props: ["icon": .controlRef(9)])
    XCTAssertNil(ChromeDefaults.nativeNavigationItems(
      [customDestination, destinations[1]], parent: parent, selected: 0,
      nodeForID: { $0 == 9 ? customIcon : nil }))
  }

  func testNavigationRailPreservesNullableSelectionAndGeometryInvariants() {
    let values = ChromeDefaults.navigationRail(ControlNode(id: 2, type: "NavigationRail"))

    XCTAssertEqual(values.minWidth, 80)
    XCTAssertEqual(values.minExtendedWidth, 256)
    XCTAssertEqual(values.groupAlignment, -1)
    XCTAssertTrue(values.useIndicator)
    XCTAssertTrue(values.showsLabel(extended: false, selected: false))
    XCTAssertNil(
      ChromeDefaults.navigationRailValidation(
        destinationCount: 0, selectedIndex: nil, minWidth: 80,
        minExtendedWidth: 256, groupAlignment: -1))
    XCTAssertNotNil(
      ChromeDefaults.navigationRailValidation(
        destinationCount: 1, selectedIndex: 1, minWidth: 80,
        minExtendedWidth: 256, groupAlignment: -1))
    XCTAssertNotNil(
      ChromeDefaults.navigationRailValidation(
        destinationCount: 1, selectedIndex: 0, minWidth: 80,
        minExtendedWidth: 79, groupAlignment: -1))
    XCTAssertNotNil(
      ChromeDefaults.navigationRailValidation(
        destinationCount: 1, selectedIndex: 0, minWidth: 80,
        minExtendedWidth: 256, groupAlignment: 1.1))
  }

  func testNavigationDrawerInvalidSelectionMeansNoDestinationSelected() {
    XCTAssertEqual(ChromeDefaults.validatedDrawerSelection(0, destinationCount: 2), 0)
    XCTAssertEqual(ChromeDefaults.validatedDrawerSelection(1, destinationCount: 2), 1)
    XCTAssertNil(ChromeDefaults.validatedDrawerSelection(-1, destinationCount: 2))
    XCTAssertNil(ChromeDefaults.validatedDrawerSelection(2, destinationCount: 2))
    XCTAssertNil(ChromeDefaults.validatedDrawerSelection(nil, destinationCount: 2))
  }

  func testEveryNavigationOwnerCommitsSelectionBeforeChangeEvent() {
    for type in ["NavigationBar", "NavigationRail", "NavigationDrawer"] {
      let node = ControlNode(
        id: 10, type: type, props: ["on_change": .bool(true)])
      var operations: [String] = []
      let sink = RufletEventSink(
        send: { _, event, value in operations.append("send:\(event):\(value)") },
        setLocal: { _, key, value in operations.append("local:\(key):\(value)") })

      sink.commit(node, key: "selected_index", value: .int(1))

      XCTAssertEqual(
        operations,
        ["local:selected_index:1", "send:change:1"],
        type)
    }
  }

  func testNavigationDescriptorsKeepEventsOnParentsAndChildrenStructural() throws {
    for type in ["NavigationBar", "NavigationRail"] {
      XCTAssertEqual(
        try XCTUnwrap(ControlRegistry.descriptor(for: type)).supportedEvents, ["change"])
    }
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "NavigationDrawer")).supportedEvents,
      ["change", "dismiss"])
    for type in [
      "NavigationBarDestination", "NavigationRailDestination", "NavigationDrawerDestination",
    ] {
      let descriptor = try XCTUnwrap(ControlRegistry.descriptor(for: type))
      XCTAssertEqual(descriptor.classification, .structuralChild)
      XCTAssertTrue(descriptor.supportedEvents.isEmpty)
    }
  }
}
