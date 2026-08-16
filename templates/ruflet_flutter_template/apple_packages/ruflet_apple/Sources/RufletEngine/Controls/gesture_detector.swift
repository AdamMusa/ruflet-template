import RufletProtocol
import SwiftUI

/// Apple-native, file-for-file port of pinned Flet `GestureDetectorControl`.
@MainActor
public struct GestureDetectorControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletGestureEventCoordinator

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletGestureEventCoordinator(control: control))
  }

  public var body: some View {
    LayoutControl(control: control) {
      if !coordinator.hasInteraction {
        ErrorControl("GestureDetector should have at least one event handler defined")
      } else {
        gestureContent
      }
    }
    .onDisappear { coordinator.cancelPendingGestures() }
  }

  private var gestureContent: some View {
    Group {
      if let content = control.buildWidget("content") {
        content
      } else {
        Color.clear
      }
    }
    .contentShape(Rectangle())
    .background(RufletPlatformGestureMonitor(coordinator: coordinator))
    .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
    .accessibilityHidden(control.boolean("exclude_from_semantics", default: false))
    .allowsHitTesting(!control.disabled)
  }
}

enum RufletGesturePointerButton: String, Hashable, Sendable {
  case primary
  case secondary
  case tertiary

  var eventPrefix: String {
    switch self {
    case .primary: ""
    case .secondary: "secondary_"
    case .tertiary: "tertiary_"
    }
  }
}

struct RufletGesturePointerSample: Equatable, Sendable {
  let local: RufletEventPoint
  let global: RufletEventPoint
  let deviceKind: String
  let timestamp: TimeInterval
  let pressure: Double
  let pressureMinimum: Double
  let pressureMaximum: Double
  let device: Int

  init(
    local: RufletEventPoint,
    global: RufletEventPoint,
    deviceKind: String,
    timestamp: TimeInterval,
    pressure: Double = 0,
    pressureMinimum: Double = 0,
    pressureMaximum: Double = 1,
    device: Int = 0
  ) {
    self.local = local
    self.global = global
    self.deviceKind = deviceKind
    self.timestamp = timestamp
    self.pressure = pressure
    self.pressureMinimum = pressureMinimum
    self.pressureMaximum = pressureMaximum
    self.device = device
  }
}

@MainActor
final class RufletGestureEventCoordinator: ObservableObject {
  let control: RufletControl

  private var downSamples: [RufletGesturePointerButton: RufletGesturePointerSample] = [:]
  private var previousSamples: [RufletGesturePointerButton: RufletGesturePointerSample] = [:]
  private var cancelledTaps: Set<RufletGesturePointerButton> = []
  private var longPressTasks: [RufletGesturePointerButton: Task<Void, Never>] = [:]
  private var longPressActive: Set<RufletGesturePointerButton> = []
  private var activeDrags: Set<RufletGestureDragKind> = []
  private var dragOrigins: [RufletGestureDragKind: RufletGesturePointerSample] = [:]
  private var previousDragSamples: [RufletGestureDragKind: RufletGesturePointerSample] = [:]
  private var dragTimestamps: [RufletGestureDragKind: Int64] = [:]
  private var hoverOrigin: RufletGesturePointerSample?
  private var hoverTimestamp = currentMilliseconds()
  private var pendingTap: Task<Void, Never>?
  private var lastTapAt: TimeInterval?
  private var multiLongPressTask: Task<Void, Never>?
  private var scaleActive = false
  private var scaleFocalPoint = RufletEventPoint(x: 0, y: 0)
  private var scaleLocalFocalPoint = RufletEventPoint(x: 0, y: 0)
  private var lastScale = 1.0
  private var lastRotation = 0.0

  init(control: RufletControl) { self.control = control }

  var hasInteraction: Bool {
    Self.eventProperties.contains(where: enabled)
      || Self.knownCursors.contains(control.string("mouse_cursor")?.lowercased() ?? "")
  }

  func accepts(deviceKind: String) -> Bool {
    guard !control.disabled else { return false }
    guard let raw = control.value("allowed_devices") else { return true }
    let devices = Set(raw.array?.compactMap { $0.text?.lowercased() } ?? [])
    return devices.contains(deviceKind.lowercased())
  }

  func pointerDown(
    _ sample: RufletGesturePointerSample,
    button: RufletGesturePointerButton
  ) {
    guard accepts(deviceKind: sample.deviceKind) else { return }
    downSamples[button] = sample
    previousSamples[button] = sample
    cancelledTaps.remove(button)
    emit("\(button.eventPrefix)tap_down", positionedValue(sample))
    emit("\(button.eventPrefix)long_press_down", positionedValue(sample))
    if button == .primary {
      emit("double_tap_down", positionedValue(sample))
      emit("horizontal_drag_down", dragDownValue(sample))
      emit("vertical_drag_down", dragDownValue(sample))
      emit("pan_down", dragDownValue(sample))
    }
    scheduleLongPress(for: button, sample: sample)
  }

  func pointerMove(
    _ sample: RufletGesturePointerSample,
    button: RufletGesturePointerButton
  ) {
    guard accepts(deviceKind: sample.deviceKind),
          let down = downSamples[button]
    else { return }
    let previous = previousSamples[button] ?? down
    previousSamples[button] = sample

    if button == .primary {
      emit("tap_move", RufletTapMoveDetails(
        localPosition: sample.local,
        globalPosition: sample.global,
        delta: pointDifference(sample.local, previous.local),
        deviceKind: sample.deviceKind).value)
    }

    if longPressActive.contains(button) {
      emit("\(button.eventPrefix)long_press_move_update", longPressMoveValue(
        sample: sample, origin: down))
      return
    }

    let delta = pointDifference(sample.local, down.local)
    guard hypot(delta.x, delta.y) >= 8 else { return }
    cancelledTaps.insert(button)
    cancelLongPress(for: button, emitCancel: true)
    guard button == .primary else { return }
    beginDragsIfNeeded(sample: sample, origin: down, delta: delta)
    updateActiveDrags(sample)
  }

