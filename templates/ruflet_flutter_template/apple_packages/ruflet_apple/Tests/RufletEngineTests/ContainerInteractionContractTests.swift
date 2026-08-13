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
