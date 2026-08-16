import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class ButtonPropertyConsumptionTests: XCTestCase {
  func testEveryMaterialButtonVariantDefaultsToNoClip() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let style = style(for: type, properties: [:])
      XCTAssertEqual(style.clipBehavior, "none", type)
      XCTAssertFalse(style.clipsContent, type)
      XCTAssertFalse(style.antialiasedClip, type)
    }
  }

  func testSharedStylePreservesHardEdgeAndAntialiasModes() {
    let hardEdge = style(for: "Button", properties: ["clip_behavior": .string("hardEdge")])
    XCTAssertTrue(hardEdge.clipsContent)
    XCTAssertFalse(hardEdge.antialiasedClip)

    let antialias = style(
      for: "FilledButton",
      properties: ["clip_behavior": .string("antiAliasWithSaveLayer")])
    XCTAssertTrue(antialias.clipsContent)
    XCTAssertTrue(antialias.antialiasedClip)
  }

  func testMaterialButtonDefaultPaddingMatchesFlutterVariants() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton"] {
      let padding = style(for: type, properties: [:]).padding.resolve([])
      XCTAssertEqual(padding?.leading, 24, type)
      XCTAssertEqual(padding?.trailing, 24, type)
      XCTAssertEqual(padding?.top, 8, type)
      XCTAssertEqual(padding?.bottom, 8, type)
    }

    let textPadding = style(for: "TextButton", properties: [:]).padding.resolve([])
    XCTAssertEqual(textPadding?.leading, 12)
    XCTAssertEqual(textPadding?.trailing, 12)
  }

  func testMaterialButtonConsumesStatefulPaddingAndSizeConstraints() {
    let buttonStyle = style(
      for: "FilledButton",
      properties: [
        "style": .map([
          "padding": .map([
            "default": .double(10),
            "hovered": .map([
              "top": .double(2), "right": .double(4),
              "bottom": .double(6), "left": .double(8),
            ]),
          ]),
          "minimum_size": .map(["width": .double(64), "height": .double(40)]),
          "maximum_size": .map(["width": .double(180), "height": .double(56)]),
          "fixed_size": .map(["width": .double(120), "height": .double(44)]),
        ]),
      ])

    let normal = buttonStyle.padding.resolve([])
    XCTAssertEqual(normal?.leading, 10)
    XCTAssertEqual(normal?.top, 10)
    let hovered = buttonStyle.padding.resolve([.hovered])
    XCTAssertEqual(hovered?.top, 2)
    XCTAssertEqual(hovered?.trailing, 4)
    XCTAssertEqual(hovered?.bottom, 6)
    XCTAssertEqual(hovered?.leading, 8)
    XCTAssertEqual(buttonStyle.minimumSize.resolve([]), CGSize(width: 64, height: 40))
    XCTAssertEqual(buttonStyle.maximumSize.resolve([]), CGSize(width: 180, height: 56))
    XCTAssertEqual(buttonStyle.fixedSize.resolve([]), CGSize(width: 120, height: 44))
  }

  func testEveryMaterialButtonConsumesDirectBackgroundColor() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton"] {
      let buttonStyle = style(
        for: type,
        properties: ["bgcolor": .string("#2563eb")])

      XCTAssertTrue(buttonStyle.hasExplicitBackground, type)
    }
  }

  func testUnconfiguredMaterialButtonHasNoExplicitBackground() {
    XCTAssertFalse(style(for: "Button", properties: [:]).hasExplicitBackground)
  }

  func testOnlyDefaultContainerButtonsAreEligibleForIOSGlass() {
    for type in ["Button", "FilledButton", "FilledTonalButton", "OutlinedButton"] {
      XCTAssertTrue(style(for: type, properties: [:]).usesNativeGlassSurface, type)
      XCTAssertFalse(
        style(for: type, properties: ["bgcolor": .string("#2563eb")])
          .usesNativeGlassSurface,
        type)
    }
    XCTAssertFalse(style(for: "TextButton", properties: [:]).usesNativeGlassSurface)
  }

  func testLongPressRecognizerExistsOnlyForAnEnabledSubscription() {
    let backend = ButtonPropertyTestBackend()
    let ordinary = RufletControl(
      id: 1, type: "Button", properties: ["on_click": true], backend: backend)
    let subscribed = RufletControl(
      id: 2, type: "Button",
      properties: ["on_click": true, "on_long_press": true], backend: backend)
    let disabled = RufletControl(
      id: 3, type: "Button",
      properties: ["disabled": true, "on_long_press": true], backend: backend)

    XCTAssertFalse(rufletButtonLongPressEnabled(ordinary))
    XCTAssertTrue(rufletButtonLongPressEnabled(subscribed))
    XCTAssertFalse(rufletButtonLongPressEnabled(disabled))
  }

  private func style(
    for type: String,
    properties: [String: RufletValue]
  ) -> RufletAppleButtonStyle {
    let control = RufletControl(
      id: 1,
      type: type,
      properties: properties,
      backend: ButtonPropertyTestBackend())
    return ButtonControl(control: control).buttonStyle
  }
}

@MainActor
private final class ButtonPropertyTestBackend: RufletBackendProtocol {
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