  func pointerUp(
    _ sample: RufletGesturePointerSample,
    button: RufletGesturePointerButton,
    velocity: RufletEventPoint = .init(x: 0, y: 0)
  ) {
    guard accepts(deviceKind: sample.deviceKind),
          downSamples[button] != nil
    else { return }

    if longPressActive.contains(button) {
      emit("\(button.eventPrefix)long_press_end", longPressEndValue(sample, velocity: velocity))
      emit("\(button.eventPrefix)long_press_up")
    } else {
      cancelLongPress(for: button, emitCancel: hasLongPressHandler(button))
      switch button {
      case .primary:
        if activeDrags.isEmpty && !cancelledTaps.contains(button) {
          emit("tap_up", positionedValue(sample))
          registerPrimaryTap(sample)
          cancelInactiveDrags()
        } else {
          emit("tap_cancel")
          endActiveDrags(sample, velocity: velocity)
        }
      case .secondary:
        if cancelledTaps.contains(button) {
          emit("secondary_tap_cancel")
        } else {
          emit("secondary_tap_up", positionedValue(sample))
          emit("secondary_tap")
        }
      case .tertiary:
        if cancelledTaps.contains(button) {
          emit("tertiary_tap_cancel")
        } else {
          emit("tertiary_tap_up", positionedValue(sample))
        }
      }
    }
    downSamples[button] = nil
    previousSamples[button] = nil
    longPressActive.remove(button)
    cancelledTaps.remove(button)
  }

  func pointerCancel(button: RufletGesturePointerButton) {
    guard downSamples[button] != nil else { return }
    cancelLongPress(for: button, emitCancel: hasLongPressHandler(button))
    emit("\(button.eventPrefix)tap_cancel")
    if button == .primary {
      cancelActiveDrags()
      emit("double_tap_cancel")
    }
    downSamples[button] = nil
    previousSamples[button] = nil
    longPressActive.remove(button)
    cancelledTaps.remove(button)
  }

  /// AppKit platform views such as NSTextView run their own mouse tracking
  /// loop, so their mouse-up events do not reliably pass through a local
  /// NSEvent monitor. An ancestor NSClickGestureRecognizer supplies the same
  /// native double-tap decision without intercepting the child control.
  func nativeDoubleTap() {
    guard !control.disabled, enabled("on_double_tap") else { return }
    pendingTap?.cancel()
    pendingTap = nil
    lastTapAt = nil
    emit("double_tap")
  }

  func forcePress(_ phase: RufletForcePressPhase, sample: RufletGesturePointerSample) {
    guard accepts(deviceKind: sample.deviceKind) else { return }
    let event: String
    switch phase {
    case .start: event = "force_press_start"
    case .peak: event = "force_press_peak"
    case .update: event = "force_press_update"
    case .end: event = "force_press_end"
    }
    emit(event, RufletForcePressDetails(
      localPosition: sample.local,
      globalPosition: sample.global,
      pressure: sample.pressure).value)
  }

  func hoverEntered(_ sample: RufletGesturePointerSample) {
    guard !control.disabled else { return }
    hoverOrigin = sample
    emit("enter", pointerValue(sample, previous: nil))
  }

  func hoverMoved(_ sample: RufletGesturePointerSample) {
    guard !control.disabled else { return }
    let now = currentMilliseconds()
    guard now - hoverTimestamp > Int64(control.integer("hover_interval", default: 0) ?? 0) else { return }
    hoverTimestamp = now
    emit("hover", pointerValue(sample, previous: hoverOrigin))
    hoverOrigin = sample
  }

  func hoverExited(_ sample: RufletGesturePointerSample) {
    guard !control.disabled else { return }
    emit("exit", pointerValue(sample, previous: nil))
    hoverOrigin = nil
  }

  func scroll(
    _ sample: RufletGesturePointerSample,
    delta: RufletEventPoint
  ) {
    guard !control.disabled else { return }
    emit("scroll", RufletPointerScrollDetails(
      localPosition: sample.local,
      globalPosition: sample.global,
      scrollDelta: delta).value)
  }

  func rightPanStarted(_ sample: RufletGesturePointerSample) {
    guard !control.disabled else { return }
    guard enabled("on_right_pan_start") else { return }
    dragOrigins[.rightPan] = sample
    previousDragSamples[.rightPan] = sample
    activeDrags.insert(.rightPan)
    emit("right_pan_start", pointerValue(sample, previous: nil))
  }

  func rightPanMoved(_ sample: RufletGesturePointerSample) {
    guard !control.disabled else { return }
    guard activeDrags.contains(.rightPan), dragIntervalAllows(.rightPan) else { return }
    let previous = previousDragSamples[.rightPan]
    emit("right_pan_update", pointerValue(sample, previous: previous))
    previousDragSamples[.rightPan] = sample
  }

  func rightPanEnded(_ sample: RufletGesturePointerSample) {
    guard !control.disabled else { return }
    guard activeDrags.remove(.rightPan) != nil else { return }
    emit("right_pan_end", pointerValue(sample, previous: nil))
    dragOrigins[.rightPan] = nil
    previousDragSamples[.rightPan] = nil
  }

