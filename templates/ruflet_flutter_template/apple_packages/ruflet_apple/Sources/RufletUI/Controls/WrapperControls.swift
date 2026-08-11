import RufletEngine
import RufletProtocol
import SwiftUI
#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

/// `Screenshot` — captures its content as PNG bytes.
///
/// Flet's `capture` returns the image to Ruby, so the control has to rasterise
/// the *live* subtree, not rebuild it. `ImageRenderer` does exactly that, which
/// is why this needs a mounted view rather than a service.
struct ScreenshotControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    content
      .rufletCommandHandler(node.id) { call, completion in
        capture(call, completion: completion)
      }
  }

  @ViewBuilder
  private var content: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }

  private func capture(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    guard #available(iOS 16.0, macOS 13.0, *) else {
      return completion(
        .failure(RufletServiceError.unavailable("Screenshot capture needs iOS 16 / macOS 13")))
    }

    let renderer = ImageRenderer(
      content:
        content
        .environmentObject(store)
        .environment(\.rufletEvents, events))
    renderer.scale = call.argument("pixel_ratio")?.doubleValue ?? 2

    #if canImport(UIKit)
      guard let data = renderer.uiImage?.pngData() else {
        return completion(.failure(RufletServiceError.failed("The view could not be rasterised")))
      }
    #elseif canImport(AppKit)
      guard let image = renderer.nsImage,
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
      else {
        return completion(.failure(RufletServiceError.failed("The view could not be rasterised")))
      }
    #else
      let data = Data()
    #endif

    completion(.success(.binary([UInt8](data))))
  }
}

/// `Semantics` — the accessibility wrapper.
///
/// Flet's Semantics carries the label, hint, value and a set of traits;
/// SwiftUI's accessibility modifiers are the direct equivalent, so a screen
/// reader hears the same thing it would through the Flutter engine.
struct SemanticsControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @AccessibilityFocusState private var accessibilityFocused: Bool

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .accessibilityLabel(node.string("label") ?? "")
    .accessibilityHint(node.string("hint") ?? "")
    .accessibilityValue(node.string("value") ?? "")
    .accessibilityAddTraits(traits)
    .accessibilityHidden(node.bool("hidden") ?? false)
    .accessibilityElement(children: node.bool("container") == true ? .contain : .combine)
    .accessibilityFocused($accessibilityFocused)
    .onChange(of: accessibilityFocused) { focused in
      events.fire(
        node,
        focused ? "did_gain_accessibility_focus" : "did_lose_accessibility_focus")
    }
    .modifier(SemanticsActions(node: node, events: events))
  }

  private var traits: AccessibilityTraits {
    var traits = AccessibilityTraits()
    if node.bool("button") == true { traits.formUnion(.isButton) }
    if node.bool("header") == true { traits.formUnion(.isHeader) }
    if node.bool("image") == true { traits.formUnion(.isImage) }
    if node.bool("link") == true { traits.formUnion(.isLink) }
    if node.bool("selected") == true { traits.formUnion(.isSelected) }
    if node.bool("text_field") == true { traits.formUnion(.isStaticText) }
    return traits
  }
}

private struct SemanticsActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(SemanticsDefaultAction(node: node, events: events))
      .modifier(SemanticsAdjustActions(node: node, events: events))
      .modifier(SemanticsDismissAction(node: node, events: events))
      .modifier(SemanticsNamedActions(node: node, events: events))
  }
}

private struct SemanticsDefaultAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  func body(content: Content) -> some View {
    if node.handlesEvent("click") {
      content.accessibilityAction(.default) { events.fire(node, "click") }
    } else { content }
  }
}

private struct SemanticsAdjustActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  func body(content: Content) -> some View {
    content.accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: events.fire(node, "increase")
      case .decrement: events.fire(node, "decrease")
      @unknown default: break
      }
    }
  }
}

private struct SemanticsDismissAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  func body(content: Content) -> some View {
    if node.handlesEvent("dismiss") {
      content.accessibilityAction(.escape) { events.fire(node, "dismiss") }
    } else { content }
  }
}

private struct SemanticsNamedActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(NamedSemanticsAction(node: node, events: events, event: "scroll_left", label: "Scroll left"))
      .modifier(NamedSemanticsAction(node: node, events: events, event: "scroll_right", label: "Scroll right"))
      .modifier(NamedSemanticsAction(node: node, events: events, event: "scroll_up", label: "Scroll up"))
      .modifier(NamedSemanticsAction(node: node, events: events, event: "scroll_down", label: "Scroll down"))
      .modifier(NamedSemanticsAction(node: node, events: events, event: "copy", label: "Copy"))
      .modifier(NamedSemanticsAction(node: node, events: events, event: "cut", label: "Cut"))
      .modifier(NamedSemanticsAction(node: node, events: events, event: "paste", label: "Paste"))
      .modifier(NamedSemanticsAction(
        node: node, events: events, event: "move_cursor_forward_by_character",
        label: "Move cursor forward", data: .bool(true)))
      .modifier(NamedSemanticsAction(
        node: node, events: events, event: "move_cursor_backward_by_character",
        label: "Move cursor backward", data: .bool(true)))
      .modifier(NamedSemanticsAction(
        node: node, events: events, event: "set_text", label: "Set text",
        data: .string(node.string("value") ?? "")))
  }
}

