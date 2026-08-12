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

    let delay = RufletWrapperDefaults.screenshotDelay(call.argument("delay")?.doubleValue)
    if delay > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1_000) {
        render(call, completion: completion)
      }
    } else {
      render(call, completion: completion)
    }
  }

  private func render(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    let renderer = ImageRenderer(
      content:
        content
        .environmentObject(store)
        .environment(\.rufletEvents, events))
    if let ratio = call.argument("pixel_ratio")?.doubleValue { renderer.scale = ratio }

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
    .accessibilityHint(node.string("hint_text") ?? "")
    .accessibilityValue(node.string("value") ?? "")
    .accessibilityAddTraits(traits)
    .accessibilityHidden(node.bool("hidden") ?? false)
    .accessibilityElement(children: childBehavior)
    .accessibilityFocused($accessibilityFocused)
    .privacySensitive(node.bool("obscured") ?? false)
    .onChange(of: accessibilityFocused) { focused in
      events.fire(
        node,
        focused ? "did_gain_accessibility_focus" : "did_lose_accessibility_focus")
    }
    .onAppear { if node.bool("focus") == true { accessibilityFocused = true } }
    .modifier(SemanticsHeading(level: node.int("heading_level")))
    .modifier(SemanticsStateContent(node: node))
    .modifier(SemanticsFocusability(focusable: node.bool("focusable")))
    .modifier(SemanticsActions(node: node, events: events))
  }

  /// `exclude_semantics` drops the subtree's own semantics, which is what
  /// `.ignore` does; `container` keeps children addressable rather than
  /// merging them into one element.
  private var childBehavior: AccessibilityChildBehavior {
    if node.bool("exclude_semantics") == true { return .ignore }
    return node.bool("container") == true ? .contain : .combine
  }

  private var traits: AccessibilityTraits {
    var traits = AccessibilityTraits()
    if node.bool("button") == true { traits.formUnion(.isButton) }
    if node.bool("header") == true { traits.formUnion(.isHeader) }
    if node.bool("image") == true { traits.formUnion(.isImage) }
    if node.bool("link") == true { traits.formUnion(.isLink) }
    if node.bool("selected") == true { traits.formUnion(.isSelected) }
    // Ruby sends `textfield`; Flutter's Semantics calls the same flag
    // `textField`. A read-only field is static text to VoiceOver.
    if node.bool("textfield") == true {
      traits.formUnion(node.bool("read_only") == true ? .isStaticText : .isSearchField)
    }
    if node.bool("slider") == true { traits.formUnion(.isSelected) }
    // Flutter's liveRegion asks the screen reader to announce changes.
    if node.bool("live_region") == true { traits.formUnion(.updatesFrequently) }
    return traits
  }
}

/// `heading_level` — Flutter numbers headings 1...6, matching SwiftUI's
/// `AccessibilityHeadingLevel`. Anything outside that range is unheaded, which
/// is what Flutter does with a zero level.
private struct SemanticsHeading: ViewModifier {
  let level: Int?

  func body(content: Content) -> some View {
    switch level {
    case 1: content.accessibilityHeading(.h1)
    case 2: content.accessibilityHeading(.h2)
    case 3: content.accessibilityHeading(.h3)
    case 4: content.accessibilityHeading(.h4)
    case 5: content.accessibilityHeading(.h5)
    case 6: content.accessibilityHeading(.h6)
    default: content
    }
  }
}

/// The state flags Flutter passes to the platform's accessibility node.
///
/// UIKit has no separate channel for them, and folding them into
/// `accessibilityValue` would overwrite the control's own value, so they are
/// announced as custom content — the API Apple provides for exactly this.
private struct SemanticsStateContent: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    var result = AnyView(content)
    for (label, value) in entries {
      result = AnyView(result.accessibilityCustomContent(Text(label), Text(value)))
    }
    return result
  }

  private var entries: [(String, String)] {
    var entries: [(String, String)] = []
    // `mixed` is Flutter's tristate checkbox, and it outranks `checked`.
    if node.bool("mixed") == true {
      entries.append(("Checked", "Mixed"))
    } else if let checked = node.bool("checked") {
      entries.append(("Checked", checked ? "Checked" : "Unchecked"))
    }
    if let toggled = node.bool("toggled") {
      entries.append(("Toggled", toggled ? "On" : "Off"))
    }
    if let expanded = node.bool("expanded") {
      entries.append(("Expanded", expanded ? "Expanded" : "Collapsed"))
    }
    if node.bool("multiline") == true { entries.append(("Multiline", "Yes")) }
    if node.bool("read_only") == true { entries.append(("Read only", "Yes")) }
    if let increased = node.string("increased_value"), !increased.isEmpty {
      entries.append(("Increased value", increased))
    }
    if let decreased = node.string("decreased_value"), !decreased.isEmpty {
      entries.append(("Decreased value", decreased))
    }
    if let current = node.int("current_value_length") {
      let maximum = node.int("max_value_length")
      entries.append((
        "Length", maximum.map { "\(current) of \($0)" } ?? "\(current)"))
    }
    return entries
  }
}

/// `focusable: false` takes the subtree out of the accessibility focus order.
/// `.accessibilityRespondsToUserInteraction` is the modifier that expresses
/// that without also hiding the element from the reader.
private struct SemanticsFocusability: ViewModifier {
  let focusable: Bool?

  func body(content: Content) -> some View {
    if let focusable {
      content.accessibilityRespondsToUserInteraction(focusable)
    } else {
      content
    }
  }
}

