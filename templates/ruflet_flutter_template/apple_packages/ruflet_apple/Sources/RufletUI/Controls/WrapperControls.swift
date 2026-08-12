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

  private var configuration: RufletSemanticsConfiguration {
    RufletSemanticsConfiguration(node: node)
  }

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        EmptyView()
      }
    }
    .modifier(
      SemanticsOptionalText(
        label: configuration.label,
        hint: configuration.hint,
        value: configuration.value)
    )
    .accessibilityAddTraits(traits)
    .modifier(SemanticsVisibility(hidden: configuration.hidden))
    .accessibilityElement(children: childBehavior)
    .accessibilityFocused($accessibilityFocused)
    .modifier(SemanticsPrivacy(obscured: configuration.obscured))
    .modifier(SemanticsTooltip(tooltip: configuration.tooltip))
    .onChange(of: accessibilityFocused) { focused in
      if let event = configuration.handledEvent(
        focused ? "did_gain_accessibility_focus" : "did_lose_accessibility_focus")
      {
        events.fire(node, event)
      }
    }
    .onAppear { if configuration.focused == true { accessibilityFocused = true } }
    .modifier(SemanticsHeading(level: configuration.headingLevel))
    .modifier(SemanticsStateContent(node: node))
    .modifier(SemanticsFocusability(focusable: configuration.focusable))
    .modifier(SemanticsActions(node: node, events: events))
  }

  /// `exclude_semantics` drops the subtree's own semantics, which is what
  /// `.ignore` does; `container` keeps children addressable rather than
  /// merging them into one element.
  private var childBehavior: AccessibilityChildBehavior {
    if configuration.excludeSemantics { return .ignore }
    return configuration.container ? .contain : .combine
  }

  private var traits: AccessibilityTraits {
    var traits = AccessibilityTraits()
    if node.bool("button") == true { traits.formUnion(.isButton) }
    if node.bool("header") == true { traits.formUnion(.isHeader) }
    if node.bool("image") == true { traits.formUnion(.isImage) }
    if node.bool("link") == true { traits.formUnion(.isLink) }
    if node.bool("selected") == true { traits.formUnion(.isSelected) }
    // Flutter's `textField` flag has no exact SwiftUI trait. Search-field and
    // static-text are the closest native distinctions VoiceOver exposes.
    if configuration.textField == true {
      traits.formUnion(node.bool("read_only") == true ? .isStaticText : .isSearchField)
    }
    // Flutter's liveRegion asks the screen reader to announce changes.
    if node.bool("live_region") == true { traits.formUnion(.updatesFrequently) }
    return traits
  }
}

/// Wire interpretation kept separate from SwiftUI so the pinned Flet names
/// and Ruflet's historical spellings cannot silently drift apart again.
/// Canonical Flet properties always win; aliases only keep older Ruby clients
/// functional while they migrate to the source contract.
struct RufletSemanticsConfiguration {
  let node: ControlNode

  var label: String? { string("label") }
  var hint: String? { string("hint", compatibility: "hint_text") }
  var value: String? { string("value") }
  var tooltip: String? { string("tooltip") }
  var textField: Bool? { bool("text_field", compatibility: "textfield") }
  var slider: Bool? { bool("slider") }
  var focused: Bool? { bool("focused", compatibility: "focus") }
  var disabled: Bool? { bool("disabled") }
  var hidden: Bool? { bool("hidden") }
  var obscured: Bool? { bool("obscured") }
  var focusable: Bool? { bool("focusable") }
  var headingLevel: Int? { integer("heading_level") }
  var container: Bool { bool("container") ?? false }
  var excludeSemantics: Bool { bool("exclude_semantics") ?? false }
  var tapHint: String? { string("on_tap_hint", compatibility: "on_tap_hint_text") }
  var longPressHint: String? {
    string("on_long_press_hint", compatibility: "on_long_press_hint_text")
  }

  func handledEvent(_ canonical: String, compatibility: String? = nil) -> String? {
    if node.props["on_\(canonical)"]?.boolValue == true { return canonical }
    if let compatibility, node.props["on_\(compatibility)"]?.boolValue == true {
      return compatibility
    }
    return nil
  }

