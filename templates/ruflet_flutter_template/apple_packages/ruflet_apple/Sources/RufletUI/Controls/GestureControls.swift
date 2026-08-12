import RufletEngine
import RufletProtocol
import SwiftUI

/// Defaults and wire shapes pinned to Flet 0.80.5. Keeping them beside the
/// native controls makes drift from the Dart client testable without adding
/// application-specific styling or layout policy.
enum RufletGestureParity {
  static let dragGroup = "default"
  static let dismissThreshold = 0.4
  static let interactionUpdateInterval = 200
  static let interactiveMinScale = 0.8
  static let interactiveMaxScale = 2.5
  static let interactiveFriction = 0.0000135
  static let interactiveScaleFactor = 200.0

  static func dragPayload(sourceID: Int, location: CGPoint) -> RufletValue {
    .map([
      "src_id": .int(Int64(sourceID)),
      "x": .double(location.x), "y": .double(location.y),
    ])
  }

  static func mouseRegionEvents(_ node: ControlNode) -> Set<String> {
    Set(["enter", "hover", "exit"].filter(node.handlesEvent))
  }

  /// Flet serialises MouseRegion's PointerEvent with the complete compact
  /// event map, including null local delta on enter/exit. Apple hover events
  /// do not expose pressure, radius, device id, or tilt, so their native mouse
  /// constants are carried without inventing stylus measurements.
  static func mouseRegionPayload(
    local: CGPoint, global: CGPoint, previousLocal: CGPoint? = nil,
    timestamp: Double = 0
  ) -> RufletValue {
    .map([
      "k": .string("mouse"),
      "l": RufletInteractionParity.point(local),
      "g": RufletInteractionParity.point(global),
      "ts": .double(timestamp),
      "dev": .int(0),
      "ps": .double(0),
      "pMin": .double(0), "pMax": .double(1),
      "dist": .double(0), "distMax": .double(0), "size": .double(0),
      "rMj": .double(0), "rMn": .double(0), "rMin": .double(0),
      "rMax": .double(0), "or": .double(0), "tilt": .double(0),
      "ld": previousLocal.map {
        RufletInteractionParity.point(
          CGPoint(x: local.x - $0.x, y: local.y - $0.y))
      } ?? .null,
    ])
  }
}

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
    .modifier(GestureTrackpadScale(node: node, events: events))
    .accessibilityHidden(node.bool("exclude_from_semantics") ?? false)
  }
}

