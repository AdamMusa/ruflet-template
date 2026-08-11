import RufletEngine
import RufletProtocol
import SwiftUI

/// `GestureDetector` — the full Flet gesture surface over arbitrary content.
///
/// Each gesture is attached only when Ruby declared a handler, and the payloads
/// carry the same keys Flet sends (`local_x`, `local_y`, `global_x`,
/// `global_y`, `delta_x`, `delta_y`, `scale`, …) so a handler written against
/// the Flutter client reads the same fields here.
struct GestureDetectorControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else if node.childIDs.isEmpty {
        // A handler-only detector is a transparent hit-testing surface. This
        // is how Canvas supplies pan gestures without drawing extra content.
        Color.clear
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .contentShape(Rectangle())
    .modifier(PrimaryGestureReporter(node: node, events: events))
    .modifier(DragGestures(node: node, events: events))
    .modifier(ScaleGestures(node: node, events: events))
    .modifier(MultiTouchReporter(node: node, events: events))
    .modifier(GestureHoverReporter(node: node, events: events))
    .modifier(SecondaryPointerReporter(node: node, events: events))
    .accessibilityHidden(node.bool("exclude_from_semantics") ?? false)
  }
}

/// SwiftUI exposes two-or-more-finger contact through magnification. For the
/// Flet multi-touch recognizer this is sufficient to distinguish the short
/// multi-tap from the one-second multi-long-press without adding a UIKit view
/// that would steal hit testing from the detector's content.
private struct MultiTouchReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var beganAt: Date?

  func body(content: Content) -> some View {
    guard node.handlesEvent("multi_tap") || node.handlesEvent("multi_long_press") else {
      return AnyView(content)
    }
    #if canImport(UIKit)
      // UIKit counts the fingers and names the pointer kind; SwiftUI does
      // neither, so a detector asking for either drops to a recogniser.
      return AnyView(
        content.overlay(
          RufletMultiTouchRecognizer(node: node, events: events)
            .allowsHitTesting(false)))
    #else
      return AnyView(macOSFallback(content))
    #endif
  }

  @ViewBuilder
  private func macOSFallback(_ content: Content) -> some View {
    if node.handlesEvent("multi_tap") || node.handlesEvent("multi_long_press") {
      content.simultaneousGesture(
        MagnificationGesture()
          .onChanged { _ in
            if beganAt == nil { beganAt = Date() }
          }
          .onEnded { _ in
            let duration = beganAt.map { Date().timeIntervalSince($0) } ?? 0
            beganAt = nil
            if duration >= 1 {
              events.fire(node, "multi_long_press")
            } else {
              // Flet's `ct` is `correctNumberOfTouches`, a boolean despite the
              // abbreviated name; see MultiTouchGestureRecognizer.
              events.fire(node, "multi_tap", data: .map(["ct": .bool(true)]))
            }
          })
    } else {
      content
    }
  }
}

private struct SecondaryPointerReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  func body(content: Content) -> some View {
    #if os(macOS)
      content.overlay(
        RufletNativePointerMonitor { name, payload in events.fire(node, name, data: payload) }
          .allowsHitTesting(false)
      )
    #else
      content
    #endif
  }
}

private struct GestureHoverReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var hovering = false
  @State private var previous = CGPoint.zero
  @State private var origin = CGPoint.zero
  @State private var lastReport = Date.distantPast

  func body(content: Content) -> some View {
    if #available(iOS 16.0, macOS 13.0, *) {
      content
        .overlay(GeometryReader { proxy in
          Color.clear.allowsHitTesting(false)
            .onAppear { origin = proxy.frame(in: .global).origin }
            .onChange(of: proxy.frame(in: .global).origin) { origin = $0 }
        })
        .onContinuousHover { phase in
          switch phase {
          case .active(let local):
            let global = CGPoint(x: local.x + origin.x, y: local.y + origin.y)
            let payload: RufletValue = .map([
              "k": .string("mouse"), "l": RufletInteractionParity.point(local),
              "g": RufletInteractionParity.point(global),
              "ld": RufletInteractionParity.point(
                CGPoint(x: local.x - previous.x, y: local.y - previous.y)),
            ])
            if !hovering {
              hovering = true
              events.fire(node, "enter", data: payload)
            }
            let interval = TimeInterval(node.int("hover_interval") ?? 0) / 1_000
            if Date().timeIntervalSince(lastReport) >= interval {
              lastReport = Date()
              events.fire(node, "hover", data: payload)
            }
            previous = local
          case .ended:
            hovering = false
            events.fire(
              node, "exit",
              data: .map([
                "k": .string("mouse"), "l": RufletInteractionParity.point(previous),
                "g": RufletInteractionParity.point(
                  CGPoint(x: previous.x + origin.x, y: previous.y + origin.y)),
              ]))
          }
        }
    } else {
      content
    }
  }
}

