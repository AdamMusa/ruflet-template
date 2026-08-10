import RufletEngine
import RufletProtocol
import SwiftUI

/// The gesture and focus events shared across controls.
///
/// Each attaches only when Ruby declared a handler (`on_click => true` and
/// friends), so a control nobody is listening to keeps SwiftUI's own hit
/// testing untouched and never puts anything on the wire.

/// `click` / `tap` — the primary activation of a non-button control.
struct ClickReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("click") {
      content.onTapGesture { events.send(node.id, "click", .null) }
    } else if node.handlesEvent("tap") {
      content.onTapGesture { events.send(node.id, "tap", .null) }
    } else {
      content
    }
  }
}

struct LongPressReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("long_press") {
      content.simultaneousGesture(
        SwiftUI.LongPressGesture().onEnded { _ in events.send(node.id, "long_press", .null) })
    } else {
      content
    }
  }
}

struct HoverReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("hover") {
      content.onHover { inside in events.send(node.id, "hover", .bool(inside)) }
    } else {
      content
    }
  }
}

/// `focus` / `blur`, which Flet emits for buttons, fields and pickers alike.
struct FocusReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("focus") || node.handlesEvent("blur"),
      #available(iOS 15.0, macOS 12.0, *)
    {
      return AnyView(FocusTracking(node: node, events: events) { content })
    }
    return AnyView(content)
  }
}

@available(iOS 15.0, macOS 12.0, *)
private struct FocusTracking<Content: View>: View {
  let node: ControlNode
  let events: RufletEventSink
  @ViewBuilder let content: () -> Content
  @FocusState private var focused: Bool

  var body: some View {
    content()
      .focused($focused)
      .onChange(of: focused) { isFocused in
        events.fire(node, isFocused ? "focus" : "blur")
      }
  }
}

/// The pointer events a control accepts without being a button.
struct TapReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(ClickReporter(node: node, events: events))
      .modifier(LongPressReporter(node: node, events: events))
      .modifier(HoverReporter(node: node, events: events))
  }
}