/// Flet's GestureDetector can convert trackpad scrolling into the same scale
/// lifecycle as a pinch while still reporting the raw pointer signal.
private struct GestureTrackpadScale: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var scale = 1.0
  @State private var active = false
  @State private var endWork: DispatchWorkItem?

  func body(content: Content) -> some View {
    #if os(macOS)
      if node.bool("trackpad_scroll_causes_scale") == true {
        content.overlay(
          RufletNativePointerMonitor { name, payload in
            guard name == "scroll",
              let delta = payload.mapValue?["sd"]?.mapValue?["y"]?.doubleValue
            else { return }
            if !active {
              active = true
              events.fire(
                node, "scale_start",
                data: RufletInteractionParity.scaleStart(
                  local: .zero, global: .zero,
                  timestamp: Date().timeIntervalSince1970 * 1_000))
            }
            scale *= exp(-delta / RufletGestureParity.interactiveScaleFactor)
            events.fire(
              node, "scale_update",
              data: RufletInteractionParity.scaleUpdate(
                scale: scale, local: .zero, global: .zero, previousLocal: .zero,
                timestamp: Date().timeIntervalSince1970 * 1_000))
            endWork?.cancel()
            let work = DispatchWorkItem {
              active = false
              scale = 1
              events.fire(node, "scale_end", data: RufletInteractionParity.scaleEnd())
            }
            endWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
          }.allowsHitTesting(false))
      } else {
        content
      }
    #else
      content
    #endif
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

  private var installsMouseRegion: Bool {
    !RufletGestureParity.mouseRegionEvents(node).isEmpty
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    if !installsMouseRegion {
      content
    } else if #available(iOS 16.0, macOS 13.0, *) {
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
            if !hovering {
              hovering = true
              previous = local
              if node.handlesEvent("enter") {
                events.fire(
                  node, "enter",
                  data: RufletGestureParity.mouseRegionPayload(
                    local: local, global: global,
                    timestamp: Date().timeIntervalSince1970 * 1_000))
              }
            }
            let interval = TimeInterval(node.int("hover_interval") ?? 0) / 1_000
            if node.handlesEvent("hover"), Date().timeIntervalSince(lastReport) >= interval {
              lastReport = Date()
              events.fire(
                node, "hover",
                data: RufletGestureParity.mouseRegionPayload(
                  local: local, global: global, previousLocal: previous,
                  timestamp: Date().timeIntervalSince1970 * 1_000))
            }
            previous = local
          case .ended:
            hovering = false
            if node.handlesEvent("exit") {
              events.fire(
                node, "exit",
                data: RufletGestureParity.mouseRegionPayload(
                  local: previous,
                  global: CGPoint(x: previous.x + origin.x, y: previous.y + origin.y),
                  timestamp: Date().timeIntervalSince1970 * 1_000))
            }
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
  @State private var longPressCancelled = false
  @State private var longPressWork: DispatchWorkItem?

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
              longPressCancelled = false
              start = value.location
              previous = value.location
              let payload = RufletInteractionParity.tap(
                kind: "touch", local: value.location, global: global)
              events.fire(node, "tap_down", data: payload)
              events.fire(node, "double_tap_down", data: payload)
              events.fire(node, "long_press_down", data: payload)
              let work = DispatchWorkItem {
                guard began, !moved else { return }
                longPressStarted = true
                let local = previous
                let global = CGPoint(x: local.x + globalOrigin.x, y: local.y + globalOrigin.y)
                events.fire(
                  node, "long_press_start",
                  data: .map([
                    "l": RufletInteractionParity.point(local),
                    "g": RufletInteractionParity.point(global),
                  ]))
                events.fire(node, "long_press")
              }
              longPressWork = work
              DispatchQueue.main.asyncAfter(
                deadline: .now() + (node.double("long_press_duration") ?? 500) / 1_000,
                execute: work)
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
              if moved, !longPressStarted, !longPressCancelled {
                longPressWork?.cancel()
                longPressCancelled = true
                events.fire(node, "long_press_cancel")
              }
            }
          }
          .onEnded { value in
            longPressWork?.cancel()
            longPressWork = nil
            let global = CGPoint(
              x: value.location.x + globalOrigin.x, y: value.location.y + globalOrigin.y)
            let payload = RufletInteractionParity.tap(
              kind: "touch", local: value.location, global: global)
            if moved {
              events.fire(node, "tap_cancel")
              events.fire(node, "double_tap_cancel")
              if !longPressStarted, !longPressCancelled { events.fire(node, "long_press_cancel") }
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
            longPressCancelled = false
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
  @State private var dragging = false

  var body: some View {
    let source = Group {
      if dragging, let draggingID = node.controlID(forKey: "content_when_dragging") {
        ControlView(id: draggingID, axis: .none)
      } else if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    if (node.int("max_simultaneous_drags") ?? 1) == 0 {
      source
    } else {
      source.onDrag {
        dragging = true
        RufletDragSession.current = .init(
          sourceID: node.id, group: node.string("group") ?? RufletGestureParity.dragGroup,
          completed: {
            dragging = false
            events.fire(
              node, "drag_complete",
              data: .string(node.string("group") ?? RufletGestureParity.dragGroup))
          })
        events.fire(node, "drag_start")
        return NSItemProvider(
          object: "\(node.string("group") ?? RufletGestureParity.dragGroup)|\(node.id)" as NSString)
      } preview: {
        if let feedbackID = node.controlID(forKey: "content_feedback") {
          ControlView(id: feedbackID, axis: .none)
        } else if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none).opacity(0.5)
        }
      }
    }
  }
}

/// SwiftUI's item provider does not expose the source view to a target. Flet's
/// drag events do, so the active native drag keeps that identity for the
/// duration of the platform drag session.
private enum RufletDragSession {
  struct Active {
    let sourceID: Int
    let group: String
    let completed: () -> Void
  }
  static var current: Active?
}