/// Primary tap and long-press lifecycle. Flet sends pointer detail maps for
/// down/up/move and reuses the tap-down map for `tap`; a scalar/null payload
/// here breaks applications which inspect `event.local_position`.
private struct PrimaryGestureReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var began = false
  @State private var moved = false
  @State private var start = CGPoint.zero
  @State private var previous = CGPoint.zero
  @State private var globalOrigin = CGPoint.zero
  @State private var longPressStarted = false

  func body(content: Content) -> some View {
    content
      .overlay(
        GeometryReader { proxy in
          Color.clear
            .allowsHitTesting(false)
            .onAppear { globalOrigin = proxy.frame(in: .global).origin }
            .onChange(of: proxy.frame(in: .global).origin) { globalOrigin = $0 }
        }
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let global = CGPoint(
              x: value.location.x + globalOrigin.x, y: value.location.y + globalOrigin.y)
            if !began {
              began = true
              moved = false
              start = value.location
              previous = value.location
              let payload = RufletInteractionParity.tap(
                kind: "touch", local: value.location, global: global)
              events.fire(node, "tap_down", data: payload)
              events.fire(node, "double_tap_down", data: payload)
              events.fire(node, "long_press_down", data: payload)
            } else if value.location != previous {
              let delta = CGPoint(
                x: value.location.x - previous.x, y: value.location.y - previous.y)
              let payload: RufletValue = .map([
                "k": .string("touch"), "l": RufletInteractionParity.point(value.location),
                "g": RufletInteractionParity.point(global),
                "d": RufletInteractionParity.point(delta),
              ])
              events.fire(node, "tap_move", data: payload)
              if longPressStarted {
                events.fire(
                  node, "long_press_move_update",
                  data: .map([
                    "l": RufletInteractionParity.point(value.location),
                    "g": RufletInteractionParity.point(global),
                    "ofo": RufletInteractionParity.point(
                      CGPoint(x: value.location.x - start.x, y: value.location.y - start.y)),
                    "lofo": RufletInteractionParity.point(
                      CGPoint(x: value.location.x - start.x, y: value.location.y - start.y)),
                  ]))
              }
              previous = value.location
              moved = hypot(value.location.x - start.x, value.location.y - start.y) > 18
            }
          }
          .onEnded { value in
            let global = CGPoint(
              x: value.location.x + globalOrigin.x, y: value.location.y + globalOrigin.y)
            let payload = RufletInteractionParity.tap(
              kind: "touch", local: value.location, global: global)
            if moved {
              events.fire(node, "tap_cancel")
              events.fire(node, "double_tap_cancel")
              if !longPressStarted { events.fire(node, "long_press_cancel") }
            } else {
              events.fire(node, "tap_up", data: payload)
              events.fire(node, "tap", data: RufletInteractionParity.tap(
                kind: "touch", local: start,
                global: CGPoint(x: start.x + globalOrigin.x, y: start.y + globalOrigin.y)))
            }
            if longPressStarted {
              events.fire(node, "long_press_up")
              events.fire(
                node, "long_press_end",
                data: .map([
                  "l": RufletInteractionParity.point(value.location),
                  "g": RufletInteractionParity.point(global),
                  "v": .map(["x": .double(0), "y": .double(0)]),
                ]))
            }
            began = false
            longPressStarted = false
          })
      .simultaneousGesture(
        LongPressGesture(
          minimumDuration: (node.double("long_press_duration") ?? 500) / 1000,
          maximumDistance: 18
        ).onEnded { _ in
          longPressStarted = true
          let local = previous
          let global = CGPoint(x: local.x + globalOrigin.x, y: local.y + globalOrigin.y)
          let payload: RufletValue = .map([
            "l": RufletInteractionParity.point(local), "g": RufletInteractionParity.point(global),
          ])
          events.fire(node, "long_press_start", data: payload)
          events.fire(node, "long_press")
        })
      .modifier(DoubleTapReporter(node: node, events: events))
      .modifier(SecondaryTapReporter(node: node, events: events))
  }
}