  func scaleStarted(
    localFocalPoint: RufletEventPoint,
    globalFocalPoint: RufletEventPoint,
    pointerCount: Int,
    timestamp: TimeInterval?
  ) {
    guard !control.disabled else { return }
    guard !scaleActive else { return }
    scaleActive = true
    scaleLocalFocalPoint = localFocalPoint
    scaleFocalPoint = globalFocalPoint
    lastScale = 1
    lastRotation = 0
    emit("scale_start", RufletScaleStartDetails(
      focalPoint: globalFocalPoint,
      localFocalPoint: localFocalPoint,
      pointerCount: pointerCount,
      timestamp: timestamp).value)
  }

  func scaleUpdated(
    localFocalPoint: RufletEventPoint,
    globalFocalPoint: RufletEventPoint,
    pointerCount: Int,
    scale: Double,
    horizontalScale: Double? = nil,
    verticalScale: Double? = nil,
    rotation: Double,
    timestamp: TimeInterval?
  ) {
    guard !control.disabled else { return }
    if !scaleActive {
      scaleStarted(
        localFocalPoint: localFocalPoint, globalFocalPoint: globalFocalPoint,
        pointerCount: pointerCount, timestamp: timestamp)
    }
    emit("scale_update", RufletScaleUpdateDetails(
      focalPoint: globalFocalPoint,
      focalPointDelta: pointDifference(globalFocalPoint, scaleFocalPoint),
      localFocalPoint: localFocalPoint,
      pointerCount: pointerCount,
      horizontalScale: horizontalScale ?? scale,
      verticalScale: verticalScale ?? scale,
      scale: scale,
      rotation: rotation,
      timestamp: timestamp).value)
    scaleLocalFocalPoint = localFocalPoint
    scaleFocalPoint = globalFocalPoint
    lastScale = scale
    lastRotation = rotation
  }

  func scaleEnded(pointerCount: Int, velocity: RufletEventPoint = .init(x: 0, y: 0)) {
    guard !control.disabled else { return }
    guard scaleActive else { return }
    emit("scale_end", RufletScaleEndDetails(pointerCount: pointerCount, velocity: velocity).value)
    scaleActive = false
  }

  func trackpadScrolled(
    _ sample: RufletGesturePointerSample,
    delta: RufletEventPoint,
    ended: Bool
  ) {
    guard !control.disabled else { return }
    guard control.boolean("trackpad_scroll_causes_scale", default: false) else { return }
    let scale = lastScale * exp(-delta.y / 200)
    scaleUpdated(
      localFocalPoint: sample.local, globalFocalPoint: sample.global,
      pointerCount: 2, scale: scale, rotation: lastRotation,
      timestamp: sample.timestamp)
    if ended { scaleEnded(pointerCount: 0) }
  }