/// `DragTarget` — accepts a `Draggable` from the same group.
struct DragTargetControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var globalOrigin = CGPoint.zero

  var body: some View {
    let contentID = node.controlID(forKey: "content")
    Group {
      if RufletDragTargetSemantics.validationError(
        contentID: contentID, content: contentID.flatMap(store.node)) == nil,
        let contentID
      {
        ControlView(id: contentID, axis: .none)
      } else {
        Text(RufletDragTargetSemantics.missingContentError)
          .font(.caption).foregroundStyle(.red)
      }
    }
    .background(
      GeometryReader { proxy in
        Color.clear
          .onAppear { globalOrigin = proxy.frame(in: .global).origin }
          .onChange(of: proxy.frame(in: .global).origin) { globalOrigin = $0 }
      })
    .onDrop(
      of: ["public.text"],
      delegate: RufletDragTargetDropDelegate(
        node: node, events: events, globalOrigin: globalOrigin))
  }
}

enum RufletDragTargetSemantics {
  static let missingContentError = "DragTarget.content must be visible"

  static func validationError(contentID: Int?, content: ControlNode?) -> String? {
    RufletRequiredContent.validationError(
      contentID: contentID, content: content, message: missingContentError)
  }
}

private struct RufletDragTargetDropDelegate: DropDelegate {
  let node: ControlNode
  let events: RufletEventSink
  let globalOrigin: CGPoint

  private var active: RufletDragSession.Active? { RufletDragSession.current }
  private var accepts: Bool {
    active?.group == (node.string("group") ?? RufletGestureParity.dragGroup)
  }

  func validateDrop(info: DropInfo) -> Bool { accepts }

  func dropEntered(info: DropInfo) {
    guard let active else { return }
    events.fire(
      node, "will_accept",
      data: .map(["accept": .bool(accepts), "src_id": .int(Int64(active.sourceID))]))
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard accepts, let active else { return DropProposal(operation: .forbidden) }
    events.fire(node, "move", data: payload(active, at: info.location))
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    guard let active else { return }
    events.fire(
      node, "leave", data: .map(["src_id": .int(Int64(active.sourceID))]))
  }

  func performDrop(info: DropInfo) -> Bool {
    guard accepts, let active else { return false }
    events.fire(node, "accept", data: payload(active, at: info.location))
    active.completed()
    RufletDragSession.current = nil
    return true
  }

  private func payload(_ active: RufletDragSession.Active, at point: CGPoint) -> RufletValue {
    RufletGestureParity.dragPayload(
      sourceID: active.sourceID,
      location: CGPoint(x: point.x + globalOrigin.x, y: point.y + globalOrigin.y))
  }
}

/// `Dismissible` — swipe a row away.
struct DismissibleControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var translation = CGSize.zero
  @State private var pendingDirection: String?
  @State private var confirmTimeout: DispatchWorkItem?
  @State private var thresholdReached = false
  @State private var dismissed = false
  @State private var collapsing = false
  @State private var dismissedDirection: String?
  @State private var measuredSize = CGSize.zero

  var body: some View {
    dismissibleBody
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "confirm_dismiss" else {
        completion(.failure(rufletUnsupported("Dismissible", call)))
        return
      }
      let allow = call.argument("dismiss")?.boolValue ?? false
      if let direction = pendingDirection {
        confirmTimeout?.cancel()
        confirmTimeout = nil
        pendingDirection = nil
        allow ? finishDismiss(direction: direction) : resetDismiss()
      }
      completion(.success(.null))
    }
    .onDisappear {
      confirmTimeout?.cancel()
      confirmTimeout = nil
    }
  }

  @ViewBuilder
  private var dismissibleBody: some View {
    if let contentID = visibleContentID {
      ZStack {
        background(direction: currentDirection)
        if !dismissed {
          ControlView(id: contentID, axis: .none)
            .offset(translation)
            .gesture(dismissGesture(size: measuredSize))
        }
      }
      .frame(
        width: collapsing && ["up", "down"].contains(dismissedDirection ?? "") ? 0 : nil,
        height: collapsing && !["up", "down"].contains(dismissedDirection ?? "") ? 0 : nil)
      .background(
        GeometryReader { proxy in
          Color.clear
            .onAppear { measuredSize = proxy.size }
            .onChange(of: proxy.size) {
              measuredSize = $0
              if collapsing { events.fire(node, "resize") }
            }
        }
      )
    } else {
      Text(RufletDismissibleDefaults.missingContentError)
        .foregroundColor(.red)
    }
  }

  private var visibleContentID: Int? {
    guard let id = node.controlID(forKey: "content"),
      let content = store.node(id), content.bool("visible") != false
    else { return nil }
    return id
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
          // The Flet client waits at most five minutes for the asynchronous
          // server confirmation. A lost connection must not strand the row.
          let timeout = DispatchWorkItem {
            guard pendingDirection != nil else { return }
            pendingDirection = nil
            resetDismiss()
          }
          confirmTimeout = timeout
          DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: timeout)
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
    RufletDismissibleDefaults.threshold(node, direction: direction)
  }

  private func finishDismiss(direction: String) {
    let target = RufletDismissibleDefaults.dismissedOffset(
      size: measuredSize, direction: direction,
      layoutDirection: layoutDirection,
      crossAxisEndOffset: node.double("cross_axis_end_offset") ?? 0)
    let seconds = RufletDismissibleDefaults.movementDuration(node) / 1_000
    let collapse = RufletDismissibleDefaults.resizeDuration(node) / 1_000
    dismissedDirection = direction
    withAnimation(.easeOut(duration: seconds)) {
      translation = target
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
      withAnimation(.easeOut(duration: collapse)) {
        collapsing = true
        dismissed = true
      }
      events.fire(node, "resize")
      DispatchQueue.main.asyncAfter(deadline: .now() + collapse) {
        events.fire(node, "dismiss", data: .map(["direction": .string(direction)]))
      }
    }
  }

  private func resetDismiss() {
    thresholdReached = false
    withAnimation(
      .easeOut(
        duration: RufletDismissibleDefaults.movementDuration(node) / 1_000)
    ) {
      translation = .zero
    }
  }
}