private struct NamedSemanticsAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  let event: String
  let label: String
  var data: RufletValue = .null

  func body(content: Content) -> some View {
    if node.handlesEvent(event) {
      content.accessibilityAction(named: Text(label)) { events.fire(node, event, data: data) }
    } else { content }
  }
}

/// `MergeSemantics` — presents its subtree as one accessibility element, the
/// way Flutter's widget of the same name does.
struct MergeSemanticsControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// `SelectionArea` — makes the text inside it selectable.
struct SelectionAreaControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .textSelection(.enabled)
    .modifier(SelectionChangeReporter(node: node, events: events))
  }
}

private struct SelectionChangeReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    #if canImport(AppKit)
      content.onReceive(
        NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)
      ) { notification in
        guard let view = notification.object as? NSTextView else { return }
        let range = view.selectedRange()
        guard range.location != NSNotFound, range.location + range.length <= view.string.utf16.count else {
          return
        }
        events.fire(
          node, "change",
          data: .string((view.string as NSString).substring(with: range)))
      }
    #elseif canImport(UIKit)
      content.onReceive(
        NotificationCenter.default.publisher(for: UITextView.textDidChangeSelectionNotification)
      ) { notification in
        guard let view = notification.object as? UITextView,
          let range = view.selectedTextRange
        else { return }
        events.fire(node, "change", data: .string(view.text(in: range) ?? ""))
      }
    #else
      content
    #endif
  }
}

/// `TransparentPointer` — visible but not hit-testable, so taps fall through
/// to whatever is beneath it in a Stack.
struct TransparentPointerControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .allowsHitTesting(false)
  }
}

/// `Shimmer` — a loading placeholder with a highlight sweeping across it.
struct ShimmerControlView: View {
  let node: ControlNode
  @State private var phase: CGFloat = -1

  var body: some View {
    let base = MaterialPalette.color(node.string("color"), default: .gray.opacity(0.3))
    let highlight = MaterialPalette.color(
      node.string("highlight_color"), default: .white.opacity(0.6))

    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .overlay(
      LinearGradient(
        stops: [
          .init(color: base.opacity(0), location: 0),
          .init(color: highlight, location: 0.5),
          .init(color: base.opacity(0), location: 1)
        ],
        startPoint: .leading, endPoint: .trailing)
        .offset(x: phase * 240)
        .blendMode(.plusLighter)
    )
    .mask(
      Group {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        }
      }
    )
    .onAppear {
      let period = (node.double("period") ?? 1500) / 1000
      withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
        phase = 1
      }
    }
  }
}

/// `ShaderMask` — masks its content with a gradient.
///
/// Flet passes an arbitrary shader; a linear or radial gradient is the part of
/// that surface SwiftUI can express, and it is what the control is used for.
struct ShaderMaskControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .mask(gradient)
  }

  @ViewBuilder
  private var gradient: some View {
    if let mask = GradientProps.linear(node.props["shader"]) {
      Rectangle().fill(mask)
    } else {
      Rectangle()
    }
  }
}

/// `Hero` — a shared-element transition between screens.
///
/// SwiftUI matches geometry by tag within a namespace, so the control's `tag`
/// becomes the match id. Two screens sharing a namespace animate; a lone Hero
/// simply renders its content, which is the Flutter behaviour too.
struct HeroControlView: View {
  let node: ControlNode
  @Namespace private var namespace

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .matchedGeometryEffect(id: node.string("tag") ?? "hero-\(node.id)", in: namespace)
  }
}

/// `WindowDragArea` — dragging this region moves the window.
struct WindowDragAreaControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .modifier(WindowDragGesture(node: node, events: events))
  }
}

private struct WindowDragGesture: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var dragging = false

  func body(content: Content) -> some View {
    #if os(macOS)
      content
        .simultaneousGesture(
          TapGesture(count: 2).onEnded {
            guard node.bool("maximizable") != false, let window = NSApp.keyWindow else { return }
            let wasMaximized = window.styleMask.contains(.fullScreen)
              || window.standardWindowButton(.zoomButton)?.state == .on
            window.performZoom(nil)
            events.fire(
              node, "double_tap",
              data: .string(wasMaximized ? "unmaximize" : "maximize"))
          })
        .gesture(
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
          .onChanged { value in
            // AppKit already knows how to drag a window from an event; asking
            // it is far more robust than moving the frame by hand.
            guard let window = NSApp.keyWindow, let event = NSApp.currentEvent else { return }
            if !dragging {
              dragging = true
              events.fire(
                node, "drag_start",
                data: RufletInteractionParity.dragStart(
                  kind: "mouse", local: value.startLocation,
                  global: value.startLocation,
                  timestamp: Date().timeIntervalSince1970 * 1_000))
            }
            window.performDrag(with: event)
          }
          .onEnded { value in
            dragging = false
            events.fire(
              node, "drag_end",
              data: RufletInteractionParity.dragEnd(
                local: value.location, global: value.location,
                velocity: .zero, primaryVelocity: nil))
          })
    #else
      content.simultaneousGesture(
        TapGesture(count: 2).onEnded {
          if node.bool("maximizable") != false {
            events.fire(node, "double_tap", data: .string("maximize"))
          }
        })
    #endif
  }
}

/// `BrowserContextMenu` and `AutofillGroup` — web-only and platform-managed
/// respectively, so they render their content and nothing more.
struct InertWrapperControlView: View {
  let node: ControlNode

  var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }
}