  func multiTouchChanged(correctNumberOfTouches: Bool) {
    guard !control.disabled else { return }
    emit("multi_tap", ["ct": .bool(correctNumberOfTouches)])
    multiLongPressTask?.cancel()
    multiLongPressTask = nil
    guard correctNumberOfTouches, enabled("on_multi_long_press") else { return }
    multiLongPressTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      guard !Task.isCancelled else { return }
      self?.emit("multi_long_press")
    }
  }

  func cancelPendingGestures() {
    pendingTap?.cancel()
    pendingTap = nil
    multiLongPressTask?.cancel()
    multiLongPressTask = nil
    for task in longPressTasks.values { task.cancel() }
    longPressTasks.removeAll()
  }

  private func beginDragsIfNeeded(
    sample: RufletGesturePointerSample,
    origin: RufletGesturePointerSample,
    delta: RufletEventPoint
  ) {
    let horizontalConfigured = hasDragHandler(.horizontal)
    let verticalConfigured = hasDragHandler(.vertical)
    if horizontalConfigured && abs(delta.x) >= abs(delta.y) {
      beginDrag(.horizontal, sample: sample, origin: origin)
    } else if verticalConfigured && abs(delta.y) > abs(delta.x) {
      beginDrag(.vertical, sample: sample, origin: origin)
    } else if hasDragHandler(.pan) {
      beginDrag(.pan, sample: sample, origin: origin)
    }
  }

  private func beginDrag(
    _ kind: RufletGestureDragKind,
    sample: RufletGesturePointerSample,
    origin: RufletGesturePointerSample
  ) {
    guard activeDrags.insert(kind).inserted else { return }
    dragOrigins[kind] = origin
    previousDragSamples[kind] = origin
    dragTimestamps[kind] = currentMilliseconds()
    emit("\(kind.eventPrefix)_start", RufletDragStartDetails(
      localPosition: sample.local,
      globalPosition: sample.global,
      deviceKind: sample.deviceKind,
      timestamp: sample.timestamp).value)
  }

  private func updateActiveDrags(_ sample: RufletGesturePointerSample) {
    for kind in activeDrags where kind != .rightPan {
      guard dragIntervalAllows(kind) else { continue }
      let previous = previousDragSamples[kind]
      let primaryDelta: Double?
      switch kind {
      case .horizontal: primaryDelta = previous.map { sample.local.x - $0.local.x }
      case .vertical: primaryDelta = previous.map { sample.local.y - $0.local.y }
      case .pan, .rightPan: primaryDelta = nil
      }
      emit("\(kind.eventPrefix)_update", RufletDragUpdateDetails(
        localPosition: sample.local,
        globalPosition: sample.global,
        previousLocalPosition: previous?.local,
        // The pinned Flet pan handler intentionally keeps its global origin
        // while advancing the local origin after each dispatched update.
        previousGlobalPosition: kind == .pan ? dragOrigins[kind]?.global : previous?.global,
        primaryDelta: primaryDelta,
        timestamp: sample.timestamp).value)
      previousDragSamples[kind] = sample
    }
  }

  private func endActiveDrags(
    _ sample: RufletGesturePointerSample,
    velocity: RufletEventPoint
  ) {
    for kind in activeDrags where kind != .rightPan {
      let primaryVelocity: Double?
      switch kind {
      case .horizontal: primaryVelocity = velocity.x
      case .vertical: primaryVelocity = velocity.y
      case .pan, .rightPan: primaryVelocity = nil
      }
      emit("\(kind.eventPrefix)_end", RufletDragEndDetails(
        localPosition: sample.local,
        globalPosition: sample.global,
        velocity: velocity,
        primaryVelocity: primaryVelocity).value)
    }
    activeDrags = activeDrags.filter { $0 == .rightPan }
    dragOrigins = dragOrigins.filter { $0.key == .rightPan }
    previousDragSamples = previousDragSamples.filter { $0.key == .rightPan }
  }

  private func cancelInactiveDrags() {
    for kind in [RufletGestureDragKind.horizontal, .vertical, .pan] {
      emit("\(kind.eventPrefix)_cancel")
    }
  }

  private func cancelActiveDrags() {
    for kind in activeDrags where kind != .rightPan {
      emit("\(kind.eventPrefix)_cancel")
    }
    activeDrags = activeDrags.filter { $0 == .rightPan }
  }

  private func hasDragHandler(_ kind: RufletGestureDragKind) -> Bool {
    ["down", "start", "update", "end", "cancel"].contains {
      enabled("on_\(kind.eventPrefix)_\($0)")
    }
  }

  private func dragIntervalAllows(_ kind: RufletGestureDragKind) -> Bool {
    let now = currentMilliseconds()
    let last = dragTimestamps[kind] ?? 0
    guard now - last > Int64(control.integer("drag_interval", default: 0) ?? 0) else { return false }
    dragTimestamps[kind] = now
    return true
  }

  private func registerPrimaryTap(_ sample: RufletGesturePointerSample) {
    guard enabled("on_double_tap") || enabled("on_double_tap_cancel") else {
      emit("tap", downSamples[.primary].map(positionedValue) ?? positionedValue(sample))
      return
    }
    if let lastTapAt, sample.timestamp - lastTapAt <= 0.3 {
      pendingTap?.cancel()
      pendingTap = nil
      self.lastTapAt = nil
      emit("double_tap")
      return
    }
    lastTapAt = sample.timestamp
    let tapValue = downSamples[.primary].map(positionedValue) ?? positionedValue(sample)
    pendingTap?.cancel()
    pendingTap = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      self?.emit("tap", tapValue)
      self?.emit("double_tap_cancel")
      self?.lastTapAt = nil
      self?.pendingTap = nil
    }
  }

  private func scheduleLongPress(
    for button: RufletGesturePointerButton,
    sample: RufletGesturePointerSample
  ) {
    guard hasLongPressHandler(button) else { return }
    longPressTasks[button]?.cancel()
    longPressTasks[button] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 500_000_000)
      guard !Task.isCancelled, let self, self.downSamples[button] != nil else { return }
      self.longPressActive.insert(button)
      self.emit("\(button.eventPrefix)long_press_start", self.longPressStartValue(sample))
      self.emit("\(button.eventPrefix)long_press")
    }
  }

  private func cancelLongPress(
    for button: RufletGesturePointerButton,
    emitCancel: Bool
  ) {
    longPressTasks[button]?.cancel()
    longPressTasks[button] = nil
    if emitCancel, !longPressActive.contains(button) {
      emit("\(button.eventPrefix)long_press_cancel")
    }
  }

  private func hasLongPressHandler(_ button: RufletGesturePointerButton) -> Bool {
    ["down", "cancel", "", "start", "move_update", "up", "end"].contains { suffix in
      let end = suffix.isEmpty ? "" : "_\(suffix)"
      return enabled("on_\(button.eventPrefix)long_press\(end)")
    }
  }

  func enabled(_ property: String) -> Bool {
    // Keep every pinned callback as an executable read. Besides preventing a
    // typo in an interpolated event name from silently enabling interaction,
    // this is the native equivalent of the explicit `getBool("on_…")` reads
    // in Flet's GestureDetectorControl.build().
    switch property {
    case "on_hover": control.hasEventHandler("hover")
    case "on_enter": control.hasEventHandler("enter")
    case "on_exit": control.hasEventHandler("exit")
    case "on_tap": control.hasEventHandler("tap")
    case "on_tap_down": control.hasEventHandler("tap_down")
    case "on_tap_up": control.hasEventHandler("tap_up")
    case "on_tap_move": control.hasEventHandler("tap_move")
    case "on_tap_cancel": control.hasEventHandler("tap_cancel")
    case "on_secondary_tap": control.hasEventHandler("secondary_tap")
    case "on_secondary_tap_down": control.hasEventHandler("secondary_tap_down")
    case "on_secondary_tap_up": control.hasEventHandler("secondary_tap_up")
    case "on_secondary_tap_cancel": control.hasEventHandler("secondary_tap_cancel")
    case "on_tertiary_tap_down": control.hasEventHandler("tertiary_tap_down")
    case "on_tertiary_tap_up": control.hasEventHandler("tertiary_tap_up")
    case "on_tertiary_tap_cancel": control.hasEventHandler("tertiary_tap_cancel")
    case "on_double_tap": control.hasEventHandler("double_tap")
    case "on_double_tap_down": control.hasEventHandler("double_tap_down")
    case "on_double_tap_cancel": control.hasEventHandler("double_tap_cancel")
    case "on_long_press_down": control.hasEventHandler("long_press_down")
    case "on_long_press_cancel": control.hasEventHandler("long_press_cancel")
    case "on_long_press": control.hasEventHandler("long_press")
    case "on_long_press_start": control.hasEventHandler("long_press_start")
    case "on_long_press_move_update": control.hasEventHandler("long_press_move_update")
    case "on_long_press_up": control.hasEventHandler("long_press_up")
    case "on_long_press_end": control.hasEventHandler("long_press_end")
    case "on_secondary_long_press_down":
      control.hasEventHandler("secondary_long_press_down")
    case "on_secondary_long_press_cancel":
      control.hasEventHandler("secondary_long_press_cancel")
    case "on_secondary_long_press": control.hasEventHandler("secondary_long_press")
    case "on_secondary_long_press_start":
      control.hasEventHandler("secondary_long_press_start")
    case "on_secondary_long_press_move_update":
      control.hasEventHandler("secondary_long_press_move_update")
    case "on_secondary_long_press_up": control.hasEventHandler("secondary_long_press_up")
    case "on_secondary_long_press_end": control.hasEventHandler("secondary_long_press_end")
    case "on_tertiary_long_press_down":
      control.hasEventHandler("tertiary_long_press_down")
    case "on_tertiary_long_press_cancel":
      control.hasEventHandler("tertiary_long_press_cancel")
    case "on_tertiary_long_press": control.hasEventHandler("tertiary_long_press")
    case "on_tertiary_long_press_start":
      control.hasEventHandler("tertiary_long_press_start")
    case "on_tertiary_long_press_move_update":
      control.hasEventHandler("tertiary_long_press_move_update")
    case "on_tertiary_long_press_up": control.hasEventHandler("tertiary_long_press_up")
    case "on_tertiary_long_press_end": control.hasEventHandler("tertiary_long_press_end")
    case "on_horizontal_drag_down": control.hasEventHandler("horizontal_drag_down")
    case "on_horizontal_drag_start": control.hasEventHandler("horizontal_drag_start")
    case "on_horizontal_drag_update": control.hasEventHandler("horizontal_drag_update")
    case "on_horizontal_drag_end": control.hasEventHandler("horizontal_drag_end")
    case "on_horizontal_drag_cancel": control.hasEventHandler("horizontal_drag_cancel")
    case "on_vertical_drag_down": control.hasEventHandler("vertical_drag_down")
    case "on_vertical_drag_start": control.hasEventHandler("vertical_drag_start")
    case "on_vertical_drag_update": control.hasEventHandler("vertical_drag_update")
    case "on_vertical_drag_end": control.hasEventHandler("vertical_drag_end")
    case "on_vertical_drag_cancel": control.hasEventHandler("vertical_drag_cancel")
    case "on_pan_down": control.hasEventHandler("pan_down")
    case "on_pan_start": control.hasEventHandler("pan_start")
    case "on_pan_update": control.hasEventHandler("pan_update")
    case "on_pan_end": control.hasEventHandler("pan_end")
    case "on_pan_cancel": control.hasEventHandler("pan_cancel")
    case "on_scale_start": control.hasEventHandler("scale_start")
    case "on_scale_update": control.hasEventHandler("scale_update")
    case "on_scale_end": control.hasEventHandler("scale_end")
    case "on_force_press_start": control.hasEventHandler("force_press_start")
    case "on_force_press_peak": control.hasEventHandler("force_press_peak")
    case "on_force_press_update": control.hasEventHandler("force_press_update")
    case "on_force_press_end": control.hasEventHandler("force_press_end")
    case "on_multi_tap": control.hasEventHandler("multi_tap")
    case "on_multi_long_press": control.hasEventHandler("multi_long_press")
    case "on_scroll": control.hasEventHandler("scroll")
    case "on_right_pan_start": control.hasEventHandler("right_pan_start")
    case "on_right_pan_update": control.hasEventHandler("right_pan_update")
    case "on_right_pan_end": control.hasEventHandler("right_pan_end")
    default: false
    }
  }

  private func emit(_ event: String, _ data: RufletValue = .null) {
    guard !control.disabled, enabled("on_\(event)") else { return }
    control.triggerEvent(event, data: data)
  }

  private func positionedValue(_ sample: RufletGesturePointerSample) -> RufletValue {
    RufletPositionedGestureDetails(
      localPosition: sample.local,
      globalPosition: sample.global,
      deviceKind: sample.deviceKind).value
  }

  private func dragDownValue(_ sample: RufletGesturePointerSample) -> RufletValue {
    ["l": sample.local.value, "g": sample.global.value]
  }

  private func pointerValue(
    _ sample: RufletGesturePointerSample,
    previous: RufletGesturePointerSample?
  ) -> RufletValue {
    RufletPointerEventDetails(
      deviceKind: sample.deviceKind,
      localPosition: sample.local,
      globalPosition: sample.global,
      previousLocalPosition: previous?.local,
      timestamp: sample.timestamp,
      device: sample.device,
      pressure: sample.pressure,
      pressureMinimum: sample.pressureMinimum,
      pressureMaximum: sample.pressureMaximum,
      distance: 0,
      distanceMaximum: 0,
      size: 0,
      radiusMajor: 0,
      radiusMinor: 0,
      radiusMinimum: 0,
      radiusMaximum: 0,
      orientation: 0,
      tilt: 0).value
  }

  private func longPressStartValue(_ sample: RufletGesturePointerSample) -> RufletValue {
    ["l": sample.local.value, "g": sample.global.value]
  }

  private func longPressMoveValue(
    sample: RufletGesturePointerSample,
    origin: RufletGesturePointerSample
  ) -> RufletValue {
    let globalDelta = pointDifference(sample.global, origin.global)
    let localDelta = pointDifference(sample.local, origin.local)
    return [
      "l": sample.local.value,
      "g": sample.global.value,
      "ofo": globalDelta.value,
      "lofo": localDelta.value,
    ]
  }

  private func longPressEndValue(
    _ sample: RufletGesturePointerSample,
    velocity: RufletEventPoint
  ) -> RufletValue {
    ["l": sample.local.value, "g": sample.global.value, "v": velocity.value]
  }

  static let eventProperties = [
    "on_hover", "on_enter", "on_exit", "on_tap", "on_tap_down", "on_tap_up",
    "on_tap_move", "on_tap_cancel", "on_secondary_tap", "on_secondary_tap_down",
    "on_secondary_tap_up", "on_secondary_tap_cancel", "on_tertiary_tap_down",
    "on_tertiary_tap_up", "on_tertiary_tap_cancel", "on_double_tap",
    "on_double_tap_down", "on_double_tap_cancel", "on_long_press_down",
    "on_long_press_cancel", "on_long_press", "on_long_press_start",
    "on_long_press_move_update", "on_long_press_up", "on_long_press_end",
    "on_secondary_long_press_down", "on_secondary_long_press_cancel",
    "on_secondary_long_press", "on_secondary_long_press_start",
    "on_secondary_long_press_move_update", "on_secondary_long_press_up",
    "on_secondary_long_press_end", "on_tertiary_long_press_down",
    "on_tertiary_long_press_cancel", "on_tertiary_long_press",
    "on_tertiary_long_press_start", "on_tertiary_long_press_move_update",
    "on_tertiary_long_press_up", "on_tertiary_long_press_end",
    "on_horizontal_drag_down", "on_horizontal_drag_start", "on_horizontal_drag_update",
    "on_horizontal_drag_end", "on_horizontal_drag_cancel", "on_vertical_drag_down",
    "on_vertical_drag_start", "on_vertical_drag_update", "on_vertical_drag_end",
    "on_vertical_drag_cancel", "on_pan_down", "on_pan_start", "on_pan_update",
    "on_pan_end", "on_pan_cancel", "on_scale_start", "on_scale_update", "on_scale_end",
    "on_force_press_start", "on_force_press_peak", "on_force_press_update",
    "on_force_press_end", "on_multi_tap", "on_multi_long_press", "on_scroll",
    "on_right_pan_start", "on_right_pan_update", "on_right_pan_end",
  ]

  private static let knownCursors: Set<String> = [
    "alias", "allscroll", "basic", "cell", "click", "contextmenu", "copy",
    "disappearing", "forbidden", "grab", "grabbing", "help", "move", "nodrop",
    "none", "precise", "progress", "resizecolumn", "resizedown", "resizeleft",
    "resizedownleft", "resizedownright", "resizeleftright", "resizeright",
    "resizerow", "resizeup", "resizeupdown", "resizeupleft",
    "resizeupleftdownright", "resizeupright", "resizeuprightdownleft", "text",
    "verticaltext", "wait", "zoomin", "zoomout",
  ]
}