/// Constructor durations for Flet's Dismissible.
///
/// The pinned Dart client currently reads its historical wire key `duration`
/// for both phases. Ruflet's public DSL also exposes the clearer generated
/// names `movement_duration` and `resize_duration`; those are accepted as
/// compatibility aliases only when the exact Flet key is absent. This keeps
/// the native engine faithful to Flet while ensuring both public properties
/// are actually consumed instead of silently discarded.
enum RufletDismissibleDefaults {
  static let missingContentError = "Dismissible.content must be visible"

  static func movementDuration(_ node: ControlNode) -> Double {
    max(node.double("duration") ?? node.double("movement_duration") ?? 200, 0)
  }

  static func resizeDuration(_ node: ControlNode) -> Double {
    max(node.double("duration") ?? node.double("resize_duration") ?? 300, 0)
  }

  static func threshold(_ node: ControlNode, direction: String) -> Double {
    guard let values = node.props["dismiss_thresholds"]?.mapValue else {
      return RufletGestureParity.dismissThreshold
    }
    // The pinned Dart parser accepts enum.name keys (`endToStart`) while the
    // Ruby DSL also serializes symbol keys as `end_to_start`. Prefer the exact
    // Flet spelling when both are present, then consume the DSL alias.
    if let exact = values[direction]?.doubleValue { return exact }
    return values.first { key, _ in
      RufletInteractionParity.normalizedDismissDirection(key) == direction
    }?.value.doubleValue ?? RufletGestureParity.dismissThreshold
  }

  /// Flutter's movement controller stops at one full main-axis extent. Use
  /// the measured Apple view extent too, including the documented fractional
  /// cross-axis offset, instead of an arbitrary screen-sized translation.
  static func dismissedOffset(
    size: CGSize, direction: String, layoutDirection: LayoutDirection,
    crossAxisEndOffset: Double
  ) -> CGSize {
    let vertical = direction == "up" || direction == "down"
    let distance = vertical ? size.height : size.width
    let cross = CGFloat(crossAxisEndOffset) * (vertical ? size.width : size.height)
    switch direction {
    case "startToEnd":
      return CGSize(
        width: layoutDirection == .leftToRight ? distance : -distance,
        height: cross)
    case "endToStart":
      return CGSize(
        width: layoutDirection == .leftToRight ? -distance : distance,
        height: cross)
    case "down":
      return CGSize(width: cross, height: distance)
    default:
      return CGSize(width: cross, height: -distance)
    }
  }
}