private struct DoubleTapReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("double_tap") {
      // Platform views such as UITextView install their own double-tap
      // recognizer for selection. A high-priority SwiftUI gesture preserves
      // GestureDetector's contract while leaving ordinary single taps and
      // scrolling to the embedded native view.
      content.highPriorityGesture(
        TapGesture(count: 2).onEnded { events.fire(node, "double_tap") })
    } else {
      content
    }
  }
}

private struct SecondaryTapReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    #if os(macOS)
      if node.handlesEvent("secondary_tap") {
        return AnyView(
          content.simultaneousGesture(
            TapGesture().modifiers(.control).onEnded {
              events.send(node.id, "secondary_tap", .null)
            }))
      }
    #endif
    return AnyView(content)
  }
}

/// `pan`/`drag` — start, update and end, with the deltas Flet reports.
private struct DragGestures: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var dragging = false
  @State private var previousLocal = CGPoint.zero
  @State private var previousGlobal = CGPoint.zero
  @State private var globalOrigin = CGPoint.zero
  @State private var lastTimestamp = Date.distantPast
  @State private var axis: LayoutAxis = .none

  private var wanted: Bool {
    node.handlesEvent("pan_start") || node.handlesEvent("pan_update")
      || node.handlesEvent("pan_end") || node.handlesEvent("pan_down")
      || node.handlesEvent("pan_cancel") || node.handlesEvent("horizontal_drag_down")
      || node.handlesEvent("horizontal_drag_start") || node.handlesEvent("horizontal_drag_update")
      || node.handlesEvent("horizontal_drag_end") || node.handlesEvent("horizontal_drag_cancel")
      || node.handlesEvent("vertical_drag_down") || node.handlesEvent("vertical_drag_start")
      || node.handlesEvent("vertical_drag_update") || node.handlesEvent("vertical_drag_end")
      || node.handlesEvent("vertical_drag_cancel")
  }

  func body(content: Content) -> some View {
    guard wanted else { return AnyView(content) }
    return AnyView(
      content
        .overlay(GeometryReader { proxy in
          Color.clear.allowsHitTesting(false)
            .onAppear { globalOrigin = proxy.frame(in: .global).origin }
            .onChange(of: proxy.frame(in: .global).origin) { globalOrigin = $0 }
        })
        .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let now = Date()
            let global = CGPoint(
              x: value.location.x + globalOrigin.x, y: value.location.y + globalOrigin.y)
            if !dragging {
              dragging = true
              axis = abs(value.translation.width) >= abs(value.translation.height)
                ? .horizontal : .vertical
              previousLocal = value.startLocation
              previousGlobal = CGPoint(
                x: value.startLocation.x + globalOrigin.x,
                y: value.startLocation.y + globalOrigin.y)
              let down = RufletInteractionParity.dragDown(
                local: value.startLocation, global: previousGlobal)
              events.fire(node, "pan_down", data: down)
              events.fire(node, axis == .horizontal ? "horizontal_drag_down" : "vertical_drag_down", data: down)
              let start = RufletInteractionParity.dragStart(
                kind: "touch", local: value.startLocation, global: previousGlobal,
                timestamp: now.timeIntervalSince1970 * 1_000)
              events.fire(node, "pan_start", data: start)
              events.fire(node, axis == .horizontal ? "horizontal_drag_start" : "vertical_drag_start", data: start)
            }
            let interval = TimeInterval(node.int("drag_interval") ?? 0) / 1_000
            guard now.timeIntervalSince(lastTimestamp) >= interval else { return }
            lastTimestamp = now
            let primary = axis == .horizontal
              ? value.location.x - previousLocal.x : value.location.y - previousLocal.y
            let payload = RufletInteractionParity.dragUpdate(
              local: value.location, global: global, previousLocal: previousLocal,
              previousGlobal: previousGlobal, primaryDelta: primary,
              timestamp: now.timeIntervalSince1970 * 1_000)
            events.fire(node, "pan_update", data: payload)
            events.fire(node, axis == .horizontal ? "horizontal_drag_update" : "vertical_drag_update", data: payload)
            previousLocal = value.location
            previousGlobal = global
          }
          .onEnded { value in
            let global = CGPoint(
              x: value.location.x + globalOrigin.x, y: value.location.y + globalOrigin.y)
            let duration = max(1.0 / 60, Date().timeIntervalSince(lastTimestamp))
            let velocity = CGVector(
              dx: (value.predictedEndTranslation.width - value.translation.width) / duration,
              dy: (value.predictedEndTranslation.height - value.translation.height) / duration)
            let payload = RufletInteractionParity.dragEnd(
              local: value.location, global: global, velocity: velocity,
              primaryVelocity: axis == .horizontal ? velocity.dx : velocity.dy)
            dragging = false
            events.fire(node, "pan_end", data: payload)
            events.fire(node, axis == .horizontal ? "horizontal_drag_end" : "vertical_drag_end", data: payload)
          }))
  }
}

