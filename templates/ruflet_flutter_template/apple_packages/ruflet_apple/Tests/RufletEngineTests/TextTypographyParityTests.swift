import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class TextTypographyParityTests: XCTestCase {
  func testMaterialThreeTextThemeMetricsRemainDistinct() {
    let expected: [(String, CGFloat, CGFloat)] = [
      ("display_large", 57, 64), ("display_medium", 45, 52),
      ("display_small", 36, 44), ("headline_large", 32, 40),
      ("headline_medium", 28, 36), ("headline_small", 24, 32),
      ("title_large", 22, 28), ("title_medium", 16, 24),
      ("title_small", 14, 20), ("body_large", 16, 24),
      ("body_medium", 14, 20), ("body_small", 12, 16),
      ("label_large", 14, 20), ("label_medium", 12, 16),
      ("label_small", 11, 16),
    ]
    for (name, size, height) in expected {
      let metric = RufletTextStyle.materialMetric(name)
      XCTAssertEqual(metric?.size, size, name)
      XCTAssertEqual(metric?.lineHeight, height, name)
    }
  }

  func testTextThemeUsesExactSemanticLineSpacing() {
    let display = RufletTextStyle.forText(node: ControlNode(
      id: 1, type: "Text", props: ["theme_style": .string("display_large")]))
    XCTAssertEqual(display.materialThemeMetric?.size, 57)
    XCTAssertEqual(display.swiftUILineSpacing, 7)

    let body = RufletTextStyle.forText(node: ControlNode(
      id: 2, type: "Text", props: ["theme_style": .string("body_medium")]))
    XCTAssertEqual(body.materialThemeMetric?.size, 14)
    XCTAssertEqual(body.swiftUILineSpacing, 6)
  }

  func testExplicitSizeAndHeightOverrideThemeMetricsLikeFletMerge() {
    let style = RufletTextStyle.forText(node: ControlNode(
      id: 1, type: "Text",
      props: [
        "theme_style": .string("display_large"),
        "size": .double(20),
        "style": .map(["height": .double(1.5)]),
      ]))
    XCTAssertEqual(style.size, 20)
    XCTAssertEqual(style.lineHeight, 1.5)
    XCTAssertEqual(style.swiftUILineSpacing, 10)
  }

  func testUnknownThemeRoleDoesNotInventTypography() {
    XCTAssertNil(RufletTextStyle.materialMetric("not_a_flet_role"))
  }
}
