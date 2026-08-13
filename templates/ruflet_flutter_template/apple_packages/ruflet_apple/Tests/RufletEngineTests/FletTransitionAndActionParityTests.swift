import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class FletTransitionAndActionParityTests: XCTestCase {
  func testHeroConsumesPinnedInteractiveGestureFlag() {
    let backend = TransitionActionBackend()
    let enabled = RufletControl(
      id: 1, type: "Hero",
      properties: ["transition_on_user_gestures": .bool(true)], backend: backend)
    let defaulted = RufletControl(id: 2, type: "Hero", properties: [:], backend: backend)

    XCTAssertTrue(HeroControl(control: enabled).transitionOnUserGestures)
    XCTAssertFalse(HeroControl(control: defaulted).transitionOnUserGestures)
    XCTAssertTrue(
      rufletHeroParticipatesInTransition(
        transitionOnUserGestures: false,
        isInteractiveNavigation: false))
    XCTAssertFalse(
      rufletHeroParticipatesInTransition(
        transitionOnUserGestures: false,
        isInteractiveNavigation: true))
    XCTAssertTrue(
      rufletHeroParticipatesInTransition(
        transitionOnUserGestures: true,
        isInteractiveNavigation: true))
  }

  func testCupertinoActionConsumesPinnedMouseCursor() {
    let backend = TransitionActionBackend()
    let control = RufletControl(
      id: 3, type: "CupertinoActionSheetAction",
      properties: ["mouse_cursor": .string("click")], backend: backend)

    XCTAssertEqual(CupertinoActionSheetActionControl(control: control).mouseCursor, "click")
  }
}

@MainActor
private final class TransitionActionBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int, properties: [String: RufletValue], client: Bool, server: Bool, notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
