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
    if RufletFocusContract.requiresNativeFocus(for: node),
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
enum RufletFocusContract {
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
        guard RufletFocusContract.methods(for: node).contains(call.name) else {
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
      .modifier(TapDownReporter(node: node, events: events))
      .modifier(ClickReporter(node: node, events: events))
      .modifier(LongPressReporter(node: node, events: events))
      .modifier(HoverReporter(node: node, events: events))
  }
}

private struct TapDownReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  @State private var active = false
  @State private var globalOrigin: CGPoint = .zero

  func body(content: Content) -> some View {
    guard node.handlesEvent("tap_down") else { return AnyView(content) }
    return AnyView(
      content
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: TapDownGlobalOriginKey.self,
              value: proxy.frame(in: .global).origin)
          })
        .onPreferenceChange(TapDownGlobalOriginKey.self) { globalOrigin = $0 }
        .simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
          .onChanged { value in
            guard !active else { return }
            active = true
            let local = CGPoint(
              x: value.startLocation.x - globalOrigin.x,
              y: value.startLocation.y - globalOrigin.y)
            events.fire(node, "tap_down", data: .map([
              "local_x": .double(Double(local.x)),
              "local_y": .double(Double(local.y)),
              "global_x": .double(Double(value.startLocation.x)),
              "global_y": .double(Double(value.startLocation.y)),
              "kind": .string("touch"),
            ]))
          }
          .onEnded { _ in active = false }))
  }
}

private struct TapDownGlobalOriginKey: PreferenceKey {
  static var defaultValue = CGPoint.zero
  static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}