private struct SemanticsActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(SemanticsDefaultAction(node: node, events: events))
      .modifier(SemanticsGestureActions(node: node, events: events))
      .modifier(SemanticsAdjustActions(node: node, events: events))
      .modifier(SemanticsDismissAction(node: node, events: events))
      .modifier(SemanticsNamedActions(node: node, events: events))
  }
}

/// Ruby declares this one as `on_tap`, so the event it expects back is `tap`
/// rather than Flutter's `click`. `on_tap_hint_text` names the activation the
/// way Flutter's `onTapHint` does; VoiceOver reads a named action's label in
/// the same place.
private struct SemanticsDefaultAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.handlesEvent("tap") {
      if let hint = node.string("on_tap_hint_text"), !hint.isEmpty {
        content.accessibilityAction(named: Text(hint)) { events.fire(node, "tap") }
      } else {
        content.accessibilityAction(.default) { events.fire(node, "tap") }
      }
    } else { content }
  }
}

/// `on_double_tap` and `on_long_press` have no gesture of their own under
/// VoiceOver, which routes every activation through the rotor, so each is
/// offered as a named action.
private struct SemanticsGestureActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(NamedSemanticsAction(
        node: node, events: events, event: "double_tap", label: "Double tap"))
      .modifier(NamedSemanticsAction(
        node: node, events: events, event: "long_press",
        label: node.string("on_long_press_hint_text") ?? "Long press"))
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
      // AppKit posts a notification whenever a selection moves; UIKit posts
      // none — `textViewDidChangeSelection` is a delegate callback, and the
      // text views here belong to whatever control is being wrapped. Text
      // change is the only public signal, so a selection that moves without
      // the text changing is not reported on iOS.
      content.onReceive(
        NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)
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
    // Flet names the resting colour `base_color`; `color` is the older
    // spelling the same control still accepts.
    let base = MaterialPalette.color(
      node.string("base_color") ?? node.string("color"), default: .gray.opacity(0.3))
    let highlight = MaterialPalette.color(
      node.string("highlight_color"), default: .white.opacity(0.6))

    content
    .overlay {
      if node.bool("disabled") != true {
        shimmer(base: base, highlight: highlight)
      }
    }
    .mask(content)
  }

  @ViewBuilder private var content: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    }
  }

  private func shimmer(base: Color, highlight: Color) -> some View {
    let supplied = GradientProps.linear(node.props["gradient"])
    return (supplied ?? LinearGradient(
      stops: [
        .init(color: base, location: 0),
        .init(color: highlight, location: 0.5),
        .init(color: base, location: 1)
      ], startPoint: sweep.start, endPoint: sweep.end))
    .overlay(
      Color.clear
    )
    .offset(x: sweep.horizontal ? phase * 240 : 0, y: sweep.horizontal ? 0 : phase * 240)
    .onAppear {
      let period = RufletWrapperDefaults.shimmerPeriod(node.double("period"))
      // `loop` is how many passes to make; Flutter treats zero as endless,
      // which is also the default.
      let passes = RufletWrapperDefaults.shimmerRepeats(node.int("loop"))
      let animation = Animation.linear(duration: period)
      withAnimation(
        passes != nil
          ? animation.repeatCount(passes!, autoreverses: false)
          : animation.repeatForever(autoreverses: false)
      ) {
        phase = 1
      }
    }
  }

  /// `direction` is the way the highlight travels across the content.
  private var sweep: (start: UnitPoint, end: UnitPoint, horizontal: Bool) {
    switch node.string("direction")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "righttoleft", "rtl": return (.trailing, .leading, true)
    case "toptobottom", "ttb": return (.top, .bottom, false)
    case "bottomtotop", "btt": return (.bottom, .top, false)
    default: return (.leading, .trailing, true)
    }
  }
}

enum RufletWrapperDefaults {
  static func screenshotDelay(_ milliseconds: Double?) -> Double {
    milliseconds ?? 20
  }

  static func shimmerPeriod(_ milliseconds: Double?) -> Double {
    (milliseconds ?? 1500) / 1_000
  }

  static func shimmerRepeats(_ loop: Int?) -> Int? {
    let count = loop ?? 0
    return count > 0 ? count : nil
  }
}

/// `ShaderMask` — masks its content with a gradient.
///
/// Flet passes an arbitrary shader; a linear or radial gradient is the part of
/// that surface SwiftUI can express, and it is what the control is used for.
struct ShaderMaskControlView: View {
  let node: ControlNode

  var body: some View {
    content
      .overlay { gradient.blendMode(ControlProps.blendMode(node.string("blend_mode"))) }
      .mask(content)
      .clipShape(RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
  }

  @ViewBuilder private var content: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
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
  @Namespace private var fallbackNamespace
  @Environment(\.rufletHeroNamespace) private var pageNamespace

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .matchedGeometryEffect(
      id: node.string("tag") ?? "hero-\(node.id)",
      in: pageNamespace ?? fallbackNamespace)
    // Flutter can keep a hero flying while the user drives a back gesture;
    // SwiftUI's matched geometry always does, so the flag only turns it off.
    .transaction { transaction in
      if node.bool("transition_on_user_gestures") == false {
        transaction.disablesAnimations = true
      }
    }
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
      // iOS has no movable top-level window. Flet's window_manager backend is
      // desktop-only too, so the wrapper remains visible without inventing a
      // maximize event that never happened.
      content
    #endif
  }
}

private struct RufletHeroNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
  var rufletHeroNamespace: Namespace.ID? {
    get { self[RufletHeroNamespaceKey.self] }
    set { self[RufletHeroNamespaceKey.self] = newValue }
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
