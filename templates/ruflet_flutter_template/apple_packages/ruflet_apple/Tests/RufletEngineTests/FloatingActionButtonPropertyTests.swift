import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class FloatingActionButtonPropertyTests: XCTestCase {
  private let backend = FloatingActionButtonTestBackend()

  func testElevationPrecedenceMatchesPinnedInteractionStates() {
    let control = RufletControl(
      id: 81,
      type: "FloatingActionButton",
      properties: [
        "elevation": 2,
        "disabled_elevation": 3,
        "focus_elevation": 4,
        "hover_elevation": 5,
        "highlight_elevation": 6,
      ],
      backend: backend)
    let presentation = RufletFloatingActionButtonPresentation(control: control)

    XCTAssertEqual(presentation.elevation(for: state()), 2)
    XCTAssertEqual(presentation.elevation(for: state(focused: true)), 4)
    XCTAssertEqual(presentation.elevation(for: state(hovered: true)), 5)
    XCTAssertEqual(presentation.elevation(for: state(pressed: true)), 6)
    XCTAssertEqual(
      presentation.elevation(
        for: state(focused: true, hovered: true, pressed: true, disabled: true)),
      3)
  }

  func testExplicitInteractionColorsOverrideNativeDefaults() {
    let control = RufletControl(
      id: 82,
      type: "FloatingActionButton",
      properties: [
        "splash_color": "#ff0000",
        "hover_color": "#00ff00",
        "focus_color": "#0000ff",
      ],
      backend: backend)
    let presentation = RufletFloatingActionButtonPresentation(control: control)

    XCTAssertNotNil(presentation.splashColor)
    XCTAssertNotNil(presentation.hoverColor)
    XCTAssertNotNil(presentation.focusColor)
  }

  private func state(
    focused: Bool = false,
    hovered: Bool = false,
    pressed: Bool = false,
    disabled: Bool = false
  ) -> RufletFloatingActionButtonState {
    RufletFloatingActionButtonState(
      focused: focused,
      hovered: hovered,
      pressed: pressed,
      disabled: disabled)
  }
}

@MainActor
private final class FloatingActionButtonTestBackend: RufletBackendProtocol {
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