  private func string(_ canonical: String, compatibility: String? = nil) -> String? {
    if let value = node.props[canonical]?.stringValue { return value }
    return compatibility.flatMap { node.props[$0]?.stringValue }
  }

  private func bool(_ canonical: String, compatibility: String? = nil) -> Bool? {
    if let value = node.props[canonical]?.boolValue { return value }
    if let compatibility, let value = node.props[compatibility]?.boolValue { return value }
    return node.bool(canonical)
  }

  private func integer(_ canonical: String, compatibility: String? = nil) -> Int? {
    if let value = node.props[canonical]?.intValue { return value }
    if let compatibility, let value = node.props[compatibility]?.intValue { return value }
    return node.int(canonical)
  }
}

private struct SemanticsOptionalText: ViewModifier {
  let label: String?
  let hint: String?
  let value: String?

  func body(content: Content) -> some View {
    content
      .modifier(OptionalSemanticsLabel(value: label))
      .modifier(OptionalSemanticsHint(value: hint))
      .modifier(OptionalSemanticsValue(value: value))
  }
}

private struct OptionalSemanticsLabel: ViewModifier {
  let value: String?
  func body(content: Content) -> some View {
    if let value { content.accessibilityLabel(Text(value)) } else { content }
  }
}

private struct OptionalSemanticsHint: ViewModifier {
  let value: String?
  func body(content: Content) -> some View {
    if let value { content.accessibilityHint(Text(value)) } else { content }
  }
}

private struct OptionalSemanticsValue: ViewModifier {
  let value: String?
  func body(content: Content) -> some View {
    if let value { content.accessibilityValue(Text(value)) } else { content }
  }
}

private struct SemanticsVisibility: ViewModifier {
  let hidden: Bool?
  func body(content: Content) -> some View {
    if let hidden { content.accessibilityHidden(hidden) } else { content }
  }
}

private struct SemanticsPrivacy: ViewModifier {
  let obscured: Bool?
  func body(content: Content) -> some View {
    if let obscured { content.privacySensitive(obscured) } else { content }
  }
}

private struct SemanticsTooltip: ViewModifier {
  let tooltip: String?
  func body(content: Content) -> some View {
    if let tooltip { content.help(tooltip) } else { content }
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
    if let disabled = node.bool("disabled") {
      entries.append(("Enabled", disabled ? "Disabled" : "Enabled"))
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
      entries.append(
        (
          "Length", maximum.map { "\(current) of \($0)" } ?? "\(current)"
        ))
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
      .modifier(SemanticsAdjustActions(node: node, events: events))
      .modifier(SemanticsDismissAction(node: node, events: events))
      .modifier(SemanticsNamedActions(node: node, events: events))
  }
}

/// Flet's canonical action is `on_click`/`click`. The `tap` fallback preserves
/// Ruflet clients that predate the source-driven wire contract.
private struct SemanticsDefaultAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    let configuration = RufletSemanticsConfiguration(node: node)
    if let event = configuration.handledEvent("click", compatibility: "tap") {
      if let hint = configuration.tapHint, !hint.isEmpty {
        content.accessibilityAction(named: Text(hint)) { events.fire(node, event) }
      } else {
        content.accessibilityAction(.default) { events.fire(node, event) }
      }
    } else {
      content
    }
  }
}

private struct SemanticsAdjustActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  func body(content: Content) -> some View {
    let configuration = RufletSemanticsConfiguration(node: node)
    let increase = configuration.handledEvent("increase")
    let decrease = configuration.handledEvent("decrease")
    if increase != nil || decrease != nil {
      content.accessibilityAdjustableAction { direction in
        switch direction {
        case .increment:
          if let increase { events.fire(node, increase) }
        case .decrement:
          if let decrease { events.fire(node, decrease) }
        @unknown default: break
        }
      }
    } else {
      content
    }
  }
}

private struct SemanticsDismissAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  func body(content: Content) -> some View {
    let configuration = RufletSemanticsConfiguration(node: node)
    if let dismiss = configuration.handledEvent("dismiss") {
      content
        .accessibilityAction(.escape) { events.fire(node, dismiss) }
        // The pinned Flet control attaches `onLongPress` to the same dismiss
        // callback. VoiceOver exposes that secondary activation in its rotor.
        .accessibilityAction(named: Text(configuration.longPressHint ?? "Long press")) {
          events.fire(node, dismiss)
        }
    } else {
      content
    }
  }
}

