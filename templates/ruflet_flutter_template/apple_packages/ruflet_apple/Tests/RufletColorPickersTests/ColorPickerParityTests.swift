import RufletColorPickers
import RufletEngine
@testable import RufletUI
import XCTest

final class ColorPickerParityTests: XCTestCase {
  func testARGBHexMatchesFletColorToHex() throws {
    let color = try XCTUnwrap(RGBAColor(token: "#8040c0ff"))
    XCTAssertEqual(color.hexARGB, "#8040c0ff")
    XCTAssertEqual(color.hexRGB, "#40c0ff")
  }

  func testSixDigitHexIsOpaque() throws {
    let color = try XCTUnwrap(RGBAColor(token: "#2196f3"))
    XCTAssertEqual(color.hexARGB, "#ff2196f3")
  }

  func testHSVMapMatchesFletEventPayload() throws {
    let color = try XCTUnwrap(RGBAColor(hsv: [
      "alpha": .double(0.5),
      "hue": .double(210.0),
      "saturation": .double(2.0 / 3.0),
      "value": .double(0.75),
    ]))
    let hsv = color.hsva
    XCTAssertEqual(hsv.alpha, 0.5, accuracy: 0.0001)
    XCTAssertEqual(hsv.hue, 210, accuracy: 0.0001)
    XCTAssertEqual(hsv.saturation, 2.0 / 3.0, accuracy: 0.0001)
    XCTAssertEqual(hsv.brightness, 0.75, accuracy: 0.0001)
    XCTAssertEqual(hsv.mapValue["value"]?.doubleValue, 0.75)
  }

  func testHSLRoundTripPreservesHueSaturationAndLightness() {
    let color = RGBAColor(hue: 210, saturation: 0.6, lightness: 0.4, alpha: 0.75)
    XCTAssertEqual(color.hsla.hue, 210, accuracy: 0.0001)
    XCTAssertEqual(color.hsla.saturation, 0.6, accuracy: 0.0001)
    XCTAssertEqual(color.hsla.lightness, 0.4, accuracy: 0.0001)
    XCTAssertEqual(color.alpha, 0.75, accuracy: 0.0001)
  }

  func testNamedMaterialColorsUseTheSharedFletPalette() throws {
    let color = try XCTUnwrap(RGBAColor(token: "blue"))
    XCTAssertEqual(color.hexARGB, "#ff2196f3")
  }

  func testManifestAndCoreFallbackDeclareOptionalPackageBoundary() throws {
    let package = try XCTUnwrap(
      RufletExtensionManifest.packages.first { $0.fletPackage == "flet_color_pickers" })
    XCTAssertEqual(package.swiftProduct, "RufletColorPickers")
    XCTAssertEqual(package.status, .available)

    for type in ["ColorPicker", "HueRingPicker", "SlidePicker", "MaterialPicker",
                 "BlockPicker", "MultipleChoiceBlockPicker"] {
      XCTAssertEqual(
        ControlRegistry.builtInDescriptor(for: type)?.rendering,
        .optionalBundle("RufletColorPickers"))
    }
  }

  @MainActor
  func testExtensionRegistersEveryVendoredWireTypeAndExactEvents() {
    let registry = ServiceRegistry()
    registry.register(extension: RufletColorPickers.self)
    XCTAssertTrue(registry.hasExtension("RufletColorPickers"))
    XCTAssertFalse(registry.handles("ColorPicker"), "Color pickers are visual, not services")

    let expected: [String: Set<String>] = [
      "ColorPicker": ["color_change", "hsv_color_change", "history_change"],
      "HueRingPicker": ["color_change"],
      "SlidePicker": ["color_change"],
      "MaterialPicker": ["color_change", "primary_change"],
      "BlockPicker": ["color_change"],
      "MultipleChoiceBlockPicker": ["colors_change"],
    ]

    for (wireType, events) in expected {
      let descriptor = ControlRegistry.descriptor(for: wireType)
      XCTAssertEqual(descriptor?.implementation,
                     "RufletColorPickers.RufletColorPickerControlView")
      XCTAssertEqual(descriptor?.supportedEvents, events)
      XCTAssertEqual(descriptor?.rendering, .nativeView)
    }
  }
}