private enum RufletGestureDragKind: Hashable {
  case horizontal, vertical, pan, rightPan

  var eventPrefix: String {
    switch self {
    case .horizontal: "horizontal_drag"
    case .vertical: "vertical_drag"
    case .pan: "pan"
    case .rightPan: "right_pan"
    }
  }
}

enum RufletForcePressPhase { case start, peak, update, end }

private func pointDifference(
  _ lhs: RufletEventPoint,
  _ rhs: RufletEventPoint
) -> RufletEventPoint {
  RufletEventPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

private func currentMilliseconds() -> Int64 {
  Int64(Date().timeIntervalSince1970 * 1_000)
}

#if os(iOS)
import UIKit

private struct RufletPlatformGestureMonitor: UIViewRepresentable {
  let coordinator: RufletGestureEventCoordinator

  func makeUIView(context: Context) -> RufletGestureInstallerView {
    let view = RufletGestureInstallerView()
    view.coordinator = coordinator
    return view
  }

  func updateUIView(_ view: RufletGestureInstallerView, context: Context) {
    view.coordinator = coordinator
    view.installIfNeeded()
  }

  static func dismantleUIView(_ view: RufletGestureInstallerView, coordinator: ()) {
    view.uninstall()
  }
}

private final class RufletGestureInstallerView: UIView, UIGestureRecognizerDelegate {
  weak var coordinator: RufletGestureEventCoordinator?
  private weak var installedView: UIView?
  private var recognizer: RufletTouchTrackingRecognizer?

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    DispatchQueue.main.async { [weak self] in self?.installIfNeeded() }
  }

  func installIfNeeded() {
    guard recognizer == nil, let target = superview else { return }
    let recognizer = RufletTouchTrackingRecognizer()
    recognizer.cancelsTouchesInView = false
    recognizer.delaysTouchesBegan = false
    recognizer.delaysTouchesEnded = false
    recognizer.delegate = self
    recognizer.callback = { [weak self, weak target] phase, changedTouches, activeTouches, event in
      guard let self, let target else { return }
      self.handle(
        phase: phase, changedTouches: changedTouches, activeTouches: activeTouches,
        event: event, in: target)
    }
    target.addGestureRecognizer(recognizer)
    installedView = target
    self.recognizer = recognizer
  }

  func uninstall() {
    if let recognizer { installedView?.removeGestureRecognizer(recognizer) }
    recognizer = nil
    installedView = nil
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool { true }

  private func handle(
    phase: RufletTouchTrackingRecognizer.Phase,
    changedTouches: Set<UITouch>,
    activeTouches: Set<UITouch>,
    event: UIEvent?,
    in target: UIView
  ) {
    guard let coordinator else { return }
    if phase == .began, trackedTouch == nil { trackedTouch = changedTouches.first }
    if let touch = trackedTouch, changedTouches.contains(touch) {
      handleTrackedTouch(touch, phase: phase, event: event, in: target, coordinator: coordinator)
      if phase == .ended || phase == .cancelled { trackedTouch = nil }
    }

    let requiredTouches = coordinator.control.integer("multi_tap_touches", default: 0) ?? 0
    if requiredTouches > 0 {
      switch phase {
      case .began where activeTouches.count == requiredTouches:
        coordinator.multiTouchChanged(correctNumberOfTouches: true)
      case .ended, .cancelled:
        coordinator.multiTouchChanged(correctNumberOfTouches: false)
      default:
        break
      }
    }
    updateScale(touches: activeTouches, phase: phase, in: target, coordinator: coordinator)
  }

  private var trackedTouch: UITouch?

  private func handleTrackedTouch(
    _ touch: UITouch,
    phase: RufletTouchTrackingRecognizer.Phase,
    event: UIEvent?,
    in target: UIView,
    coordinator: RufletGestureEventCoordinator
  ) {
    let local = touch.location(in: target)
    let global = target.convert(local, to: target.window)
    let deviceKind: String
    switch touch.type {
    case .pencil: deviceKind = "stylus"
    case .indirect, .indirectPointer: deviceKind = "mouse"
    default: deviceKind = "touch"
    }
    let sample = RufletGesturePointerSample(
      local: .init(local), global: .init(global), deviceKind: deviceKind,
      timestamp: touch.timestamp, pressure: Double(touch.force),
      pressureMinimum: 0, pressureMaximum: Double(max(touch.maximumPossibleForce, 1)),
      device: touch.hash)
    let button: RufletGesturePointerButton
    if event?.buttonMask.contains(.button(2)) == true { button = .tertiary }
    else if event?.buttonMask.contains(.secondary) == true { button = .secondary }
    else { button = .primary }

    switch phase {
    case .began:
      coordinator.pointerDown(sample, button: button)
      if touch.maximumPossibleForce > 0, touch.force > 0 {
        coordinator.forcePress(.start, sample: sample)
      }
    case .moved:
      coordinator.pointerMove(sample, button: button)
      if touch.maximumPossibleForce > 0, touch.force > 0 {
        coordinator.forcePress(.update, sample: sample)
        if touch.force >= touch.maximumPossibleForce {
          coordinator.forcePress(.peak, sample: sample)
        }
      }
    case .ended:
      coordinator.pointerUp(sample, button: button)
      if touch.maximumPossibleForce > 0, touch.force > 0 {
        coordinator.forcePress(.end, sample: sample)
      }
    case .cancelled:
      coordinator.pointerCancel(button: button)
    }
  }

  private var initialScaleDistance: CGFloat?
  private var initialScaleAngle: CGFloat?
  private var previousScaleCenter: CGPoint?

  private func updateScale(
    touches: Set<UITouch>,
    phase: RufletTouchTrackingRecognizer.Phase,
    in target: UIView,
    coordinator: RufletGestureEventCoordinator
  ) {
    let values = Array(touches.prefix(2))
    guard values.count == 2 else {
      if phase == .ended || phase == .cancelled {
        coordinator.scaleEnded(pointerCount: touches.count)
        initialScaleDistance = nil
        initialScaleAngle = nil
        previousScaleCenter = nil
      }
      return
    }
    let first = values[0].location(in: target)
    let second = values[1].location(in: target)
    let center = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    let global = target.convert(center, to: target.window)
    let distance = hypot(second.x - first.x, second.y - first.y)
    let angle = atan2(second.y - first.y, second.x - first.x)
    if initialScaleDistance == nil {
      initialScaleDistance = max(distance, 0.001)
      initialScaleAngle = angle
      previousScaleCenter = center
      coordinator.scaleStarted(
        localFocalPoint: .init(center), globalFocalPoint: .init(global),
        pointerCount: 2, timestamp: values[0].timestamp)
    } else {
      coordinator.scaleUpdated(
        localFocalPoint: .init(center), globalFocalPoint: .init(global),
        pointerCount: 2,
        scale: Double(distance / (initialScaleDistance ?? distance)),
        rotation: Double(angle - (initialScaleAngle ?? angle)),
        timestamp: values[0].timestamp)
      previousScaleCenter = center
    }
  }
}

private final class RufletTouchTrackingRecognizer: UIGestureRecognizer {
  enum Phase { case began, moved, ended, cancelled }
  var callback: ((Phase, Set<UITouch>, Set<UITouch>, UIEvent?) -> Void)?
  private var activeTouches: Set<UITouch> = []

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    activeTouches.formUnion(touches)
    state = state == .possible ? .began : .changed
    callback?(.began, touches, activeTouches, event)
  }
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    state = .changed
    callback?(.moved, touches, activeTouches, event)
  }
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    activeTouches.subtract(touches)
    callback?(.ended, touches, activeTouches, event)
    state = activeTouches.isEmpty ? .ended : .changed
  }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    activeTouches.subtract(touches)
    callback?(.cancelled, touches, activeTouches, event)
    state = activeTouches.isEmpty ? .cancelled : .changed
  }
  override func reset() { activeTouches.removeAll() }
}