private struct SemanticsNamedActions: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    content
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "scroll_left", label: "Scroll left")
      )
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "scroll_right", label: "Scroll right")
      )
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "scroll_up", label: "Scroll up")
      )
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "scroll_down", label: "Scroll down")
      )
      .modifier(
        NamedSemanticsAction(node: node, events: events, canonicalEvent: "copy", label: "Copy")
      )
      .modifier(
        NamedSemanticsAction(node: node, events: events, canonicalEvent: "cut", label: "Cut")
      )
      .modifier(
        NamedSemanticsAction(node: node, events: events, canonicalEvent: "paste", label: "Paste")
      )
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "move_cursor_forward_by_character",
          label: "Move cursor forward", data: .bool(true))
      )
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "move_cursor_backward_by_character",
          label: "Move cursor backward", data: .bool(true))
      )
      .modifier(
        NamedSemanticsAction(
          node: node, events: events, canonicalEvent: "set_text", label: "Set text",
          data: .string(node.string("value") ?? "")))
  }
}

private struct NamedSemanticsAction: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  let canonicalEvent: String
  let label: String
  var data: RufletValue = .null

  func body(content: Content) -> some View {
    if let event = RufletSemanticsConfiguration(node: node).handledEvent(canonicalEvent) {
      content.accessibilityAction(named: Text(label)) { events.fire(node, event, data: data) }
    } else {
      content
    }
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
        EmptyView()
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
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
        .textSelection(.enabled)
        .modifier(SelectionChangeReporter(node: node, events: events))
    } else {
      RufletWrapperError("SelectionArea.content must be provided and visible")
    }
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
        guard range.location != NSNotFound, range.location + range.length <= view.string.utf16.count
        else {
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
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
        .allowsHitTesting(false)
    } else {
      EmptyView()
    }
  }
}

/// `Shimmer` — a loading placeholder with a highlight sweeping across it.
struct ShimmerControlView: View {
  let node: ControlNode
  @State private var phase: CGFloat = -1

  private var configuration: RufletShimmerConfiguration {
    RufletShimmerConfiguration(node: node)
  }

  @ViewBuilder
  var body: some View {
    if node.controlID(forKey: "content") == nil {
      RufletWrapperError("Shimmer.content must be specified")
    } else if !configuration.hasValidColors {
      RufletWrapperError("Shimmer requires either gradient or base/highlight colors")
    } else {
      content
        .overlay {
          if configuration.enabled {
            shimmer
          }
        }
        .mask(content)
    }
  }