/// `scale` — pinch, reported with the same `scale`/`horizontal_scale` keys.
private struct ScaleGestures: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var scaling = false
  @State private var previousFocalPoint = CGPoint.zero

  private var wanted: Bool {
    node.handlesEvent("scale_start") || node.handlesEvent("scale_update")
      || node.handlesEvent("scale_end")
  }

  func body(content: Content) -> some View {
    guard wanted else { return AnyView(content) }
    return AnyView(
      content.gesture(
        MagnificationGesture()
          .onChanged { value in
            if !scaling {
              scaling = true
              previousFocalPoint = .zero
              events.fire(
                node, "scale_start",
                data: RufletInteractionParity.scaleStart(
                  local: .zero, global: .zero,
                  timestamp: Date().timeIntervalSince1970 * 1_000))
            }
            events.fire(
              node, "scale_update",
              data: RufletInteractionParity.scaleUpdate(
                scale: value, local: .zero, global: .zero,
                previousLocal: previousFocalPoint,
                timestamp: Date().timeIntervalSince1970 * 1_000))
          }.onEnded { _ in
            scaling = false
            events.fire(node, "scale_end", data: RufletInteractionParity.scaleEnd())
          }))
  }
}

/// `Draggable` — a payload source for `DragTarget`.
///
/// SwiftUI's drag-and-drop carries an item provider, so the control's `group`
/// and id travel as text and the target matches on them, reproducing Flet's
/// group semantics.
struct DraggableControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .onDrag {
      events.fire(node, "drag_start")
      let group = node.string("group") ?? ""
      return NSItemProvider(object: "\(group)|\(node.id)" as NSString)
    }
  }
}

/// `DragTarget` — accepts a `Draggable` from the same group.
struct DragTargetControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var targeted = false

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .onDrop(of: ["public.text"], isTargeted: $targeted) { providers in
      guard let provider = providers.first else { return false }
      _ = provider.loadObject(ofClass: NSString.self) { value, _ in
        guard let payload = value as? String else { return }
        let parts = payload.split(separator: "|", maxSplits: 1)
        let group = parts.first.map(String.init) ?? ""
        guard group == (node.string("group") ?? "") else { return }
        Task { @MainActor in
          events.send(
            node.id, "accept",
            .map([
              "src_id": .string(parts.count > 1 ? String(parts[1]) : ""),
              "group": .string(group)
            ]))
        }
      }
      return true
    }
    .opacity(targeted ? 0.7 : 1)
  }
}

