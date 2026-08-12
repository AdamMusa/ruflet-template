import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class AppBarBottomAppBarParityTests: XCTestCase {
  func testAppBarPreservesPinnedFletAndForcedToolbarDefaults() {
    let values = ChromeDefaults.appBar(ControlNode(id: 1, type: "AppBar"))
    XCTAssertEqual(values.toolbarHeight, 56)
    XCTAssertEqual(values.toolbarOpacity, 1)
    XCTAssertEqual(values.titleSpacing, 16)
    XCTAssertEqual(values.leadingWidth, 56)
    XCTAssertEqual(values.elevation, 0)
    XCTAssertEqual(values.scrolledUnderElevation, 3)
    XCTAssertFalse(values.excludeHeaderSemantics)
    XCTAssertFalse(values.forceMaterialTransparency)
    XCTAssertTrue(values.primary)

    let secondary = ChromeDefaults.appBar(
      ControlNode(
        id: 2, type: "AppBar", props: ["secondary": .bool(true)]))
    XCTAssertFalse(secondary.primary)
  }

  func testAppBarImpliedSlotsFollowFlutterScaffoldPrecedence() {
    let plain = ControlNode(id: 1, type: "AppBar")
    XCTAssertEqual(
      ChromeDefaults.appBarSlots(
        plain, canPop: true, hasDrawer: true, hasEndDrawer: true),
      .init(leading: .drawer, actions: .endDrawer))
    XCTAssertEqual(
      ChromeDefaults.appBarSlots(
        plain, canPop: true, hasDrawer: false, hasEndDrawer: false
      ).leading,
      .back)

    let disabled = ControlNode(
      id: 2, type: "AppBar", props: ["automatically_imply_leading": .bool(false)])
    XCTAssertEqual(
      ChromeDefaults.appBarSlots(
        disabled, canPop: true, hasDrawer: true, hasEndDrawer: false
      ).leading,
      .none)

    let explicit = ControlNode(
      id: 3, type: "AppBar",
      props: [
        "leading": .controlRef(10),
        "actions": .array([.controlRef(11), .controlRef(12)]),
      ])
    XCTAssertEqual(
      ChromeDefaults.appBarSlots(
        explicit, canPop: true, hasDrawer: true, hasEndDrawer: true),
      .init(leading: .explicit, actions: .explicit))
  }

  func testAppBarScrolledSurfaceOnlyChangesForOmittedColor() {
    let omitted = ControlNode(id: 1, type: "AppBar")
    XCTAssertEqual(ChromeDefaults.appBarBackgroundToken(omitted, scrolledUnder: false), "surface")
    XCTAssertEqual(
      ChromeDefaults.appBarBackgroundToken(omitted, scrolledUnder: true), "surfacecontainer")

    let explicit = ControlNode(id: 2, type: "AppBar", props: ["bgcolor": .string("red")])
    XCTAssertEqual(ChromeDefaults.appBarBackgroundToken(explicit, scrolledUnder: true), "red")

    let transparent = ControlNode(
      id: 3, type: "AppBar", props: ["force_material_transparency": .bool(true)])
    XCTAssertNil(ChromeDefaults.appBarBackgroundToken(transparent, scrolledUnder: true))
  }

  func testBottomAppBarThemeShapeDoesNotInventAGuestCutout() {
    let themeDefault = ChromeDefaults.bottomAppBarNotch(
      ControlNode(id: 1, type: "BottomAppBar"))
    XCTAssertEqual(themeDefault.kind, .automatic)
    XCTAssertFalse(themeDefault.subtractsGuest)
    XCTAssertEqual(themeDefault.margin, 4)

    let automaticWithoutGuest = ChromeDefaults.bottomAppBarNotch(
      ControlNode(
        id: 2, type: "BottomAppBar",
        props: ["shape": .map(["_type": .string("auto")])]))
    XCTAssertFalse(automaticWithoutGuest.subtractsGuest)

    let automaticWithGuest = ChromeDefaults.bottomAppBarNotch(
      ControlNode(
        id: 3, type: "BottomAppBar",
        props: [
          "shape": .map([
            "_type": .string("auto"),
            "host": .map(["_type": .string("continuousrectangle")]),
            "guest": .map(["_type": .string("circle")]),
          ])
        ]))
    XCTAssertTrue(automaticWithGuest.subtractsGuest)
    XCTAssertNotNil(automaticWithGuest.hostShape)
    XCTAssertNotNil(automaticWithGuest.guestShape)

    let circular = ChromeDefaults.bottomAppBarNotch(
      ControlNode(
        id: 4, type: "BottomAppBar",
        props: [
          "shape": .map([
            "_type": .string("circular"), "inverted": .bool(true),
          ])
        ]))
    XCTAssertTrue(circular.subtractsGuest)
    XCTAssertTrue(circular.inverted)
  }

  func testBottomAppBarUsesNativeAppleSurfaceOnlyForOmittedAppearance() {
    XCTAssertTrue(ChromeDefaults.usesNativeBottomAppBarSurface(
      ControlNode(id: 1, type: "BottomAppBar")))
    for (index, key) in ["bgcolor", "shadow_color", "shape", "border_radius"].enumerated() {
      XCTAssertFalse(ChromeDefaults.usesNativeBottomAppBarSurface(ControlNode(
        id: 10 + index, type: "BottomAppBar", props: [key: .string("explicit")])))
    }
  }

  func testViewAndPageletFABLocationsShareScaffoldGeometry() {
    let size = CGSize(width: 56, height: 56)

    let docked = RufletFABPlacement(.string("center_docked"))
    XCTAssertEqual(docked.horizontal, .center)
    XCTAssertEqual(docked.vertical, .docked)
    XCTAssertEqual(
      docked.padding(bottomBarHeight: 80, appBarHeight: 56, fabSize: size).bottom,
      52)

    let contained = RufletFABPlacement(.string("end_contained"))
    XCTAssertEqual(
      contained.padding(bottomBarHeight: 80, appBarHeight: 56, fabSize: size).bottom,
      12)
    XCTAssertEqual(
      contained.padding(bottomBarHeight: 80, appBarHeight: 56, fabSize: size).trailing,
      16)

    let top = RufletFABPlacement(.string("start_top"))
    XCTAssertEqual(top.vertical, .top)
    XCTAssertEqual(
      top.padding(bottomBarHeight: 80, appBarHeight: 56, fabSize: size).top,
      28)

    let custom = RufletFABPlacement(.map(["x": .double(100), "y": .double(120)]))
    let padding = custom.padding(bottomBarHeight: 80, appBarHeight: 56, fabSize: size)
    XCTAssertEqual(custom.vertical, .custom)
    XCTAssertEqual(padding.trailing, 44)
    XCTAssertEqual(padding.bottom, 64)

    let mini = RufletFABPlacement(.string("mini_end_float"))
    let miniPadding = mini.padding(
      bottomBarHeight: 80, appBarHeight: 56, fabSize: CGSize(width: 40, height: 40))
    XCTAssertTrue(mini.mini)
    XCTAssertEqual(miniPadding.trailing, 12)
    XCTAssertEqual(miniPadding.bottom, 92)
  }
}
