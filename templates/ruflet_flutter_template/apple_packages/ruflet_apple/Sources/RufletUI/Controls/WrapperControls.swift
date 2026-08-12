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
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    Group {
      if let error = RufletScreenshotSemantics.validationError(
        contentID: contentID, contentIsVisible: contentIsVisible)
      {
        RufletWrapperError(error)
      } else {
        content
      }
    }
      .rufletCommandHandler(node.id) { call, completion in
        handle(call, completion: completion)
      }
  }

  private var contentID: Int? { node.controlID(forKey: "content") }

  private var contentIsVisible: Bool {
    guard let contentID, let content = store.node(contentID) else { return false }
    return content.bool("visible") != false
  }

  @ViewBuilder
  private var content: some View {
    if let contentID {
      ControlView(id: contentID, axis: .none)
    } else {
      EmptyView()
    }
  }

  private func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    if let error = RufletScreenshotSemantics.commandError(call.name) {
      return completion(.failure(error))
    }
    guard RufletScreenshotSemantics.validationError(
      contentID: contentID, contentIsVisible: contentIsVisible) == nil
    else {
      return completion(.failure(RufletServiceError.failed(
        RufletScreenshotSemantics.missingContentError)))
    }
    guard #available(iOS 16.0, macOS 13.0, *) else {
      return completion(
        .failure(RufletServiceError.unavailable(RufletScreenshotSemantics.availabilityError)))
    }

    let request = RufletScreenshotCaptureRequest(call: call)
    if request.delayMilliseconds > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + request.delayMilliseconds / 1_000) {
        render(request, completion: completion)
      }
    } else {
      render(request, completion: completion)
    }
  }

  private func render(
    _ request: RufletScreenshotCaptureRequest,
    completion: @escaping RufletMethodCompletion
  ) {
    let renderer = ImageRenderer(
      content:
        content
        .environmentObject(store)
        .environment(\.rufletEvents, events))
    renderer.scale = request.pixelRatio ?? displayScale

    #if canImport(UIKit)
      guard let data = renderer.uiImage?.pngData() else {
        return completion(RufletScreenshotSemantics.captureResult(pngData: nil))
      }
    #elseif canImport(AppKit)
      guard let image = renderer.nsImage,
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
      else {
        return completion(RufletScreenshotSemantics.captureResult(pngData: nil))
      }
    #else
      let data = Data()
    #endif

    completion(RufletScreenshotSemantics.captureResult(pngData: data))
  }
}

struct RufletScreenshotCaptureRequest: Equatable {
  let delayMilliseconds: Double
  let pixelRatio: CGFloat?

  init(call: RufletMethodCall) {
    delayMilliseconds = RufletScreenshotSemantics.delayMilliseconds(call.argument("delay"))
    pixelRatio = call.argument("pixel_ratio")?.doubleValue.map { CGFloat($0) }
  }
}

enum RufletScreenshotSemantics {
  static let missingContentError = "Screenshot.content must be provided and visible"
  static let availabilityError = "Screenshot capture needs iOS 16 / macOS 13"
  static let rasterizationError = "The view could not be rasterised"

  static func validationError(contentID: Int?, contentIsVisible: Bool) -> String? {
    contentID != nil && contentIsVisible ? nil : missingContentError
  }

  static func commandError(_ name: String) -> RufletServiceError? {
    name == "capture" ? nil : .unsupportedMethod(type: "Screenshot", method: name)
  }

  /// Flet's `parseDuration` treats a scalar as milliseconds and sums every
  /// component of a Duration map. Duration extension values carry microseconds.
  static func delayMilliseconds(_ value: RufletValue?) -> Double {
    guard let value, !value.isNull else { return 20 }
    switch value {
    case .int(let milliseconds):
      return Double(milliseconds)
    case .double:
      // `parseDuration` delegates to Dart's integer parser; a fractional
      // numeric string does not parse as an Int and therefore becomes zero.
      return 0
    case .extended(type: 3, let microseconds):
      return Double(Int64(microseconds) ?? 0) / 1_000
    case .map(let components):
      func integer(_ key: String) -> Int64 {
        switch components[key] {
        case .int(let value): return value
        case .string(let value), .extended(_, let value): return Int64(value) ?? 0
        default: return 0
        }
      }
      let microseconds = integer("microseconds")
        + 1_000 * integer("milliseconds")
        + 1_000_000 * integer("seconds")
        + 60_000_000 * integer("minutes")
        + 3_600_000_000 * integer("hours")
        + 86_400_000_000 * integer("days")
      return Double(microseconds) / 1_000
    default:
      return 0
    }
  }