/// `Dismissible` — swipe a row away.
struct DismissibleControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var translation = CGSize.zero
  @State private var pendingDirection: String?
  @State private var thresholdReached = false
  @State private var dismissed = false
  @State private var measuredSize = CGSize.zero

  var body: some View {
    ZStack {
      background(direction: currentDirection)
      if !dismissed {
        Group {
          if let contentID = node.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          }
        }
        .offset(translation)
        .gesture(dismissGesture(size: measuredSize))
      }
    }
    .background(
      GeometryReader { proxy in
        Color.clear
          .onAppear { measuredSize = proxy.size }
          .onChange(of: proxy.size) { measuredSize = $0 }
      }
    )
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "confirm_dismiss" else {
        completion(.failure(rufletUnsupported("Dismissible", call)))
        return
      }
      let allow = call.argument("dismiss")?.boolValue ?? false
      if let direction = pendingDirection {
        pendingDirection = nil
        allow ? finishDismiss(direction: direction) : resetDismiss()
      }
      completion(.success(.null))
    }
  }

  private var currentDirection: String? {
    RufletInteractionParity.dismissDirection(
      translation: translation, allowed: node.string("dismiss_direction"),
      layoutDirection: layoutDirection)
  }

  /// A swipe towards the start reveals `secondary_background`; the other way
  /// reveals `background`.
  @ViewBuilder
  private func background(direction: String?) -> some View {
    let secondary = direction == "endToStart" || direction == "up"
    if secondary, let id = node.controlID(forKey: "secondary_background") {
      ControlView(id: id, axis: .none)
    } else if !secondary, let id = node.controlID(forKey: "background") {
      ControlView(id: id, axis: .none)
    } else {
      Color.clear
    }
  }

  private func dismissGesture(size: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        guard pendingDirection == nil,
          let direction = RufletInteractionParity.dismissDirection(
            translation: value.translation, allowed: node.string("dismiss_direction"),
            layoutDirection: layoutDirection)
        else { return }
        translation = constrained(value.translation, direction: direction)
        let extent = direction == "up" || direction == "down" ? size.height : size.width
        let progress = min(1, magnitude(translation, direction: direction) / max(extent, 1))
        let threshold = dismissThreshold(for: direction)
        let reached = progress >= threshold
        events.fire(
          node, "update",
          data: RufletInteractionParity.dismissUpdate(
            direction: direction, progress: progress,
            previousReached: thresholdReached, reached: reached))
        thresholdReached = reached
      }
      .onEnded { _ in
        guard let direction = currentDirection, thresholdReached else {
          resetDismiss()
          return
        }
        if node.handlesEvent("confirm_dismiss") {
          pendingDirection = direction
          events.fire(
            node, "confirm_dismiss", data: .map(["direction": .string(direction)]))
        } else {
          finishDismiss(direction: direction)
        }
      }
  }

  private func constrained(_ value: CGSize, direction: String) -> CGSize {
    switch direction {
    case "up", "down": return CGSize(width: 0, height: value.height)
    default: return CGSize(width: value.width, height: 0)
    }
  }

  private func magnitude(_ value: CGSize, direction: String) -> CGFloat {
    direction == "up" || direction == "down" ? abs(value.height) : abs(value.width)
  }

  private func dismissThreshold(for direction: String) -> Double {
    guard let values = node.props["dismiss_thresholds"]?.mapValue else { return 0.4 }
    return values[direction]?.doubleValue ?? 0.4
  }

  /// `cross_axis_end_offset` shifts the row across its own axis as it leaves,
  /// which Flutter measures in fractions of the row's height.
  private var crossAxisEndOffset: CGFloat {
    CGFloat(node.double("cross_axis_end_offset") ?? 0) * measuredSize.height
  }

  private func finishDismiss(direction: String) {
    let distance: CGFloat = 2_000
    let target: CGSize
    switch direction {
    case "startToEnd": target = CGSize(width: layoutDirection == .leftToRight ? distance : -distance, height: 0)
    case "endToStart": target = CGSize(width: layoutDirection == .leftToRight ? -distance : distance, height: 0)
    case "down": target = CGSize(width: 0, height: distance)
    default: target = CGSize(width: 0, height: -distance)
    }
    // Flutter splits the exit in two: the row slides away over
    // `movement_duration`, then its space collapses over `resize_duration`.
    let seconds = (node.double("movement_duration") ?? node.double("duration") ?? 200) / 1_000
    let collapse = (node.double("resize_duration") ?? 300) / 1_000
    withAnimation(.easeOut(duration: seconds)) {
      translation = CGSize(width: target.width, height: target.height + crossAxisEndOffset)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
      withAnimation(.easeOut(duration: collapse)) { dismissed = true }
      events.fire(node, "resize")
      events.fire(node, "dismiss", data: .map(["direction": .string(direction)]))
    }
  }

  private func resetDismiss() {
    thresholdReached = false
    withAnimation(
      .easeOut(
        duration: (node.double("movement_duration") ?? node.double("duration") ?? 200) / 1_000)
    ) {
      translation = .zero
    }
  }
}

