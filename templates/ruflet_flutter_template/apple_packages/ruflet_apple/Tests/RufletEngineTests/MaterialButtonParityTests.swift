import XCTest
@testable import RufletEngine
@testable import RufletUI

final class MaterialButtonParityTests: XCTestCase {
  func testButtonVariantsUsePinnedFletStyleDefaults() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "color"), "primary")
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "bgcolor"), "surface")
      XCTAssertEqual(RufletThemeDefaults.resolvedColorToken(for: node, property: "overlay_color"), "primary,0.08")
    }
  }

  func testIconButtonVariantPalettesMatchMaterial3States() {
    XCTAssertEqual(
      IconButtonPresentation.palette(for: ControlNode(id: 1, type: "FilledIconButton")),
      .init(background: "primary", foreground: "onprimary", outline: nil))
    XCTAssertEqual(
      IconButtonPresentation.palette(for: ControlNode(
        id: 2, type: "OutlinedIconButton", props: ["selected": .bool(true)])),
      .init(background: "inversesurface", foreground: "oninversesurface", outline: nil))
  }

  func testFloatingActionGeometryUsesFlutterConstructorDefaults() {
    let normal = FloatingActionPresentation(node: ControlNode(id: 1, type: "FloatingActionButton"))
    let mini = FloatingActionPresentation(node: ControlNode(
      id: 2, type: "FloatingActionButton", props: ["mini": .bool(true)]))
    XCTAssertEqual(normal.side, 56)
    XCTAssertEqual(normal.radius, 16)
    XCTAssertEqual(mini.side, 40)
    XCTAssertEqual(mini.radius, 12)
  }

  func testChipResolvesRufletAndFletDeleteTooltipNames() {
    XCTAssertEqual(
      ChipPresentation.deleteTooltip(ControlNode(
        id: 1,
        type: "Chip",
        props: ["delete_icon_tooltip": .string("Remove")]
      )),
      "Remove"
    )
    XCTAssertEqual(
      ChipPresentation.deleteTooltip(ControlNode(
        id: 2,
        type: "Chip",
        props: ["delete_button_tooltip": .string("Delete")]
      )),
      "Delete"
    )
  }
}
