import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class RufletThemeDefaultsTests: XCTestCase {
  func testMaterialAppBarUsesFlutterToolbarHeightOnApple() {
    XCTAssertEqual(RufletThemeDefaults.appBarHeight(ControlNode(id: 1, type: "AppBar")), 56)
  }

  func testViewUsesFletConstructorPaddingWhenOmitted() {
    XCTAssertEqual(RufletThemeDefaults.viewPadding.top, 10)
    XCTAssertEqual(RufletThemeDefaults.viewPadding.leading, 10)
    XCTAssertEqual(RufletThemeDefaults.viewPadding.bottom, 10)
    XCTAssertEqual(RufletThemeDefaults.viewPadding.trailing, 10)
  }

  func testAppleAppBarCentersOmittedTitleWithFewerThanTwoActions() {
    let noActions = ControlNode(id: 1, type: "AppBar")
    let oneAction = ControlNode(
      id: 1, type: "AppBar",
      props: ["actions": .array([.controlRef(2)])])

    #if os(iOS) || os(macOS)
      XCTAssertTrue(RufletThemeDefaults.appBarCentersTitle(noActions))
      XCTAssertTrue(RufletThemeDefaults.appBarCentersTitle(oneAction))
    #else
      XCTAssertFalse(RufletThemeDefaults.appBarCentersTitle(noActions))
      XCTAssertFalse(RufletThemeDefaults.appBarCentersTitle(oneAction))
    #endif
  }

  func testAppleAppBarDoesNotCenterWhenTwoActionsArePresent() {
    let node = ControlNode(
      id: 1, type: "AppBar",
      props: ["actions": .array([.controlRef(2), .controlRef(3)])])
    XCTAssertFalse(RufletThemeDefaults.appBarCentersTitle(node))
  }

  func testExplicitCenterTitleOverridesPlatformDefault() {
    let falseNode = ControlNode(
      id: 1, type: "AppBar", props: ["center_title": .bool(false)])
    let trueNode = ControlNode(
      id: 2, type: "AppBar", props: ["center_title": .bool(true)])

    XCTAssertFalse(RufletThemeDefaults.appBarCentersTitle(falseNode))
    XCTAssertTrue(RufletThemeDefaults.appBarCentersTitle(trueNode))
  }

  func testMaterialButtonOmissionsUsePinnedFletThemeRoles() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "color"), "primary")
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"), "surface")
    }
    XCTAssertEqual(RufletThemeDefaults.materialButtonElevation, 1)
    XCTAssertEqual(RufletThemeDefaults.materialButtonPadding.leading, 8)
    XCTAssertEqual(RufletThemeDefaults.materialButtonPadding.trailing, 8)
  }

  func testExplicitMaterialButtonColorsOverrideThemeDefaults() {
    let node = ControlNode(
      id: 1, type: "FilledButton",
      props: ["color": .string("#112233"), "bgcolor": .string("red400")])
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: node, property: "color"), "#112233")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"), "red400")
  }

  func testSelectionColorsResolveThroughThemeUnlessExplicit() {
    let omitted = ControlNode(id: 1, type: "Checkbox")
    let explicit = ControlNode(
      id: 2, type: "Checkbox", props: ["active_color": .string("green")])
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "active_color"), "primary")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: omitted, property: "inactive_color"),
      "onsurfacevariant")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedColorToken(for: explicit, property: "active_color"), "green")
  }

  func testCupertinoButtonKeepsNativeOmittedPaddingAndFletRadius() {
    let omitted = ControlNode(id: 1, type: "CupertinoButton")
    XCTAssertNil(RufletThemeDefaults.cupertinoButtonPadding(omitted))
    XCTAssertEqual(
      RufletThemeDefaults.cupertinoButtonRadius(omitted),
      RufletThemeDefaults.cupertinoButtonCornerRadius)

    let explicit = ControlNode(
      id: 2, type: "CupertinoButton",
      props: ["padding": .double(12), "border_radius": .double(3)])
    XCTAssertEqual(RufletThemeDefaults.cupertinoButtonPadding(explicit)?.top, 12)
    XCTAssertEqual(RufletThemeDefaults.cupertinoButtonRadius(explicit), 3)
  }

  func testRangeSliderOmittedAndExplicitValuesMatchFletConstructor() {
    let omitted = RufletThemeDefaults.rangeSliderValues(
      ControlNode(id: 1, type: "RangeSlider", props: ["min": .double(-10), "max": .double(10)]))
    XCTAssertEqual(omitted.start, 0)
    XCTAssertEqual(omitted.end, 0)

    let explicit = RufletThemeDefaults.rangeSliderValues(
      ControlNode(
        id: 2, type: "RangeSlider",
        props: ["start_value": .double(2), "end_value": .double(7)]))
    XCTAssertEqual(explicit.start, 2)
    XCTAssertEqual(explicit.end, 7)
  }
}