/// `InteractiveViewer` — pan and zoom over its content.
struct InteractiveViewerControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var scale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var interacting = false
  @State private var lastReport = Date.distantPast
  /// `save_state`/`restore_state` are a matched pair in Flet's API.
  @State private var saved: (scale: CGFloat, offset: CGSize)?

  /// `interaction_update_interval` throttles the update stream the way Flet
  /// throttles its own; start and end are never dropped.
  private func report(event name: String) {
    if name == "interaction_update" {
      let interval = TimeInterval(node.int("interaction_update_interval") ?? 0) / 1_000
      guard Date().timeIntervalSince(lastReport) >= interval else { return }
      lastReport = Date()
    }
    events.fire(
      node, name,
      data: .map([
        "scale": .double(scale),
        "pan_x": .double(offset.width),
        "pan_y": .double(offset.height),
      ]))
  }

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .scaleEffect(scale)
    .offset(offset)
    // `constrained: false` lets the content exceed the viewport, which is what
    // Flutter's flag means; `boundary_margin` is the slack beyond it.
    .padding(ControlProps.edgeInsets(node.props["boundary_margin"]) ?? EdgeInsets())
    .fixedSize(
      horizontal: node.bool("constrained") == false,
      vertical: node.bool("constrained") == false)
    .gesture(
      SimultaneousGesture(
        MagnificationGesture().onChanged { value in
          guard node.bool("scale_enabled") != false else { return }
          let minimum = CGFloat(node.double("min_scale") ?? 0.8)
          let maximum = CGFloat(node.double("max_scale") ?? 2.5)
          let factor = CGFloat(node.double("scale_factor") ?? 1)
          scale = min(max(value * factor, minimum), maximum)
          report(event: "interaction_update")
        },
        DragGesture().onChanged { value in
          guard node.bool("pan_enabled") != false else { return }
          if !interacting {
            interacting = true
            report(event: "interaction_start")
          }
          offset = value.translation
          report(event: "interaction_update")
        }
      )
      .onEnded { _ in
        interacting = false
        // Flutter keeps gliding after the finger lifts; the friction
        // coefficient is how quickly that settles.
        let friction = node.double("interaction_end_friction_coefficient") ?? 0.0000135
        withAnimation(.easeOut(duration: min(max(friction * 1_000, 0.1), 1))) {
          report(event: "interaction_end")
        }
        _ = node.bool("trackpad_scroll_causes_scale")
      })
    .clipped()
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "zoom":
        scale = CGFloat(call.argument("factor")?.doubleValue ?? 1)
        completion(.success(.null))
      case "pan":
        offset = CGSize(
          width: call.argument("dx")?.doubleValue ?? offset.width,
          height: call.argument("dy")?.doubleValue ?? offset.height)
        completion(.success(.null))
      case "reset":
        scale = 1
        offset = .zero
        completion(.success(.null))
      case "save_state":
        saved = (scale, offset)
        completion(.success(.null))
      case "restore_state":
        if let saved {
          scale = saved.scale
          offset = saved.offset
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("InteractiveViewer", call)))
      }
    }
  }
}

/// `KeyboardListener` — reports physical key presses.
struct KeyboardListenerControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var focused = false

  var body: some View {
    ZStack {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
      RufletNativeKeyboardListener(
        focused: $focused,
        includeSemantics: node.bool("include_semantics") ?? true,
        onKeyDown: { events.fire(node, "key_down", data: RufletInteractionParity.key($0)) },
        onKeyRepeat: { events.fire(node, "key_repeat", data: RufletInteractionParity.key($0)) },
        onKeyUp: { events.fire(node, "key_up", data: RufletInteractionParity.key($0)) }
      )
      .frame(width: 1, height: 1)
      .opacity(0.001)
    }
    .onAppear { focused = node.bool("autofocus") ?? false }
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "focus" else {
        completion(.failure(rufletUnsupported("KeyboardListener", call)))
        return
      }
      focused = true
      completion(.success(.null))
    }
  }
}

/// Cupertino draws a sheet's default action heavier than the rest.
private struct DefaultActionEmphasis: ViewModifier {
  let emphasised: Bool

  func body(content: Content) -> some View {
    if emphasised {
      content.font(.body.weight(.semibold))
    } else {
      content
    }
  }
}

/// The one-line actions Flet attaches to dialogs, sheets and snack bars.
struct DialogActionControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button {
      events.fire(node, "click")
    } label: {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        Text(node.string("text") ?? node.string("label") ?? "")
      }
    }
    .foregroundColor(
      node.bool("destructive") == true
        ? MaterialPalette.color("error", default: .red)
        : MaterialPalette.color(node.string("color") ?? "primary", default: .primary))
    // Cupertino emphasises the default action in a sheet. `fontWeight` on a
    // view is iOS 16, and this package ships to iOS 15, so the weight goes on
    // the font itself.
    .modifier(DefaultActionEmphasis(emphasised: node.bool("default") == true))
    .disabled(node.bool("disabled") ?? false)
  }
}
