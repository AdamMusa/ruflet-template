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
    if FletFocusContract.requiresNativeFocus(for: node),
      #available(iOS 15.0, macOS 12.0, *)
    {
      return AnyView(FocusTracking(node: node, events: events) { content })
    }
    return AnyView(content)
  }
}

/// The focus capability is declared once by the control contract and shared
/// by every native primitive. Flet gives controls a `FocusNode` when they
/// expose focus/blur events, an autofocus property, or an imperative focus
/// method; deciding that in each renderer caused methods to be advertised but
/// never mounted on Apple.
enum FletFocusContract {
  static func methods(for node: ControlNode) -> Set<String> {
    ControlRegistry.descriptor(for: node.type)?.supportedMethods
      .intersection(["focus", "blur"]) ?? []
  }

  static func requiresNativeFocus(for node: ControlNode) -> Bool {
    node.handlesEvent("focus") || node.handlesEvent("blur")
      || node.bool("autofocus") == true || !methods(for: node).isEmpty
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
      .onAppear {
        if node.bool("autofocus") == true { focused = true }
      }
      .onChange(of: focused) { isFocused in
        events.fire(node, isFocused ? "focus" : "blur")
      }
      .rufletCommandHandler(node.id) { call, completion in
        guard FletFocusContract.methods(for: node).contains(call.name) else {
          completion(.failure(rufletUnsupported(node.type, call)))
          return
        }
        focused = call.name == "focus"
        completion(.success(.null))
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
