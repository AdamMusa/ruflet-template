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
}