  static func captureResult(pngData: Data?) -> Result<RufletValue, Error> {
    guard let pngData else {
      return .failure(RufletServiceError.failed(rasterizationError))
    }
    return .success(.binary([UInt8](pngData)))
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
        .environment(\.rufletSelectionAreaChange) { selection in
          events.fire(node, "change", data: RufletSelectionAreaPayload.data(selection))
        }
    } else {
      RufletWrapperError("SelectionArea.content must be provided and visible")
    }
  }
}

enum RufletSelectionAreaPayload {
  static func selection(in source: String, range: NSRange) -> String? {
    guard range.location != NSNotFound, range.length > 0,
      range.location >= 0, NSMaxRange(range) <= source.utf16.count
    else { return nil }
    return (source as NSString).substring(with: range)
  }

  static func data(_ selection: String?) -> RufletValue {
    selection.map(RufletValue.string) ?? .null
  }
}

private struct RufletSelectionAreaChangeKey: EnvironmentKey {
  static let defaultValue: ((String?) -> Void)? = nil
}

extension EnvironmentValues {
  var rufletSelectionAreaChange: ((String?) -> Void)? {
    get { self[RufletSelectionAreaChangeKey.self] }
    set { self[RufletSelectionAreaChangeKey.self] = newValue }
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
  @EnvironmentObject private var store: ControlStore
  @State private var phase: CGFloat = -1

  private var configuration: RufletShimmerConfiguration {
    RufletShimmerConfiguration(node: node)
  }

  @ViewBuilder
  var body: some View {
    if let error = configuration.validationError(contentIsVisible: contentIsVisible) {
      RufletWrapperError(error)
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

  private var contentIsVisible: Bool {
    guard let id = configuration.contentID, let content = store.node(id) else { return false }
    return content.bool("visible") != false
  }

  @ViewBuilder private var content: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    }
  }

  private var shimmer: some View {
    let gradient = configuration.gradient
      ?? RufletWrapperGradient(
        colors: [
          configuration.baseColor!, configuration.highlightColor!, configuration.baseColor!,
        ],
        stops: [0, 0.5, 1], begin: configuration.direction.start,
        end: configuration.direction.end)
    return GeometryReader { proxy in
      gradient.view
        .overlay(Color.clear)
        // The shimmer package translates by the child's extent, not a fixed
        // number of pixels. Measuring keeps the same speed and sweep on every
        // device and for every Ruflet layout.
        .offset(
          x: configuration.direction.horizontal
            ? phase * configuration.direction.phaseMultiplier * proxy.size.width : 0,
          y: configuration.direction.horizontal
            ? 0 : phase * configuration.direction.phaseMultiplier * proxy.size.height)
    }
    .id(configuration.animationIdentity)
    .onAppear {
      // `loop` is how many passes to make; Flutter treats zero as endless,
      // which is also the default.
      phase = -1
      DispatchQueue.main.async {
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
  }
}

enum RufletShimmerDirection: String, Equatable {
  case ltr
  case rtl
  case ttb
  case btt

  init(_ raw: String?) {
    switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "rtl", "righttoleft": self = .rtl
    case "ttb", "toptobottom": self = .ttb
    case "btt", "bottomtotop": self = .btt
    default: self = .ltr
    }
  }

  var start: UnitPoint {
    switch self {
    case .ltr: return .leading
    case .rtl: return .trailing
    case .ttb: return .top
    case .btt: return .bottom
    }
  }

  var end: UnitPoint {
    switch self {
    case .ltr: return .trailing
    case .rtl: return .leading
    case .ttb: return .bottom
    case .btt: return .top
    }
  }

  var horizontal: Bool { self == .ltr || self == .rtl }
  var phaseMultiplier: CGFloat { self == .rtl || self == .btt ? -1 : 1 }
}

enum RufletWrapperDefaults {
  static func screenshotDelay(_ milliseconds: Double?) -> Double {
    milliseconds ?? 20
  }

  static func shimmerPeriod(_ milliseconds: Double?) -> Double {
    max(milliseconds ?? 1500, 0) / 1_000
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
  static let missingContentError = "Shimmer.content must be specified"
  static let missingColorsError = "Shimmer requires either gradient or base/highlight colors"

  let contentID: Int?
  let baseColor: Color?
  let highlightColor: Color?
  let gradient: RufletWrapperGradient?
  let direction: RufletShimmerDirection
  let period: Double
  let repeats: Int?
  let enabled: Bool

  init(node: ControlNode) {
    contentID = node.controlID(forKey: "content")
    baseColor = MaterialPalette.color(node.string("base_color"))
    highlightColor = MaterialPalette.color(node.string("highlight_color"))
    gradient = RufletWrapperGradient(node.props["gradient"])
    direction = RufletShimmerDirection(node.string("direction"))
    period = ControlProps.animationDurationSeconds(node.props["period"])
      ?? RufletWrapperDefaults.shimmerPeriod(nil)
    repeats = RufletWrapperDefaults.shimmerRepeats(node.int("loop"))
    enabled = node.bool("disabled") != true
  }

  var hasValidColors: Bool {
    gradient != nil || (baseColor != nil && highlightColor != nil)
  }

  func validationError(contentIsVisible: Bool) -> String? {
    guard contentID != nil, contentIsVisible else { return Self.missingContentError }
    guard hasValidColors else { return Self.missingColorsError }
    return nil
  }

  var animationIdentity: String {
    "\(direction.rawValue):\(period):\(repeats.map(String.init) ?? "infinite"):\(enabled)"
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
    let presentation = RufletShaderMaskPresentation(node: node)
    if let shader = presentation.shader {
      content
        .overlay {
          shader.view.blendMode(presentation.blendMode)
        }
        .mask(content)
        .modifier(ShaderMaskCornerClip(radii: presentation.borderRadii))
    } else {
      RufletWrapperError(RufletShaderMaskPresentation.missingShaderError)
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

struct RufletShaderMaskPresentation {
  static let missingShaderError = "ShaderMask.shader must be provided"
  let node: ControlNode

  var shader: RufletWrapperGradient? { RufletWrapperGradient(node.props["shader"]) }
  var blendModeToken: String { node.string("blend_mode") ?? "modulate" }
  var blendMode: BlendMode { RufletWrapperDefaults.shaderBlendMode(blendModeToken) }
  var borderRadii: RufletCornerRadii? { ControlProps.cornerRadii(node.props["border_radius"]) }
  var contentID: Int? { node.controlID(forKey: "content") }
}

private struct ShaderMaskCornerClip: ViewModifier {
  let radii: RufletCornerRadii?

  func body(content: Content) -> some View {
    if let radii {
      content.clipShape(RufletRoundedRectangle(radii: radii))
    } else {
      content
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
  @EnvironmentObject private var store: ControlStore
  @Namespace private var fallbackNamespace
  @Environment(\.rufletHeroNamespace) private var pageNamespace
  @Environment(\.rufletHeroProvidesGeometry) private var providesGeometry

  @ViewBuilder
  var body: some View {
    let contentID = node.controlID(forKey: "content")
    let contentIsVisible = contentID.flatMap(store.node).map { $0.bool("visible") != false } ?? false
    if let error = RufletHeroSemantics.validationError(
      contentID: contentID,
      contentIsVisible: contentIsVisible,
      tag: node.props["tag"])
    {
      RufletWrapperError(error)
    } else if let contentID, let tag = node.props["tag"] {
      Group {
        ControlView(id: contentID, axis: .none)
      }
      .matchedGeometryEffect(
        id: RufletHeroTag(tag),
        in: pageNamespace ?? fallbackNamespace,
        isSource: providesGeometry)
      .modifier(HeroGestureTransition(
        enabled: RufletHeroSemantics.transitionOnUserGestures(node)))
    }
  }
}

enum RufletHeroSemantics {
  static let missingContentError = "Hero.content must be provided and visible"
  static let missingTagError = "Hero.tag must be provided"

  static func transitionOnUserGestures(_ node: ControlNode) -> Bool {
    node.bool("transition_on_user_gestures") ?? false
  }

  static func providesGeometry(viewID: Int, activeViewID: Int) -> Bool {
    viewID == activeViewID
  }

  static func validationError(
    contentID: Int?,
    contentIsVisible: Bool,
    tag: RufletValue?
  ) -> String? {
    guard contentID != nil, contentIsVisible else { return missingContentError }
    guard let tag, !tag.isNull else { return missingTagError }
    return nil
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
  private struct MapEntry: Hashable {
    let key: String
    let value: Identity
  }

  private indirect enum Identity: Hashable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case binary([UInt8])
    case array([Identity])
    case map([MapEntry])
    case extended(Int8, String)
    case controlRef(Int)
  }

  private let value: Identity

  init(_ value: RufletValue?) {
    self.value = Self.identity(value ?? .null)
  }

  private static func identity(_ value: RufletValue) -> Identity {
    switch value {
    case .null: return .null
    case .bool(let value): return .bool(value)
    case .int(let value): return .int(value)
    case .double(let value): return .double(value)
    case .string(let value): return .string(value)
    case .binary(let value): return .binary(value)
    case .array(let values): return .array(values.map(identity))
    case .map(let values):
      return .map(values.keys.sorted().map {
        MapEntry(key: $0, value: identity(values[$0]!))
      })
    case .extended(let type, let value): return .extended(type, value)
    case .controlRef(let id): return .controlRef(id)
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
  let focal: UnitPoint?
  let focalRadius: CGFloat
  let startAngle: Angle
  let endAngle: Angle
  let rotation: Angle
  let tileMode: String

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
    focal = Self.optionalPoint(map["focal"])
    focalRadius = CGFloat(map["focal_radius"]?.doubleValue ?? 0)
    startAngle = .radians(map["start_angle"]?.doubleValue ?? 0)
    endAngle = .radians(map["end_angle"]?.doubleValue ?? Double.pi * 2)
    rotation = .radians(map["rotation"]?.doubleValue ?? 0)
    tileMode = map["tile_mode"]?.stringValue?.lowercased() ?? "clamp"
  }

  init(colors: [Color], stops locations: [Double], begin: UnitPoint, end: UnitPoint) {
    kind = .linear
    stops = Self.stops(colors: colors, locations: locations)
    self.begin = begin
    self.end = end
    center = .center
    radius = 0.5
    focal = nil
    focalRadius = 0
    startAngle = .zero
    endAngle = .radians(Double.pi * 2)
    rotation = .zero
    tileMode = "clamp"
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

  private static func optionalPoint(_ value: RufletValue?) -> UnitPoint? {
    guard let alignment = ControlProps.continuousAlignment(value) else { return nil }
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

  @ViewBuilder
  var body: some View {
    if let contentID = WindowDragAreaPresentation(node: node).contentID {
      ControlView(id: contentID, axis: .none)
        .modifier(WindowDragGesture(node: node, events: events))
    } else {
      RufletWrapperError(WindowDragAreaPresentation.missingContentError)
    }
  }
}

struct WindowDragAreaPresentation {
  static let missingContentError = "WindowDragArea.content must be provided and visible"
  let node: ControlNode
  var contentID: Int? { node.controlID(forKey: "content") }
  var maximizable: Bool { node.bool("maximizable") ?? true }

  static func doubleTapPayload(wasMaximized: Bool) -> RufletValue {
    .string(wasMaximized ? "unmaximize" : "maximize")
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
            guard WindowDragAreaPresentation(node: node).maximizable,
              let window = NSApp.keyWindow
            else { return }
            let wasMaximized =
              window.styleMask.contains(.fullScreen)
              || window.standardWindowButton(.zoomButton)?.state == .on
            window.performZoom(nil)
            events.fire(
              node, "double_tap",
              data: WindowDragAreaPresentation.doubleTapPayload(
                wasMaximized: wasMaximized))
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

private struct RufletHeroProvidesGeometryKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  var rufletHeroNamespace: Namespace.ID? {
    get { self[RufletHeroNamespaceKey.self] }
    set { self[RufletHeroNamespaceKey.self] = newValue }
  }

  var rufletHeroProvidesGeometry: Bool {
    get { self[RufletHeroProvidesGeometryKey.self] }
    set { self[RufletHeroProvidesGeometryKey.self] = newValue }
  }
}

/// `AutofillGroup` keeps related native text inputs in one subtree. UIKit and
/// AppKit infer autofill grouping from the native view hierarchy and the text
/// inputs' content types, so this is a presentation-free native container.
struct AutofillGroupControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  @ViewBuilder var body: some View {
    let contentID = node.controlID(forKey: "content")
    let contentIsVisible = contentID.flatMap(store.node).map { $0.bool("visible") != false } ?? false
    if let error = RufletAutofillGroupSemantics.validationError(
      contentID: contentID, contentIsVisible: contentIsVisible)
    {
      RufletWrapperError(error)
    } else if let contentID {
      ControlView(id: contentID, axis: .none)
        .onDisappear { RufletAutofillGroupSemantics.dispose(node) }
    }
  }
}

enum RufletAutofillGroupSemantics {
  static let missingContentError = "AutofillGroup control has no content."

  enum DisposeAction: String, Equatable {
    case commit
    case cancel
  }

  /// Flet defaults missing and unknown values to commit.
  static func disposeAction(_ node: ControlNode) -> DisposeAction {
    DisposeAction(rawValue: node.string("dispose_action")?.lowercased() ?? "") ?? .commit
  }

  /// Flet resolves the content slot through `buildWidget`, which rejects both
  /// absent controls and controls removed by `visible: false`.
  static func validationError(contentID: Int?, contentIsVisible: Bool) -> String? {
    guard contentID != nil, contentIsVisible else { return missingContentError }
    return nil
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