/// `InteractiveViewer` — pan and zoom over its content.
struct InteractiveViewerControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var scale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var interacting = false
  @State private var gestureStartScale: CGFloat?
  @State private var gestureStartOffset: CGSize?
  @State private var viewportSize = CGSize.zero
  @State private var lastReport = Date.distantPast
  /// `save_state`/`restore_state` are a matched pair in Flet's API.
  @State private var saved: (scale: CGFloat, offset: CGSize)?

  /// `interaction_update_interval` throttles the update stream the way Flet
  /// throttles its own; start and end are never dropped.
  private func report(event name: String) {
    if name == "interaction_update" {
      let interval = TimeInterval(
        node.int("interaction_update_interval") ?? RufletGestureParity.interactionUpdateInterval
      ) / 1_000
      guard Date().timeIntervalSince(lastReport) >= interval else { return }
      lastReport = Date()
    }
    let timestamp = Date().timeIntervalSince1970 * 1_000
    switch name {
    case "interaction_start":
      events.fire(
        node, name,
        data: RufletInteractionParity.scaleStart(
          local: .zero, global: .zero, timestamp: timestamp))
    case "interaction_update":
      events.fire(
        node, name,
        data: RufletInteractionParity.scaleUpdate(
          scale: scale, local: .zero, global: .zero,
          previousLocal: CGPoint(x: -offset.width, y: -offset.height), timestamp: timestamp))
    default:
      events.fire(node, name, data: RufletInteractionParity.scaleEnd())
    }
  }

  private func startInteractionIfNeeded() {
    guard !interacting else { return }
    interacting = true
    report(event: "interaction_start")
  }

  private var transformAnchor: UnitPoint {
    let alignment = ControlProps.alignment(node.props["alignment"]) ?? .center
    if alignment == .topLeading { return .topLeading }
    if alignment == .top { return .top }
    if alignment == .topTrailing { return .topTrailing }
    if alignment == .leading { return .leading }
    if alignment == .trailing { return .trailing }
    if alignment == .bottomLeading { return .bottomLeading }
    if alignment == .bottom { return .bottom }
    if alignment == .bottomTrailing { return .bottomTrailing }
    return .center
  }

  private func clampedOffset(_ candidate: CGSize) -> CGSize {
    let margin = ControlProps.edgeInsets(node.props["boundary_margin"]) ?? EdgeInsets()
    let overflowX = max(0, (scale - 1) * viewportSize.width / 2)
    let overflowY = max(0, (scale - 1) * viewportSize.height / 2)
    return CGSize(
      width: min(max(candidate.width, -overflowX - margin.trailing), overflowX + margin.leading),
      height: min(max(candidate.height, -overflowY - margin.bottom), overflowY + margin.top))
  }

  var body: some View {
    let contentID = node.controlID(forKey: "content")
    return Group {
      if RufletInteractiveViewerSemantics.validationError(
        contentID: contentID, content: contentID.flatMap(store.node)) == nil,
        let contentID
      {
        ControlView(id: contentID, axis: .none)
      } else {
        Text(RufletInteractiveViewerSemantics.missingContentError)
          .font(.caption).foregroundStyle(.red)
      }
    }
    .scaleEffect(scale, anchor: transformAnchor)
    .offset(offset)
    .fixedSize(
      horizontal: node.bool("constrained") == false,
      vertical: node.bool("constrained") == false)
    .background(
      GeometryReader { proxy in
        Color.clear
          .onAppear { viewportSize = proxy.size }
          .onChange(of: proxy.size) { viewportSize = $0 }
      })
    .gesture(
      SimultaneousGesture(
        MagnificationGesture().onChanged { value in
          guard node.bool("disabled") != true, node.bool("scale_enabled") != false else { return }
          startInteractionIfNeeded()
          let minimum = CGFloat(node.double("min_scale") ?? RufletGestureParity.interactiveMinScale)
          let maximum = CGFloat(node.double("max_scale") ?? RufletGestureParity.interactiveMaxScale)
          if gestureStartScale == nil { gestureStartScale = scale }
          scale = min(max((gestureStartScale ?? 1) * value, minimum), maximum)
          report(event: "interaction_update")
        },
        DragGesture().onChanged { value in
          guard node.bool("disabled") != true, node.bool("pan_enabled") != false else { return }
          startInteractionIfNeeded()
          if gestureStartOffset == nil { gestureStartOffset = offset }
          offset = clampedOffset(CGSize(
            width: (gestureStartOffset ?? .zero).width + value.translation.width,
            height: (gestureStartOffset ?? .zero).height + value.translation.height))
          report(event: "interaction_update")
        }
      )
      .onEnded { value in
        guard interacting else { return }
        interacting = false
        // Flutter keeps gliding after the finger lifts; the friction
        // coefficient is how quickly that settles.
        let friction =
          node.double("interaction_end_friction_coefficient")
          ?? RufletGestureParity.interactiveFriction
        let duration = min(max(friction * 1_000, 0.1), 1)
        if node.bool("pan_enabled") != false, let drag = value.second {
          let origin = gestureStartOffset ?? offset
          let projected = clampedOffset(
            CGSize(
              width: origin.width + drag.predictedEndTranslation.width,
              height: origin.height + drag.predictedEndTranslation.height))
          withAnimation(.easeOut(duration: duration)) { offset = projected }
        }
        gestureStartScale = nil
        gestureStartOffset = nil
        report(event: "interaction_end")
      })
    .modifier(ChromeClipModifier(behavior: node.string("clip_behavior") ?? "hardEdge"))
    .modifier(
      InteractiveTrackpadScale(
        node: node, scale: $scale,
        began: { startInteractionIfNeeded() },
        updated: { report(event: "interaction_update") },
        ended: {
          guard interacting else { return }
          interacting = false
          report(event: "interaction_end")
        }))
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "zoom":
        let factor = CGFloat(call.argument("factor")?.doubleValue ?? 1)
        scale = min(
          max(
            scale * factor,
            CGFloat(node.double("min_scale") ?? RufletGestureParity.interactiveMinScale)),
          CGFloat(node.double("max_scale") ?? RufletGestureParity.interactiveMaxScale))
        completion(.success(.null))
      case "pan":
        // Flet exposes a z delta for matrix parity. The native Apple viewer is
        // two-dimensional, but dx/dy retain the same additive semantics.
        _ = call.argument("dz")?.doubleValue ?? 0
        offset = clampedOffset(CGSize(
          width: offset.width + CGFloat(call.argument("dx")?.doubleValue ?? 0),
          height: offset.height + CGFloat(call.argument("dy")?.doubleValue ?? 0)))
        completion(.success(.null))
      case "reset":
        let reset = {
          scale = 1
          offset = .zero
        }
        if let milliseconds = call.argument("animation_duration")?.doubleValue,
          milliseconds > 0
        {
          withAnimation(.easeInOut(duration: milliseconds / 1_000), reset)
        } else {
          reset()
        }
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

enum RufletInteractiveViewerSemantics {
  static let missingContentError = "InteractiveViewer.content must be provided and visible"

  static func validationError(contentID: Int?, content: ControlNode?) -> String? {
    RufletRequiredContent.validationError(
      contentID: contentID, content: content, message: missingContentError)
  }
}

/// Flutter uses `scale_factor` only when a trackpad scroll is converted to a
/// scale gesture. Direct pinches must not be multiplied by it.
private struct InteractiveTrackpadScale: ViewModifier {
  let node: ControlNode
  @Binding var scale: CGFloat
  let began: () -> Void
  let updated: () -> Void
  let ended: () -> Void
  @State private var endWork: DispatchWorkItem?

  func body(content: Content) -> some View {
    #if os(macOS)
      content.overlay(
        RufletNativePointerMonitor { name, payload in
          guard name == "scroll", node.bool("disabled") != true,
            node.bool("trackpad_scroll_causes_scale") == true,
            let delta = payload.mapValue?["sd"]?.mapValue?["y"]?.doubleValue
          else { return }
          began()
          let factor = node.double("scale_factor") ?? RufletGestureParity.interactiveScaleFactor
          let minimum = node.double("min_scale") ?? RufletGestureParity.interactiveMinScale
          let maximum = node.double("max_scale") ?? RufletGestureParity.interactiveMaxScale
          scale = CGFloat(min(max(Double(scale) * exp(-delta / factor), minimum), maximum))
          updated()
          endWork?.cancel()
          let work = DispatchWorkItem(block: ended)
          endWork = work
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }.allowsHitTesting(false))
    #else
      content
    #endif
  }
}

/// `KeyboardListener` — reports physical key presses.
struct KeyboardListenerControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var focused = false

  var body: some View {
    let presentation = KeyboardListenerPresentation(node: node)
    if let contentID = presentation.contentID,
      presentation.validationError(content: store.node(contentID)) == nil
    {
      ZStack {
        ControlView(id: contentID, axis: .none)
        RufletNativeKeyboardListener(
          focused: $focused,
          includeSemantics: KeyboardListenerPresentation(node: node).includeSemantics,
          onKeyDown: { events.fire(node, "key_down", data: RufletInteractionParity.key($0)) },
          onKeyRepeat: { events.fire(node, "key_repeat", data: RufletInteractionParity.key($0)) },
          onKeyUp: { events.fire(node, "key_up", data: RufletInteractionParity.key($0)) }
        )
        .frame(width: 1, height: 1)
        .opacity(0.001)
      }
      .onAppear { focused = KeyboardListenerPresentation(node: node).autofocus }
      .rufletCommandHandler(node.id) { call, completion in
        guard call.name == "focus" else {
          completion(.failure(rufletUnsupported("KeyboardListener", call)))
          return
        }
        focused = true
        completion(.success(.null))
      }
    } else {
      Text(KeyboardListenerPresentation.missingContentError)
        .font(.caption).foregroundStyle(.red)
    }
  }
}

