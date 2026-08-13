import RufletProtocol
import XCTest
@testable import RufletEngine

@MainActor
final class GestureDetectorControlTests: XCTestCase {
  func testInteractionRequiresPinnedEventOrValidCursor() {
    let backend = GestureDetectorTestBackend()
    let empty = coordinator(properties: [:], backend: backend)
    let uncommonEvent = coordinator(
      properties: ["on_tertiary_long_press_move_update": true], backend: backend)
    let diagonalCursor = coordinator(
      properties: ["mouse_cursor": "resizeUpLeftDownRight"], backend: backend)
    let unknownCursor = coordinator(
      properties: ["mouse_cursor": "material_pointer"], backend: backend)

    XCTAssertFalse(empty.hasInteraction)
    XCTAssertTrue(uncommonEvent.hasInteraction)
    XCTAssertTrue(diagonalCursor.hasInteraction)
    XCTAssertFalse(unknownCursor.hasInteraction)
  }

  func testAllowedDevicesGatePrimarySecondaryAndTertiaryRecognizers() {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "allowed_devices": ["touch"],
        "on_tap": true,
        "on_secondary_tap": true,
        "on_tertiary_tap_up": true,
      ], backend: backend)
    let mouse = sample(local: (1, 2), global: (10, 20), kind: "mouse")

    for button in [
      RufletGesturePointerButton.primary, .secondary, .tertiary,
    ] {
      coordinator.pointerDown(mouse, button: button)
      coordinator.pointerUp(mouse, button: button)
    }
    XCTAssertTrue(backend.events.isEmpty)

    let touch = sample(local: (1, 2), global: (10, 20), kind: "touch")
    coordinator.pointerDown(touch, button: .secondary)
    coordinator.pointerUp(touch, button: .secondary)
    XCTAssertEqual(backend.events.map(\.name), ["secondary_tap"])
  }

  func testDisabledControlRejectsEveryNativePointerButton() {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "disabled": true,
        "on_tap": true,
        "on_secondary_tap": true,
        "on_tertiary_tap_up": true,
        "on_hover": true,
        "on_scroll": true,
        "on_scale_start": true,
        "on_scale_update": true,
        "on_scale_end": true,
        "on_multi_tap": true,
      ], backend: backend)
    let pointer = sample(local: (1, 2), global: (10, 20), kind: "mouse")

    XCTAssertTrue(coordinator.hasInteraction)
    XCTAssertFalse(coordinator.accepts(deviceKind: "mouse"))
    for button in [
      RufletGesturePointerButton.primary, .secondary, .tertiary,
    ] {
      coordinator.pointerDown(pointer, button: button)
      coordinator.pointerUp(pointer, button: button)
    }
    coordinator.hoverEntered(pointer)
    coordinator.hoverMoved(pointer)
    coordinator.hoverExited(pointer)
    coordinator.scroll(pointer, delta: .init(x: 2, y: 3))
    coordinator.scaleStarted(
      localFocalPoint: pointer.local, globalFocalPoint: pointer.global,
      pointerCount: 2, timestamp: pointer.timestamp)
    coordinator.scaleUpdated(
      localFocalPoint: pointer.local, globalFocalPoint: pointer.global,
      pointerCount: 2, scale: 1.2, rotation: 0.1, timestamp: pointer.timestamp)
    coordinator.scaleEnded(pointerCount: 0)
    coordinator.multiTouchChanged(correctNumberOfTouches: true)
    XCTAssertTrue(backend.events.isEmpty)
  }

  func testEveryPinnedEventPropertyIsAnExecutableSubscription() {
    let backend = GestureDetectorTestBackend()
    for property in RufletGestureEventCoordinator.eventProperties {
      let coordinator = coordinator(properties: [property: true], backend: backend)
      XCTAssertTrue(coordinator.enabled(property), property)
      XCTAssertTrue(coordinator.hasInteraction, property)
    }
    XCTAssertFalse(coordinator(properties: [:], backend: backend).enabled("on_not_a_flet_event"))
  }

  func testTapUsesPinnedNamesAndCompactDownPayload() {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: ["on_tap": true, "on_tap_down": true, "on_tap_up": true],
      backend: backend)
    let down = sample(local: (2, 3), global: (20, 30), kind: "touch", timestamp: 1)
    let up = sample(local: (4, 5), global: (40, 50), kind: "touch", timestamp: 1.1)

    coordinator.pointerDown(down, button: .primary)
    coordinator.pointerUp(up, button: .primary)

    XCTAssertEqual(backend.events.map(\.name), ["tap_down", "tap_up", "tap"])
    XCTAssertEqual(backend.events[0].data.map?["k"], .string("touch"))
    XCTAssertEqual(backend.events[0].data.map?["l"]?.map?["x"], .double(2))
    XCTAssertEqual(backend.events[1].data.map?["g"]?.map?["y"], .double(50))
    XCTAssertEqual(backend.events[2].data, backend.events[0].data)
  }

  func testPanUpdatePreservesPinnedRelativeDeltaContract() {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "drag_interval": -1,
        "on_pan_start": true,
        "on_pan_update": true,
        "on_pan_end": true,
      ], backend: backend)
    coordinator.pointerDown(
      sample(local: (0, 0), global: (100, 200), timestamp: 1), button: .primary)
    coordinator.pointerMove(
      sample(local: (10, 5), global: (110, 205), timestamp: 1.1), button: .primary)
    coordinator.pointerMove(
      sample(local: (16, 8), global: (122, 212), timestamp: 1.2), button: .primary)
    coordinator.pointerUp(
      sample(local: (20, 10), global: (125, 215), timestamp: 1.3),
      button: .primary, velocity: .init(x: 30, y: 40))

    XCTAssertEqual(
      backend.events.map(\.name), ["pan_start", "pan_update", "pan_update", "pan_end"])
    let secondUpdate = backend.events[2].data.map
    XCTAssertEqual(secondUpdate?["ld"]?.map?["x"], .double(6))
    XCTAssertEqual(secondUpdate?["ld"]?.map?["y"], .double(3))
    // Pinned Flet advances the local origin but retains the pan's global origin.
    XCTAssertEqual(secondUpdate?["gd"]?.map?["x"], .double(22))
    XCTAssertEqual(secondUpdate?["gd"]?.map?["y"], .double(12))
    XCTAssertEqual(backend.events[3].data.map?["v"]?.map?["y"], .double(40))
  }

  func testLongPressMoveKeepsGlobalAndLocalOriginsDistinct() async throws {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "on_long_press_start": true,
        "on_long_press_move_update": true,
        "on_long_press_end": true,
      ], backend: backend)
    coordinator.pointerDown(
      sample(local: (1, 2), global: (10, 20), timestamp: 1), button: .primary)
    try await Task.sleep(nanoseconds: 550_000_000)
    coordinator.pointerMove(
      sample(local: (5, 8), global: (17, 29), timestamp: 1.6), button: .primary)
    coordinator.pointerUp(
      sample(local: (6, 9), global: (18, 30), timestamp: 1.7),
      button: .primary, velocity: .init(x: 2, y: 3))

    XCTAssertEqual(
      backend.events.map(\.name),
      ["long_press_start", "long_press_move_update", "long_press_end"])
    let move = backend.events[1].data.map
    XCTAssertEqual(move?["ofo"]?.map?["x"], .double(7))
    XCTAssertEqual(move?["ofo"]?.map?["y"], .double(9))
    XCTAssertEqual(move?["lofo"]?.map?["x"], .double(4))
    XCTAssertEqual(move?["lofo"]?.map?["y"], .double(6))
  }

  func testSecondaryAndTertiaryLongPressLifecycleUsesExactPinnedNames() async throws {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "on_secondary_tap_down": true,
        "on_secondary_long_press_down": true,
        "on_secondary_long_press_start": true,
        "on_secondary_long_press": true,
        "on_secondary_long_press_move_update": true,
        "on_secondary_long_press_end": true,
        "on_secondary_long_press_up": true,
        "on_tertiary_tap_down": true,
        "on_tertiary_long_press_down": true,
        "on_tertiary_long_press_start": true,
        "on_tertiary_long_press": true,
        "on_tertiary_long_press_move_update": true,
        "on_tertiary_long_press_end": true,
        "on_tertiary_long_press_up": true,
      ], backend: backend)
    let down = sample(local: (1, 2), global: (10, 20), kind: "mouse", timestamp: 1)
    coordinator.pointerDown(down, button: .secondary)
    coordinator.pointerDown(down, button: .tertiary)
    try await Task.sleep(nanoseconds: 550_000_000)
    let moved = sample(local: (5, 8), global: (17, 29), kind: "mouse", timestamp: 1.6)
    coordinator.pointerMove(moved, button: .secondary)
    coordinator.pointerMove(moved, button: .tertiary)
    coordinator.pointerUp(moved, button: .secondary)
    coordinator.pointerUp(moved, button: .tertiary)

    let secondary = backend.events.map(\.name).filter { $0.hasPrefix("secondary_") }
    XCTAssertEqual(secondary, [
      "secondary_tap_down", "secondary_long_press_down", "secondary_long_press_start",
      "secondary_long_press", "secondary_long_press_move_update", "secondary_long_press_end",
      "secondary_long_press_up",
    ])
    let tertiary = backend.events.map(\.name).filter { $0.hasPrefix("tertiary_") }
    XCTAssertEqual(tertiary, [
      "tertiary_tap_down", "tertiary_long_press_down", "tertiary_long_press_start",
      "tertiary_long_press", "tertiary_long_press_move_update", "tertiary_long_press_end",
      "tertiary_long_press_up",
    ])
  }

  func testForcePressPhasesPreservePinnedOrderAndPressure() {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "on_force_press_start": true,
        "on_force_press_peak": true,
        "on_force_press_update": true,
        "on_force_press_end": true,
      ], backend: backend)
    let pointer = RufletGesturePointerSample(
      local: .init(x: 2, y: 3), global: .init(x: 20, y: 30),
      deviceKind: "touch", timestamp: 2, pressure: 0.75)

    coordinator.forcePress(.start, sample: pointer)
    coordinator.forcePress(.update, sample: pointer)
    coordinator.forcePress(.peak, sample: pointer)
    coordinator.forcePress(.end, sample: pointer)

    XCTAssertEqual(backend.events.map(\.name), [
      "force_press_start", "force_press_update", "force_press_peak", "force_press_end",
    ])
    XCTAssertEqual(backend.events.map { $0.data.map?["p"] }, Array(repeating: .double(0.75), count: 4))
  }

  func testScrollTrackpadScaleAndMultiTapUsePinnedPayloads() {
    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "on_scroll": true,
        "on_scale_start": true,
        "on_scale_update": true,
        "on_scale_end": true,
        "trackpad_scroll_causes_scale": true,
        "on_multi_tap": true,
      ], backend: backend)
    let pointer = sample(local: (3, 4), global: (30, 40), timestamp: 2)
    let delta = RufletEventPoint(x: 0, y: -20)

    coordinator.scroll(pointer, delta: delta)
    coordinator.trackpadScrolled(pointer, delta: delta, ended: true)
    coordinator.multiTouchChanged(correctNumberOfTouches: true)
    coordinator.multiTouchChanged(correctNumberOfTouches: false)

    XCTAssertEqual(
      backend.events.map(\.name),
      ["scroll", "scale_start", "scale_update", "scale_end", "multi_tap", "multi_tap"])
    XCTAssertEqual(backend.events[0].data.map?["sd"]?.map?["y"], .double(-20))
    XCTAssertEqual(backend.events[1].data.map?["pc"], .int(2))
    XCTAssertGreaterThan(backend.events[2].data.map?["s"]?.number ?? 0, 1)
    XCTAssertEqual(backend.events[3].data.map?["v"]?.map?["x"], .double(0))
    XCTAssertEqual(backend.events[4].data, ["ct": true])
    XCTAssertEqual(backend.events[5].data, ["ct": false])
  }

  func testRightPanRequiresStartAndUsesPointerDeltaPayload() {
    let ignoredBackend = GestureDetectorTestBackend()
    let ignored = coordinator(
      properties: ["on_right_pan_update": true, "drag_interval": -1],
      backend: ignoredBackend)
    let start = sample(local: (2, 3), global: (20, 30), kind: "mouse", timestamp: 1)
    ignored.rightPanStarted(start)
    ignored.rightPanMoved(sample(local: (5, 7), global: (23, 34), kind: "mouse"))
    XCTAssertTrue(ignoredBackend.events.isEmpty)

    let backend = GestureDetectorTestBackend()
    let coordinator = coordinator(
      properties: [
        "on_right_pan_start": true,
        "on_right_pan_update": true,
        "on_right_pan_end": true,
        "drag_interval": -1,
      ], backend: backend)
    coordinator.rightPanStarted(start)
    coordinator.rightPanMoved(
      sample(local: (5, 7), global: (23, 34), kind: "mouse", timestamp: 1.1))
    coordinator.rightPanEnded(
      sample(local: (6, 8), global: (24, 35), kind: "mouse", timestamp: 1.2))

    XCTAssertEqual(backend.events.map(\.name), ["right_pan_start", "right_pan_update", "right_pan_end"])
    XCTAssertEqual(backend.events[1].data.map?["ld"]?.map?["x"], .double(3))
    XCTAssertEqual(backend.events[1].data.map?["ld"]?.map?["y"], .double(4))
  }

  private func coordinator(
    properties: [String: RufletValue],
    backend: GestureDetectorTestBackend
  ) -> RufletGestureEventCoordinator {
    RufletGestureEventCoordinator(control: RufletControl(
      id: backend.nextID(), type: "GestureDetector", properties: properties,
      backend: backend))
  }

  private func sample(
    local: (Double, Double),
    global: (Double, Double),
    kind: String = "touch",
    timestamp: TimeInterval = 0
  ) -> RufletGesturePointerSample {
    RufletGesturePointerSample(
      local: .init(x: local.0, y: local.1),
      global: .init(x: global.0, y: global.1),
      deviceKind: kind, timestamp: timestamp)
  }
}

@MainActor
private final class GestureDetectorTestBackend: RufletBackendProtocol {
  struct Event: Equatable {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var events: [Event] = []
  private var sequence = 0

  func nextID() -> Int {
    sequence += 1
    return sequence
  }

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }
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
