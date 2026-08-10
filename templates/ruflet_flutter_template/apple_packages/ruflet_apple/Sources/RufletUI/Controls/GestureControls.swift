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
    .modifier(TapGestures(node: node, events: events))
    .modifier(DragGestures(node: node, events: events))
    .modifier(ScaleGestures(node: node, events: events))
    .modifier(HoverReporter(node: node, events: events))
  }
}

private struct TapGestures: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(ClickReporter(node: node, events: events))
      .modifier(LongPressReporter(node: node, events: events))
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
        TapGesture(count: 2).onEnded { events.send(node.id, "double_tap", .null) })
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

  private var wanted: Bool {
    node.handlesEvent("pan_start") || node.handlesEvent("pan_update")
      || node.handlesEvent("pan_end") || node.handlesEvent("horizontal_drag_update")
      || node.handlesEvent("vertical_drag_update")
  }

  func body(content: Content) -> some View {
    guard wanted else { return AnyView(content) }
    return AnyView(
      content.gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if !dragging {
              dragging = true
              events.fire(node, "pan_start", data: payload(value))
            }
            events.fire(node, "pan_update", data: payload(value))
            events.fire(node, "horizontal_drag_update", data: payload(value))
            events.fire(node, "vertical_drag_update", data: payload(value))
          }
          .onEnded { value in
            dragging = false
            events.fire(node, "pan_end", data: payload(value))
          }))
  }

  private func payload(_ value: DragGesture.Value) -> RufletValue {
    .map([
      "lx": .double(value.location.x),
      "ly": .double(value.location.y),
      "gx": .double(value.startLocation.x + value.translation.width),
      "gy": .double(value.startLocation.y + value.translation.height),
      "dx": .double(value.translation.width),
      "dy": .double(value.translation.height),
      "local_x": .double(value.location.x),
      "local_y": .double(value.location.y),
      "global_x": .double(value.startLocation.x + value.translation.width),
      "global_y": .double(value.startLocation.y + value.translation.height),
      "delta_x": .double(value.translation.width),
      "delta_y": .double(value.translation.height),
      "primary_delta": .double(value.translation.width)
    ])
  }
}

/// `scale` — pinch, reported with the same `scale`/`horizontal_scale` keys.
private struct ScaleGestures: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var scaling = false

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
              events.fire(node, "scale_start", data: .map(["scale": .double(value)]))
            }
            events.fire(
              node, "scale_update",
              data: .map([
                "scale": .double(value),
                "horizontal_scale": .double(value),
                "vertical_scale": .double(value)
              ]))
          }
          .onEnded { value in
            scaling = false
            events.fire(node, "scale_end", data: .map(["scale": .double(value)]))
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

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        events.fire(node, "dismiss", data: .map(["direction": .string("endToStart")]))
      } label: {
        Label("Dismiss", systemImage: "trash")
      }
    }
  }
}

/// `InteractiveViewer` — pan and zoom over its content.
struct InteractiveViewerControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var scale: CGFloat = 1
  @State private var offset: CGSize = .zero
  /// `save_state`/`restore_state` are a matched pair in Flet's API.
  @State private var saved: (scale: CGFloat, offset: CGSize)?

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .scaleEffect(scale)
    .offset(offset)
    .gesture(
      SimultaneousGesture(
        MagnificationGesture().onChanged { value in
          let minimum = CGFloat(node.double("min_scale") ?? 0.8)
          let maximum = CGFloat(node.double("max_scale") ?? 2.5)
          scale = min(max(value, minimum), maximum)
        },
        DragGesture().onChanged { value in
          guard node.bool("pan_enabled") != false else { return }
          offset = value.translation
        }
      )
      .onEnded { _ in
        events.fire(
          node, "interaction_end",
          data: .map([
            "scale": .double(scale),
            "pan_x": .double(offset.width),
            "pan_y": .double(offset.height)
          ]))
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

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    #if os(macOS)
      .onExitCommand { events.fire(node, "key", data: .map(["key": .string("Escape")])) }
    #endif
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
    .disabled(node.bool("disabled") ?? false)
  }
}
