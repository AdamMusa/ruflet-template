import XCTest
@testable import RufletUI
import RufletEngine
import RufletProtocol

final class FletThemeDefaultsTests: XCTestCase {
  func testMaterialAppBarUsesFlutterToolbarHeightOnApple() {
    XCTAssertEqual(FletThemeDefaults.appBarHeight(ControlNode(id: 1, type: "AppBar")), 56)
  }

  func testViewUsesFletConstructorPaddingWhenOmitted() {
    XCTAssertEqual(FletThemeDefaults.viewPadding.top, 10)
    XCTAssertEqual(FletThemeDefaults.viewPadding.leading, 10)
    XCTAssertEqual(FletThemeDefaults.viewPadding.bottom, 10)
    XCTAssertEqual(FletThemeDefaults.viewPadding.trailing, 10)
  }

  func testAppleAppBarCentersOmittedTitleWithFewerThanTwoActions() {
    let noActions = ControlNode(id: 1, type: "AppBar")
    let oneAction = ControlNode(
      id: 1, type: "AppBar",
      props: ["actions": .array([.controlRef(2)])])

    #if os(iOS) || os(macOS)
      XCTAssertTrue(FletThemeDefaults.appBarCentersTitle(noActions))
      XCTAssertTrue(FletThemeDefaults.appBarCentersTitle(oneAction))
    #else
      XCTAssertFalse(FletThemeDefaults.appBarCentersTitle(noActions))
      XCTAssertFalse(FletThemeDefaults.appBarCentersTitle(oneAction))
    #endif
  }

  func testAppleAppBarDoesNotCenterWhenTwoActionsArePresent() {
    let node = ControlNode(
      id: 1, type: "AppBar",
      props: ["actions": .array([.controlRef(2), .controlRef(3)])])
    XCTAssertFalse(FletThemeDefaults.appBarCentersTitle(node))
  }

  func testExplicitCenterTitleOverridesPlatformDefault() {
    let falseNode = ControlNode(
      id: 1, type: "AppBar", props: ["center_title": .bool(false)])
    let trueNode = ControlNode(
      id: 2, type: "AppBar", props: ["center_title": .bool(true)])

    XCTAssertFalse(FletThemeDefaults.appBarCentersTitle(falseNode))
    XCTAssertTrue(FletThemeDefaults.appBarCentersTitle(trueNode))
  }

  func testMaterialButtonOmissionsUsePinnedFletThemeRoles() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertEqual(FletThemeDefaults.resolvedColorToken(for: node, property: "color"), "primary")
      XCTAssertEqual(FletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"), "surface")
    }
    XCTAssertEqual(FletThemeDefaults.materialButtonElevation, 1)
    XCTAssertEqual(FletThemeDefaults.materialButtonPadding.leading, 8)
    XCTAssertEqual(FletThemeDefaults.materialButtonPadding.trailing, 8)
  }

  func testExplicitMaterialButtonColorsOverrideThemeDefaults() {
    let node = ControlNode(
      id: 1, type: "FilledButton",
      props: ["color": .string("#112233"), "bgcolor": .string("red400")])
    XCTAssertEqual(
      FletThemeDefaults.resolvedColorToken(for: node, property: "color"), "#112233")
    XCTAssertEqual(
      FletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"), "red400")
  }

  func testSelectionColorsResolveThroughThemeUnlessExplicit() {
    let omitted = ControlNode(id: 1, type: "Checkbox")
    let explicit = ControlNode(
      id: 2, type: "Checkbox", props: ["active_color": .string("green")])
    XCTAssertEqual(
      FletThemeDefaults.resolvedColorToken(for: omitted, property: "active_color"), "primary")
    XCTAssertEqual(
      FletThemeDefaults.resolvedColorToken(for: omitted, property: "inactive_color"),
      "onsurfacevariant")
    XCTAssertEqual(
      FletThemeDefaults.resolvedColorToken(for: explicit, property: "active_color"), "green")
  }

  func testCupertinoButtonKeepsNativeOmittedPaddingAndFletRadius() {
    let omitted = ControlNode(id: 1, type: "CupertinoButton")
    XCTAssertNil(FletThemeDefaults.cupertinoButtonPadding(omitted))
    XCTAssertEqual(
      FletThemeDefaults.cupertinoButtonRadius(omitted),
      FletThemeDefaults.cupertinoButtonCornerRadius)

    let explicit = ControlNode(
      id: 2, type: "CupertinoButton",
      props: ["padding": .double(12), "border_radius": .double(3)])
    XCTAssertEqual(FletThemeDefaults.cupertinoButtonPadding(explicit)?.top, 12)
    XCTAssertEqual(FletThemeDefaults.cupertinoButtonRadius(explicit), 3)
  }

  func testRangeSliderOmittedAndExplicitValuesMatchFletConstructor() {
    let omitted = FletThemeDefaults.rangeSliderValues(
      ControlNode(id: 1, type: "RangeSlider", props: ["min": .double(-10), "max": .double(10)]))
    XCTAssertEqual(omitted.start, 0)
    XCTAssertEqual(omitted.end, 0)

    let explicit = FletThemeDefaults.rangeSliderValues(
      ControlNode(
        id: 2, type: "RangeSlider",
        props: ["start_value": .double(2), "end_value": .double(7)]))
    XCTAssertEqual(explicit.start, 2)
    XCTAssertEqual(explicit.end, 7)
  }
}
