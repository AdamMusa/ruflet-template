@testable import RufletColorPickers
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

  func testLabelParsingFiltersUnknownValuesLikePinnedDartEnums() {
    XCTAssertEqual(
      ColorPickerSemantics.labelTypes(nil, defaults: ["rgb", "hsv", "hsl"]),
      ["rgb", "hsv", "hsl"])
    XCTAssertEqual(
      ColorPickerSemantics.labelTypes(
        [.string("HEX"), .string("unknown"), .int(7), .string("hSl")], defaults: []),
      ["hex", "hsl"])
    XCTAssertEqual(ColorPickerSemantics.labelTypes([], defaults: ["rgb"]), [])
  }

  func testNodeSynchronizationUsesBlackFallbackAndHsvPrecedence() {
    XCTAssertEqual(
      ColorPickerSemantics.synchronizedColor(ControlNode(id: 1, type: "SlidePicker")),
      .black)
    XCTAssertEqual(
      ColorPickerSemantics.synchronizedColor(ControlNode(
        id: 2, type: "ColorPicker", props: [
          "color": .string("red"),
          "hsv_color": .map([
            "alpha": .double(1), "hue": .double(120),
            "saturation": .double(1), "value": .double(1),
          ]),
        ])),
      RGBAColor(red: 0, green: 1, blue: 0))
  }

  func testMultipleChoiceRetainsLocalSelectionForAbsentOrEmptyWireList() throws {
    let blue = try XCTUnwrap(RGBAColor(token: "blue"))
    XCTAssertEqual(
      ColorPickerSemantics.synchronizedSelections(nil, current: [blue]), [blue])
    XCTAssertEqual(
      ColorPickerSemantics.synchronizedSelections([], current: [blue]), [blue])
    XCTAssertEqual(
      ColorPickerSemantics.synchronizedSelections([], current: []), [.black])
  }

  func testMaterialPrimaryListIncludesPinnedBlackEntry() {
    XCTAssertEqual(ColorPickerDefaults.materialPrimaries.count, 20)
    XCTAssertEqual(ColorPickerDefaults.materialPrimaries.last, .black)
    XCTAssertEqual(RGBAColor.black.materialShades, [.black, .white])
  }

  func testPaletteModesMutateTheSameTwoChannelsAsFlutterColorPicker() {
    let current = RGBAColor(hue: 210, saturation: 0.4, brightness: 0.8, alpha: 0.5)

    let hsvValue = ColorSpectrum.adjustedColor(
      mode: .hsvWithValue, current: current, horizontal: 0.25, vertical: 0.6)
    XCTAssertEqual(hsvValue.hsva.hue, 90, accuracy: 0.0001)
    XCTAssertEqual(hsvValue.hsva.saturation, 0.6, accuracy: 0.0001)
    XCTAssertEqual(hsvValue.hsva.brightness, 0.8, accuracy: 0.0001)

    let rgbRed = ColorSpectrum.adjustedColor(
      mode: .rgbWithRed, current: current, horizontal: 0.2, vertical: 0.7)
    XCTAssertEqual(rgbRed.red, current.red, accuracy: 0.0001)
    XCTAssertEqual(rgbRed.green, 0.7, accuracy: 0.0001)
    XCTAssertEqual(rgbRed.blue, 0.2, accuracy: 0.0001)
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
