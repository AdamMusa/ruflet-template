import RufletEngine
import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

@MainActor
final class IconPropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedVariableFontAndCompositingFields() {
    let control = makeControl(properties: [
      "size": .double(32),
      "apply_text_scaling": .bool(true),
      "fill": .double(0.5),
      "grade": .double(100),
      "weight": .double(400),
      "optical_size": .double(24),
      "blend_mode": .string("src_in"),
      "shadows": .array([
        .map([
          "color": .string("#80112233"),
          "blur_radius": .double(2),
          "offset": .map(["x": .double(3), "y": .double(4)]),
        ])
      ]),
    ])

    let presentation = RufletIconPresentation(control: control)
    XCTAssertEqual(presentation.size, 32)
    XCTAssertTrue(presentation.applyTextScaling)
    XCTAssertEqual(presentation.fill, 0.5)
    XCTAssertEqual(presentation.weight, .regular)
    XCTAssertEqual(presentation.opticalSize, 24)
    XCTAssertEqual(presentation.blendMode, .sourceAtop)
    XCTAssertEqual(presentation.shadows.count, 1)
    XCTAssertEqual(presentation.shadows[0].radius, 2)
    XCTAssertEqual(presentation.shadows[0].x, 3)
    XCTAssertEqual(presentation.shadows[0].y, 4)
  }

  func testGradeAdjustsNativeWeightWithoutInventingAnIconSize() {
    XCTAssertEqual(RufletIconPresentation.fontWeight(weight: 400, grade: -200), .thin)
    XCTAssertEqual(RufletIconPresentation.fontWeight(weight: 400, grade: 200), .semibold)

    let defaults = RufletIconPresentation(control: makeControl(properties: [:]))
    XCTAssertEqual(defaults.size, 24)
    XCTAssertFalse(defaults.applyTextScaling)
    XCTAssertNil(defaults.fill)
    XCTAssertNil(defaults.opticalSize)
    XCTAssertEqual(defaults.blendMode, .normal)
    XCTAssertTrue(defaults.shadows.isEmpty)
  }

  func testBlendModeNamesAcceptPinnedSnakeCaseValues() {
    XCTAssertEqual(RufletIconPresentation.blendMode("src_in"), .sourceAtop)
    XCTAssertEqual(RufletIconPresentation.blendMode("color_dodge"), .colorDodge)
    XCTAssertEqual(RufletIconPresentation.blendMode("hard_light"), .hardLight)
    XCTAssertEqual(RufletIconPresentation.blendMode("plus"), .plusLighter)
    XCTAssertEqual(RufletIconPresentation.blendMode(nil), .normal)
  }

  private func makeControl(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "Icon",
      properties: properties,
      backend: IconPropertyTestBackend())
  }
}

@MainActor
private final class IconPropertyTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