  @ViewBuilder private var content: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    }
  }

  private var shimmer: some View {
    let gradient =
      RufletWrapperGradient(node.props["gradient"])
      ?? RufletWrapperGradient(
        colors: [
          configuration.baseColor!, configuration.highlightColor!, configuration.baseColor!,
        ],
        stops: [0, 0.5, 1], begin: sweep.start, end: sweep.end)
    return GeometryReader { proxy in
      gradient.view
        .overlay(Color.clear)
        // The shimmer package translates by the child's extent, not a fixed
        // number of pixels. Measuring keeps the same speed and sweep on every
        // device and for every Ruflet layout.
        .offset(
          x: sweep.horizontal ? phase * proxy.size.width : 0,
          y: sweep.horizontal ? 0 : phase * proxy.size.height)
    }
    .onAppear {
      // `loop` is how many passes to make; Flutter treats zero as endless,
      // which is also the default.
      let passes = configuration.repeats
      let animation = Animation.linear(duration: configuration.period)
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

  /// Flutter's ShaderMask constructor defaults to `BlendMode.modulate`.
  /// SwiftUI names the equivalent component multiplication `multiply`.
  static func shaderBlendMode(_ value: String?) -> BlendMode {
    guard let value else { return .multiply }
    return value.lowercased() == "modulate" ? .multiply : ControlProps.blendMode(value)
  }
}

/// The constructor validation and defaults used by the vendored Shimmer
/// widget. In particular, omitted colours are an error in Flet; inventing a
/// grey/white pair here makes invalid Ruflet code appear valid only on Apple.
struct RufletShimmerConfiguration {
  let baseColor: Color?
  let highlightColor: Color?
  let hasGradient: Bool
  let period: Double
  let repeats: Int?
  let enabled: Bool

  init(node: ControlNode) {
    baseColor = MaterialPalette.color(node.string("base_color"))
    highlightColor = MaterialPalette.color(node.string("highlight_color"))
    hasGradient = RufletWrapperGradient(node.props["gradient"]) != nil
    period = RufletWrapperDefaults.shimmerPeriod(node.double("period"))
    repeats = RufletWrapperDefaults.shimmerRepeats(node.int("loop"))
    enabled = node.bool("disabled") != true
  }

  var hasValidColors: Bool {
    hasGradient || (baseColor != nil && highlightColor != nil)
  }
}

/// `ShaderMask` — masks its content with a gradient.
///
/// Flet passes an arbitrary shader; a linear or radial gradient is the part of
/// that surface SwiftUI can express, and it is what the control is used for.
struct ShaderMaskControlView: View {
  let node: ControlNode

  @ViewBuilder
  var body: some View {
    if let shader = RufletWrapperGradient(node.props["shader"]) {
      content
        .overlay {
          shader.view.blendMode(
            RufletWrapperDefaults.shaderBlendMode(node.string("blend_mode")))
        }
        .mask(content)
        .clipShape(
          RoundedRectangle(
            cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
    } else {
      RufletWrapperError("ShaderMask.shader must be provided")
    }
  }

  @ViewBuilder private var content: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
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

  @ViewBuilder
  var body: some View {
    if node.controlID(forKey: "content") == nil {
      RufletWrapperError("Hero.content must be provided and visible")
    } else if node.props["tag"] == nil {
      RufletWrapperError("Hero.tag must be provided")
    } else if let contentID = node.controlID(forKey: "content") {
      Group {
        ControlView(id: contentID, axis: .none)
      }
      .matchedGeometryEffect(
        id: RufletHeroTag(node.props["tag"]),
        in: pageNamespace ?? fallbackNamespace)
      .modifier(HeroGestureTransition(
        enabled: RufletHeroSemantics.transitionOnUserGestures(node)))
    }
  }
}

enum RufletHeroSemantics {
  static func transitionOnUserGestures(_ node: ControlNode) -> Bool {
    node.bool("transition_on_user_gestures") ?? false
  }
}

/// Flutter keeps a Hero flight attached to an interactive route gesture when
/// this flag is true. SwiftUI's corresponding transaction signal is
/// `isContinuous`; the enclosing native navigation transition still owns the
/// gesture and timing.
private struct HeroGestureTransition: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    content.transaction { transaction in
      if enabled { transaction.isContinuous = true }
    }
  }
}

/// Hero accepts any protocol value as its tag. Stringifying only string tags
/// made the integer and boolean tags used by Flet collide on Apple.
struct RufletHeroTag: Hashable {
  private let value: String

  init(_ value: RufletValue?) {
    switch value {
    case .string(let string): self.value = "string:\(string)"
    case .int(let integer): self.value = "int:\(integer)"
    case .double(let double): self.value = "double:\(double)"
    case .bool(let bool): self.value = "bool:\(bool)"
    case .null, nil: self.value = "null"
    default: self.value = "value:\(String(describing: value!))"
    }
  }
}

/// A gradient parser local to the wrapper controls. Flet accepts linear,
/// radial and sweep gradients for both Shimmer and ShaderMask; the previous
/// implementation silently discarded the latter two.
struct RufletWrapperGradient {
  enum Kind: Equatable { case linear, radial, sweep }
  let kind: Kind
  let stops: [Gradient.Stop]
  let begin: UnitPoint
  let end: UnitPoint
  let center: UnitPoint
  let radius: CGFloat
  let startAngle: Angle
  let endAngle: Angle
  let rotation: Angle

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return nil }
    let colors = (map["colors"]?.arrayValue ?? []).compactMap {
      MaterialPalette.color($0.stringValue)
    }
    guard colors.count > 1 else { return nil }
    let locations = map["stops"]?.arrayValue?.compactMap(\.doubleValue)
    stops = Self.stops(colors: colors, locations: locations)
    switch map["_type"]?.stringValue?.lowercased() {
    case "linear": kind = .linear
    case "radial": kind = .radial
    case "sweep": kind = .sweep
    default: return nil
    }
    begin = Self.point(map["begin"], fallback: .leading)
    end = Self.point(map["end"], fallback: .trailing)
    center = Self.point(map["center"], fallback: .center)
    radius = CGFloat(map["radius"]?.doubleValue ?? 0.5)
    startAngle = .radians(map["start_angle"]?.doubleValue ?? 0)
    endAngle = .radians(map["end_angle"]?.doubleValue ?? 0)
    rotation = .radians(map["rotation"]?.doubleValue ?? 0)
  }

  init(colors: [Color], stops locations: [Double], begin: UnitPoint, end: UnitPoint) {
    kind = .linear
    stops = Self.stops(colors: colors, locations: locations)
    self.begin = begin
    self.end = end
    center = .center
    radius = 0.5
    startAngle = .zero
    endAngle = .zero
    rotation = .zero
  }

  @ViewBuilder var view: some View {
    Group {
      switch kind {
      case .linear:
        Rectangle().fill(LinearGradient(stops: stops, startPoint: begin, endPoint: end))
      case .radial:
        GeometryReader { proxy in
          Rectangle().fill(
            RadialGradient(
              stops: stops, center: center, startRadius: 0,
              endRadius: radius * min(proxy.size.width, proxy.size.height)))
        }
      case .sweep:
        Rectangle().fill(
          AngularGradient(
            stops: stops, center: center, startAngle: startAngle, endAngle: endAngle))
      }
    }
    .rotationEffect(rotation)
  }

  private static func stops(colors: [Color], locations: [Double]?) -> [Gradient.Stop] {
    let resolved: [Double]
    if let locations, locations.count == colors.count {
      resolved = locations
    } else {
      resolved = colors.indices.map { Double($0) / Double(colors.count - 1) }
    }
    return zip(colors, resolved).map { Gradient.Stop(color: $0.0, location: $0.1) }
  }

  private static func point(_ value: RufletValue?, fallback: UnitPoint) -> UnitPoint {
    guard let alignment = ControlProps.continuousAlignment(value) else { return fallback }
    return UnitPoint(x: (alignment.x + 1) / 2, y: (alignment.y + 1) / 2)
  }
}

