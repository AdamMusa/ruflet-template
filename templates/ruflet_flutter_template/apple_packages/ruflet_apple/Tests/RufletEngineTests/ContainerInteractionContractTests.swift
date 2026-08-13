import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class ContainerInteractionContractTests: XCTestCase {
  func testInertContainerInstallsNoInteractionContract() {
    let control = makeContainer([:])

    let contract = RufletContainerInteractionContract(control: control)

    XCTAssertFalse(contract.handlesTap)
    XCTAssertFalse(contract.handlesTapDown)
    XCTAssertFalse(contract.handlesLongPress)
    XCTAssertFalse(contract.handlesHover)
    XCTAssertFalse(contract.isEnabled)
  }

  func testPinnedSubscriptionsEnableOnlyTheirOwnRecognizer() {
    let control = makeContainer([
      "on_tap_down": .bool(true),
      "on_hover": .bool(true),
    ])

    let contract = RufletContainerInteractionContract(control: control)

    XCTAssertFalse(contract.handlesTap)
    XCTAssertTrue(contract.handlesTapDown)
    XCTAssertFalse(contract.handlesLongPress)
    XCTAssertTrue(contract.handlesHover)
    XCTAssertTrue(contract.isEnabled)
  }

  func testURLCountsAsTapAndDisabledSuppressesWrapper() {
    let enabled = RufletContainerInteractionContract(
      control: makeContainer(["url": .string("https://ruflet.dev")]))
    XCTAssertTrue(enabled.handlesTap)
    XCTAssertTrue(enabled.isEnabled)

    let disabled = RufletContainerInteractionContract(
      control: makeContainer([
        "disabled": .bool(true),
        "url": .string("https://ruflet.dev"),
        "on_click": .bool(true),
      ]))
    XCTAssertTrue(disabled.handlesTap)
    XCTAssertFalse(disabled.isEnabled)
  }

  func testPinnedContainerPresentationConsumesNativeDecorationContract() {
    let backend = ContainerInteractionTestBackend()
    let control = RufletControl(
      id: 101, type: "Container",
      properties: [
        "blend_mode": .string("multiply"),
        "blur": ["sigma_x": .double(4), "sigma_y": .double(8)],
        "clip_behavior": .string("antiAlias"),
        "color_filter": ["color": .string("#FF336699"), "blend_mode": .string("screen")],
        "foreground_decoration": [
          "bgcolor": .string("#22000000"),
          "border_radius": .double(12),
        ],
        "image": [
          "src": .binary(Data([0x89, 0x50, 0x4E, 0x47])),
          "fit": .string("cover"),
        ],
        "ink": .bool(true),
        "ink_color": .string("#44112233"),
        "shadow": .array([
          .map([
            "blur_radius": .double(3),
            "spread_radius": .double(2),
            "offset": ["x": .double(1), "y": .double(2)],
          ]),
          .map(["blur_radius": .double(6)]),
        ]),
      ], backend: backend)

    let presentation = RufletContainerPresentation(control: control, radius: .zero)

    XCTAssertEqual(presentation.clipBehavior, "antialias")
    XCTAssertEqual(presentation.blur, RufletContainerBlur(["sigma_x": 4, "sigma_y": 8]))
    XCTAssertNotNil(presentation.colorFilter)
    XCTAssertNotNil(presentation.background?.image)
    XCTAssertNotNil(presentation.foreground)
    XCTAssertTrue(presentation.ink)
    XCTAssertEqual(presentation.shadows.count, 2)
    XCTAssertEqual(presentation.shadows[0].spread, 2)
  }

  func testPinnedClipDefaultFollowsParsedBorderRadius() {
    let backend = ContainerInteractionTestBackend()
    let plainControl = RufletControl(id: 102, type: "Container", properties: [:], backend: backend)
    let plain = RufletContainerPresentation(control: plainControl, radius: .zero)
    XCTAssertEqual(plain.clipBehavior, "none")

    let roundedControl = RufletControl(
      id: 103,
      type: "Container",
      properties: ["border_radius": .double(10)],
      backend: backend)
    let rounded = RufletContainerPresentation(
      control: roundedControl,
      radius: parseBorderRadius(roundedControl.dynamicValue("border_radius"), .zero)!)
    XCTAssertEqual(rounded.clipBehavior, "antialias")
  }

  private func makeContainer(_ properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 100,
      type: "Container",
      properties: properties,
      backend: ContainerInteractionTestBackend())
  }
}

@MainActor
private final class ContainerInteractionTestBackend: RufletBackendProtocol {
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