struct KeyboardListenerPresentation {
  static let missingContentError = "KeyboardListener control has no content."
  let node: ControlNode
  var contentID: Int? { node.controlID(forKey: "content") }
  var autofocus: Bool { node.bool("autofocus") ?? false }
  var includeSemantics: Bool { node.bool("include_semantics") ?? true }

  func validationError(content: ControlNode?) -> String? {
    guard contentID != nil, let content, content.bool("visible") != false else {
      return Self.missingContentError
    }
    return nil
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

  @ViewBuilder
  var body: some View {
    if node.type.hasPrefix("Cupertino") {
      cupertinoAction
    } else {
      nativeAction
    }
  }

  /// Flet owns the action slot and click contract. Apple owns the omitted
  /// button presentation; an explicit DSL color or destructive role is the
  /// only reason to override the native tint.
  private var nativeAction: some View {
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
        ? .red
        : MaterialPalette.color(node.string("color")))
    // Cupertino emphasises the default action in a sheet. `fontWeight` on a
    // view is iOS 16, and this package ships to iOS 15, so the weight goes on
    // the font itself.
    .modifier(DefaultActionEmphasis(emphasised: node.bool("default") == true))
    .disabled(node.bool("disabled") ?? false)
  }

  private var cupertinoAction: some View {
    Button {
      guard node.bool("disabled") != true else { return }
      events.fire(node, "click")
    } label: {
      HStack(spacing: 8) {
        actionContent
        if node.type == "CupertinoContextMenuAction",
           let icon = node.props["trailing_icon"]
        {
          RufletIcon(value: icon, size: 21, color: nil)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .frame(minHeight: minimumHeight)
      .padding(actionPadding)
    }
    .buttonStyle(.plain)
    .font(.system(size: actionFontSize,
                  weight: node.bool("default") == true ? .semibold : .regular))
    .rufletTextStyle(RufletTextStyle(node: node, styleKey: "text_style"))
    .foregroundColor(node.bool("destructive") == true ? .red : .accentColor)
    .disabled(node.bool("disabled") == true)
  }

  @ViewBuilder
  private var actionContent: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else if let content = node.string("content") {
      Text(content).lineLimit(node.type == "CupertinoContextMenuAction" ? 1 : nil)
    } else {
      Text("content must be provided").foregroundColor(.red)
    }
  }

  private var minimumHeight: CGFloat {
    switch node.type {
    case "CupertinoActionSheetAction":
      return RufletCupertinoPresentationDefaults.actionSheetActionMinimumHeight
    case "CupertinoContextMenuAction":
      return RufletCupertinoPresentationDefaults.contextMenuActionMinimumHeight
    default:
      return 44
    }
  }

  private var actionPadding: EdgeInsets {
    switch node.type {
    case "CupertinoActionSheetAction":
      return EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
    case "CupertinoContextMenuAction":
      return RufletCupertinoPresentationDefaults.contextMenuActionPadding
    default:
      return EdgeInsets()
    }
  }

  private var actionFontSize: CGFloat {
    node.type == "CupertinoContextMenuAction" ? 16 : 17
  }
}