private struct RufletWrapperError: View {
  let message: String
  init(_ message: String) { self.message = message }
  var body: some View {
    Text(message).font(.caption).foregroundStyle(.red)
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
            let wasMaximized =
              window.styleMask.contains(.fullScreen)
              || window.standardWindowButton(.zoomButton)?.state == .on
            window.performZoom(nil)
            events.fire(
              node, "double_tap",
              data: .string(wasMaximized ? "unmaximize" : "maximize"))
          }
        )
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

/// `AutofillGroup` keeps related native text inputs in one subtree. UIKit and
/// AppKit infer autofill grouping from the native view hierarchy and the text
/// inputs' content types, so this is a presentation-free native container.
struct AutofillGroupControlView: View {
  let node: ControlNode

  @ViewBuilder var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
        .onDisappear { RufletAutofillGroupSemantics.dispose(node) }
    } else {
      RufletWrapperError("AutofillGroup control has no content.")
    }
  }
}

enum RufletAutofillGroupSemantics {
  enum DisposeAction: String, Equatable {
    case commit
    case cancel
  }

  /// Flet defaults missing and unknown values to commit.
  static func disposeAction(_ node: ControlNode) -> DisposeAction {
    DisposeAction(rawValue: node.string("dispose_action")?.lowercased() ?? "") ?? .commit
  }

  @MainActor
  static func dispose(_ node: ControlNode) {
    #if canImport(UIKit)
      // Resigning the group commits UIKit's active text/autofill session. iOS
      // exposes no public cancel-session API; cancel therefore leaves the
      // current context uncommitted, matching the observable Flet distinction.
      if disposeAction(node) == .commit {
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
    #elseif canImport(AppKit)
      if disposeAction(node) == .commit {
        NSApp.keyWindow?.makeFirstResponder(nil)
      }
    #endif
  }
}