#elseif os(macOS)
import AppKit

private struct RufletPlatformGestureMonitor: NSViewRepresentable {
  let coordinator: RufletGestureEventCoordinator

  func makeNSView(context: Context) -> RufletMacGestureMonitorView {
    let view = RufletMacGestureMonitorView()
    view.coordinator = coordinator
    return view
  }
  func updateNSView(_ view: RufletMacGestureMonitorView, context: Context) {
    view.coordinator = coordinator
    view.installIfNeeded()
  }
  static func dismantleNSView(_ view: RufletMacGestureMonitorView, coordinator: ()) {
    view.uninstall()
  }
}

private final class RufletMacGestureMonitorView: NSView {
  weak var coordinator: RufletGestureEventCoordinator?
  private weak var installedView: NSView?
  private var monitor: Any?
  private var pointerInside = false
  private var activeButtons: Set<RufletGesturePointerButton> = []

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    installIfNeeded()
  }

  func installIfNeeded() {
    guard monitor == nil, window != nil, let target = superview else { return }
    installedView = target
    window?.acceptsMouseMovedEvents = true
    let mask: NSEvent.EventTypeMask = [
      .leftMouseDown, .leftMouseDragged, .leftMouseUp,
      .rightMouseDown, .rightMouseDragged, .rightMouseUp,
      .otherMouseDown, .otherMouseDragged, .otherMouseUp,
      .mouseMoved, .scrollWheel, .magnify, .rotate, .pressure,
    ]
    monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
      self?.handle(event)
      return event
    }
  }

  func uninstall() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    installedView = nil
  }

  private func handle(_ event: NSEvent) {
    guard let coordinator, let target = installedView, event.window === target.window else { return }
    // NSViewRepresentable backgrounds can keep a zero intrinsic frame even
    // though SwiftUI proposes the full GestureDetector area. Its superview is
    // the actual gesture surface, so hit-test in that coordinate space. This
    // is essential when the child is an NSTextView/other native platform view.
    let local = target.convert(event.locationInWindow, from: nil)
    let inside = target.bounds.contains(local)
    let global = event.locationInWindow
    let sample = RufletGesturePointerSample(
      local: .init(local), global: .init(global), deviceKind: "mouse",
      timestamp: event.timestamp, pressure: Double(event.pressure),
      pressureMinimum: 0, pressureMaximum: 1, device: event.deviceID)

    if inside && !pointerInside {
      pointerInside = true
      coordinator.hoverEntered(sample)
    } else if !inside && pointerInside {
      pointerInside = false
      coordinator.hoverExited(sample)
    } else if inside && event.type == .mouseMoved {
      coordinator.hoverMoved(sample)
    }
    guard inside || !activeButtons.isEmpty else { return }

    switch event.type {
    case .leftMouseDown:
      down(.primary, sample: sample)
      if event.clickCount >= 2 {
        // NSTextView and other platform children consume mouse-up inside an
        // AppKit tracking loop, but the second mouse-down still carries
        // AppKit's authoritative click count. Defer emission until that loop
        // returns so the event has the same completed-click ordering as Flet.
        DispatchQueue.main.async { [weak coordinator] in coordinator?.nativeDoubleTap() }
      }
    case .leftMouseDragged: coordinator.pointerMove(sample, button: .primary)
    case .leftMouseUp: up(.primary, sample: sample)
    case .rightMouseDown:
      down(.secondary, sample: sample)
      coordinator.rightPanStarted(sample)
    case .rightMouseDragged:
      coordinator.pointerMove(sample, button: .secondary)
      coordinator.rightPanMoved(sample)
    case .rightMouseUp:
      up(.secondary, sample: sample)
      coordinator.rightPanEnded(sample)
    case .otherMouseDown: down(.tertiary, sample: sample)
    case .otherMouseDragged: coordinator.pointerMove(sample, button: .tertiary)
    case .otherMouseUp: up(.tertiary, sample: sample)
    case .scrollWheel:
      let delta = RufletEventPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY)
      coordinator.scroll(sample, delta: delta)
      coordinator.trackpadScrolled(
        sample, delta: delta,
        ended: event.phase == .ended || event.phase == .cancelled)
    case .magnify:
      let scale = 1 + Double(event.magnification)
      coordinator.scaleUpdated(
        localFocalPoint: sample.local, globalFocalPoint: sample.global,
        pointerCount: 2, scale: scale, rotation: 0, timestamp: event.timestamp)
      if event.phase == .ended || event.phase == .cancelled { coordinator.scaleEnded(pointerCount: 0) }
    case .rotate:
      coordinator.scaleUpdated(
        localFocalPoint: sample.local, globalFocalPoint: sample.global,
        pointerCount: 2, scale: 1, rotation: Double(event.rotation) * .pi / 180,
        timestamp: event.timestamp)
      if event.phase == .ended || event.phase == .cancelled { coordinator.scaleEnded(pointerCount: 0) }
    case .pressure:
      let phase: RufletForcePressPhase
      switch event.stage {
      case 1: phase = .start
      case 2: phase = .peak
      default: phase = event.pressure > 0 ? .update : .end
      }
      coordinator.forcePress(phase, sample: sample)
    default: break
    }
  }

  private func down(
    _ button: RufletGesturePointerButton,
    sample: RufletGesturePointerSample
  ) {
    activeButtons.insert(button)
    coordinator?.pointerDown(sample, button: button)
  }

  private func up(
    _ button: RufletGesturePointerButton,
    sample: RufletGesturePointerSample
  ) {
    activeButtons.remove(button)
    coordinator?.pointerUp(sample, button: button)
  }
}
#endif
