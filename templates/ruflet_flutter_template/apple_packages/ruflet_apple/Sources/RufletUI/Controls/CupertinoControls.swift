import RufletEngine
import RufletProtocol
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// The Cupertino family.
///
/// These are the controls a Flet app uses to look iOS-native — which is what
/// SwiftUI renders by default on both platforms this engine targets. Most of
/// them therefore map onto the same native control as their Material
/// counterpart; the ones that differ genuinely (action sheets, pickers, the
/// tinted button styles) get their own treatment.

/// `CupertinoButton` / `CupertinoFilledButton` / `CupertinoTintedButton`.
struct CupertinoButtonControlView: View {
  let node: ControlNode

  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL
  @EnvironmentObject private var store: ControlStore
  @FocusState private var focused: Bool
  @State private var longPressConsumedClick = false

  @ViewBuilder
  var body: some View {
    nativeButton
      .modifier(CupertinoButtonNativeSemantics(
        presentation: presentation, focused: focused))
      .modifier(CupertinoButtonLongPress(
        enabled: !presentation.disabled && node.handlesEvent("long_press"),
        action: handleLongPress))
      .modifier(CupertinoPressOpacity(
        value: presentation.pressedOpacity, enabled: !presentation.disabled))
      .focused($focused)
      .onAppear { focused = presentation.autofocus }
      .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
      .rufletCommandHandler(node.id) { call, completion in
        guard call.name == "focus" else {
          completion(.failure(rufletUnsupported(node.type, call)))
          return
        }
        focused = true
        completion(.success(.null))
      }
      .disabled(presentation.disabled)
  }

  private var presentation: CupertinoButtonPresentation {
    CupertinoButtonPresentation(node: node)
  }

  @ViewBuilder
  private var nativeButton: some View {
    let button = Button(action: activate) { label }
    switch presentation.appearance {
    case .borderedProminent: button.buttonStyle(.borderedProminent)
    case .bordered: button.buttonStyle(.bordered)
    case .borderless: button.buttonStyle(.borderless)
    }
  }

  @ViewBuilder
  private var label: some View {
    Group {
      if hasVisibleIcon && hasVisibleContent {
        HStack(spacing: CupertinoButtonPresentation.iconContentSpacing) {
          icon
          content
        }
      } else if hasVisibleIcon {
        icon
      } else if hasVisibleContent {
        content
      } else {
        Text("")
      }
    }
    // An explicit padding value belongs inside CupertinoButton's decoration.
    // When omitted, the native button family owns its visual insets while the
    // exact Flet/Flutter defaults remain pinned in the presentation contract.
    .modifier(OptionalEdgeInsets(insets: presentation.explicitPadding))
  }

  @ViewBuilder
  private var icon: some View {
    if let iconID = node.controlID(forKey: "icon"), isVisible(iconID) {
      ControlView(id: iconID, axis: .none)
    } else if node.controlID(forKey: "icon") == nil, node.props["icon"] != nil {
      RufletIcon(
        value: node.props["icon"], size: CupertinoButtonPresentation.iconSize,
        color: MaterialPalette.color(node.string("icon_color")))
    }
  }

  @ViewBuilder
  private var content: some View {
    if let contentID = node.controlID(forKey: "content"), isVisible(contentID) {
      ControlView(id: contentID, axis: .none)
    } else if node.controlID(forKey: "content") == nil,
      let text = node.string("content") ?? node.string("text")
    {
      Text(text)
    }
  }

  private var hasVisibleIcon: Bool {
    if let id = node.controlID(forKey: "icon") { return isVisible(id) }
    return node.props["icon"]?.isNull == false
  }

  private var hasVisibleContent: Bool {
    if let id = node.controlID(forKey: "content") { return isVisible(id) }
    return node.string("content") != nil || node.string("text") != nil
  }

  private func isVisible(_ id: Int) -> Bool {
    store.node(id)?.bool("visible") != false
  }

  private func activate() {
    guard !presentation.disabled else { return }
    if longPressConsumedClick {
      longPressConsumedClick = false
      return
    }
    if let url = node.string("url").flatMap(URL.init(string:)) { openURL(url) }
    events.fire(node, "click")
  }

  private func handleLongPress() {
    longPressConsumedClick = true
    events.fire(node, "long_press")
    // SwiftUI normally lets the long-press recognizer suppress Button's tap.
    // Keep the flag briefly as a guard for platform releases
    // where both callbacks are delivered for the same pointer sequence.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      if longPressConsumedClick { longPressConsumedClick = false }
    }
  }
}

enum CupertinoButtonVariant: Equatable {
  case plain
  case filled
  case tinted

  init(wireType: String) {
    switch wireType {
    case "CupertinoFilledButton", "FilledButton": self = .filled
    case "CupertinoTintedButton", "FilledTonalButton": self = .tinted
    default: self = .plain
    }
  }
}

enum CupertinoButtonSizeStyle: String, Equatable {
  case small
  case medium
  case large
}

enum CupertinoNativeButtonAppearance: Equatable {
  case borderedProminent
  case bordered
  case borderless
}

enum CupertinoButtonSlot: Equatable {
  case none
  case scalar
  case control(Int)
}

/// The source-pinned constructor values Flet passes to Flutter's
/// `CupertinoButton`, independent of how SwiftUI chooses to draw them.
struct CupertinoButtonPresentation {
  let node: ControlNode

  static let iconContentSpacing: CGFloat = 8
  static let iconSize: CGFloat = 20
  static let focusOutlineWidth: CGFloat = 3.5
  static let defaultDisabledBackgroundToken = "tertiarySystemFill"
  static let defaultFocusColorOpacity = 0.80
  static let defaultFocusColorBrightness = 0.69
  static let defaultFocusColorSaturation = 0.835

  var variant: CupertinoButtonVariant { CupertinoButtonVariant(wireType: node.type) }
  var disabled: Bool { node.bool("disabled") ?? false }
  var autofocus: Bool { node.bool("autofocus") ?? false }
  var pressedOpacity: Double { node.double("opacity_on_click") ?? 0.4 }

  var sizeStyle: CupertinoButtonSizeStyle {
    CupertinoButtonSizeStyle(rawValue: node.string("size")?.lowercased() ?? "") ?? .large
  }

  var defaultMinimumSide: CGFloat {
    switch sizeStyle {
    case .small: return 28
    case .medium: return 32
    case .large: return 44
    }
  }

  var minimumSize: CGSize {
    guard let size = node.props["min_size"]?.mapValue else {
      return CGSize(width: defaultMinimumSide, height: defaultMinimumSide)
    }
    return CGSize(
      width: CGFloat(size["width"]?.doubleValue ?? Double(defaultMinimumSide)),
      height: CGFloat(size["height"]?.doubleValue ?? Double(defaultMinimumSide)))
  }

  var explicitPadding: EdgeInsets? { ControlProps.edgeInsets(node.props["padding"]) }

  var resolvedPadding: EdgeInsets {
    if let explicitPadding { return explicitPadding }
    switch sizeStyle {
    case .small: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    case .medium: return EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
    case .large: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
    }
  }

  var alignment: Alignment {
    ControlProps.alignment(node.props["alignment"]) ?? .center
  }

  // Flet explicitly passes 8 even though Flutter's newer size presets have
  // their own radii, so every size keeps this value unless Ruby overrides it.
  var borderRadius: CGFloat { RufletThemeDefaults.cupertinoButtonRadius(node) }

  var backgroundToken: String? { node.string("bgcolor") }
  var foregroundToken: String? { node.string("color") }
  var focusColorToken: String? { node.string("focus_color") }
  var disabledBackgroundToken: String {
    node.string("disabled_bgcolor") ?? Self.defaultDisabledBackgroundToken
  }

  func slot(_ key: String) -> CupertinoButtonSlot {
    if let id = node.controlID(forKey: key) { return .control(id) }
    guard node.props[key]?.isNull == false else { return .none }
    return .scalar
  }

  var hasBackground: Bool {
    variant != .plain || backgroundToken != nil
  }

  var appearance: CupertinoNativeButtonAppearance {
    switch variant {
    case .filled: return .borderedProminent
    case .tinted: return .bordered
    case .plain:
      return hasBackground ? .borderedProminent : .borderless
    }
  }

  var foreground: Color? { MaterialPalette.color(foregroundToken) }

  var tint: Color? {
    if disabled, hasBackground {
      return MaterialPalette.color(node.string("disabled_bgcolor"))
        ?? Self.nativeTertiarySystemFill
    }
    return MaterialPalette.color(backgroundToken)
  }

  var focusColor: Color {
    MaterialPalette.color(focusColorToken)
      ?? Color.accentColor.opacity(Self.defaultFocusColorOpacity)
  }

  var controlSize: ControlSize {
    switch sizeStyle {
    case .small: return .small
    case .medium: return .regular
    case .large: return .large
    }
  }

  private static var nativeTertiarySystemFill: Color? {
    #if os(iOS)
      return Color(uiColor: .tertiarySystemFill)
    #else
      // AppKit has no `tertiarySystemFill` color. Leaving the tint unspecified
      // lets the native disabled button style resolve the platform fill.
      return nil
    #endif
  }
}

private struct CupertinoButtonNativeSemantics: ViewModifier {
  let presentation: CupertinoButtonPresentation
  let focused: Bool

  func body(content: Content) -> some View {
    content
      .controlSize(presentation.controlSize)
      .modifier(OptionalTint(color: presentation.tint))
      .modifier(OptionalForeground(color: presentation.foreground))
      .frame(
        minWidth: presentation.minimumSize.width,
        minHeight: presentation.minimumSize.height,
        alignment: presentation.alignment)
      .clipShape(RoundedRectangle(
        cornerRadius: presentation.borderRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: presentation.borderRadius, style: .continuous)
          .stroke(
            focused ? presentation.focusColor : .clear,
            lineWidth: CupertinoButtonPresentation.focusOutlineWidth))
  }
}

private struct CupertinoButtonLongPress: ViewModifier {
  let enabled: Bool
  let action: () -> Void

  func body(content: Content) -> some View {
    if enabled {
      content.simultaneousGesture(LongPressGesture().onEnded { _ in action() })
    } else {
      content
    }
  }
}

/// Cupertino's press feedback is a fade, and the button names how far.
private struct CupertinoPressOpacity: ViewModifier {
  let value: Double
  let enabled: Bool
  @State private var pressed = false

  func body(content: Content) -> some View {
    content
      .opacity(pressed ? value : 1)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            guard enabled, !pressed else { return }
            withAnimation(.easeInOut(duration: 0.12)) { pressed = true }
          }
          .onEnded { _ in
            guard pressed else { return }
            withAnimation(.easeOut(duration: 0.18)) { pressed = false }
          })
  }
}

private struct OptionalEdgeInsets: ViewModifier {
  let insets: EdgeInsets?
  func body(content: Content) -> some View {
    if let insets { content.padding(insets) } else { content }
  }
}

/// `CupertinoSwitch` — the same native toggle, which is already the iOS one.
struct CupertinoSwitchControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletListTileClicks) private var listTileClicks
  @Environment(\.rufletServerURL) private var serverURL
  @FocusState private var focused: Bool
  @State private var currentValue: Bool
  @State private var hovered = false

  init(node: ControlNode) {
    self.node = node
    _currentValue = State(initialValue: CupertinoSwitchPresentation(node: node).value)
  }

  var body: some View {
    let presentation = CupertinoSwitchPresentation(
      node: node, value: currentValue, focused: focused, hovered: hovered)
    HStack(spacing: 8) {
      if presentation.labelPosition == .left { label(presentation) }
      Toggle("", isOn: binding)
        .labelsHidden()
        .toggleStyle(.switch)
        .modifier(OptionalTint(color: presentation.trackColor))
        .overlay(thumbOverlay(presentation))
        .modifier(SwitchTrackOutline(presentation: presentation))
      if presentation.labelPosition == .right { label(presentation) }
    }
    .modifier(ListTileToggleListener(notifier: listTileClicks, action: toggleFromListTile))
    .focused($focused)
    .onHover { hovered = $0 }
    .onAppear {
      currentValue = CupertinoSwitchPresentation(node: node).value
      focused = presentation.autofocus
    }
    .onChange(of: node.bool("value")) { _ in
      currentValue = CupertinoSwitchPresentation(node: node).value
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .disabled(presentation.disabled)
  }

  private var binding: Binding<Bool> {
    Binding(
      get: { currentValue },
      set: {
        guard node.bool("disabled") != true else { return }
        currentValue = $0
        RufletValueControlEvents.commit(
          node, value: .bool($0), payload: .none, to: events)
      })
  }

  private func toggleFromListTile() {
    guard node.bool("disabled") != true else { return }
    binding.wrappedValue.toggle()
  }

  @ViewBuilder
  private func label(_ presentation: CupertinoSwitchPresentation) -> some View {
    if let text = presentation.label {
      Text(text)
        .foregroundColor(presentation.disabled ? .secondary : nil)
        .contentShape(Rectangle())
        .onTapGesture {
          guard !presentation.disabled else { return }
          binding.wrappedValue.toggle()
        }
    }
  }

  @ViewBuilder
  private func thumbOverlay(_ presentation: CupertinoSwitchPresentation) -> some View {
    if presentation.hasThumbDecoration {
      HStack {
        if presentation.value { Spacer(minLength: 0) }
        ZStack {
          Circle().fill(presentation.thumbColor ?? .white)
          if !presentation.thumbImageSource.isMissing {
            CupertinoSwitchThumbImage(
              source: presentation.thumbImageSource, serverURL: serverURL,
              onError: { events.fire(node, "image_error", data: .string($0)) })
              .clipShape(Circle())
          }
          if let icon = presentation.thumbIcon {
            RufletIcon(value: icon, size: 12, color: presentation.thumbIconColor)
          }
        }
        .frame(width: 22, height: 22)
        if !presentation.value { Spacer(minLength: 0) }
      }
      .padding(.horizontal, 3)
      .allowsHitTesting(false)
    }
  }
}

enum CupertinoSwitchLabelPosition: Equatable {
  case left
  case right
}

/// Exact Flet/Flutter value and widget-state resolution kept independently of
/// SwiftUI's native switch rendering so it can be parity-tested.
struct CupertinoSwitchPresentation {
  let node: ControlNode
  let value: Bool
  let focused: Bool
  let hovered: Bool

  init(
    node: ControlNode, value: Bool? = nil, focused: Bool = false, hovered: Bool = false
  ) {
    self.node = node
    self.value = value ?? node.bool("value") ?? false
    self.focused = focused
    self.hovered = hovered
  }

  var disabled: Bool { node.bool("disabled") ?? false }
  var autofocus: Bool { node.bool("autofocus") ?? false }

  var label: String? {
    guard let value = node.string("label"), !value.isEmpty else { return nil }
    return value
  }

  var labelPosition: CupertinoSwitchLabelPosition {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  var states: Set<RufletWidgetState> {
    var extra: Set<RufletWidgetState> = []
    if focused { extra.insert(.focused) }
    if hovered { extra.insert(.hovered) }
    return node.widgetStates(selected: value, extra: extra)
  }

  var trackColorToken: String? {
    value ? node.string("active_track_color") : node.string("inactive_track_color")
  }
  var trackColor: Color? { MaterialPalette.color(trackColorToken) }

  var thumbColorToken: String {
    if !value, let inactive = node.string("inactive_thumb_color") { return inactive }
    return node.string("thumb_color") ?? "white"
  }
  var thumbColor: Color? { MaterialPalette.color(thumbColorToken) }

  var thumbIcon: RufletValue? {
    RufletWidgetStateProperty.resolve(node.props["thumb_icon"], in: states)
  }
  var thumbIconColor: Color? {
    MaterialPalette.color(
      RufletWidgetStateProperty.resolve(node.props["thumb_color"], in: states)?.stringValue)
      ?? thumbColor
  }

  var trackOutlineColorToken: String? {
    RufletWidgetStateProperty.resolve(node.props["track_outline_color"], in: states)?.stringValue
  }
  var trackOutlineColor: Color? { MaterialPalette.color(trackOutlineColorToken) }
  var trackOutlineWidth: CGFloat? {
    ControlProps.statefulDouble(node.props["track_outline_width"], in: states)
  }

  var focusColorToken: String? {
    // Current Flet Python writes snake_case. Accept the historical renderer's
    // camelCase spelling too so old recorded patches remain consumable.
    node.string("focus_color") ?? node.string("focusColor")
  }
  var focusColor: Color? { MaterialPalette.color(focusColorToken) }

  var onLabelColorToken: String? { node.string("on_label_color") }
  var offLabelColorToken: String? { node.string("off_label_color") }
  var activeLabelColor: Color? {
    MaterialPalette.color(value ? onLabelColorToken : offLabelColorToken)
  }

  var thumbImageValue: RufletValue? {
    if value {
      return node.props["active_thumb_image_src"] ?? node.props["active_thumb_image"]
    }
    return node.props["inactive_thumb_image_src"] ?? node.props["inactive_thumb_image"]
  }
  var thumbImageSource: RufletImageSource { RufletImageSource(value: thumbImageValue) }

  var hasThumbDecoration: Bool {
    thumbIcon != nil || !thumbImageSource.isMissing
      || node.props["thumb_color"] != nil || node.props["inactive_thumb_color"] != nil
  }
}

extension RufletImageSource {
  fileprivate var isMissing: Bool {
    if case .missing = self { return true }
    return false
  }
}

private struct CupertinoSwitchThumbImage: View {
  let source: RufletImageSource
  let serverURL: URL?
  let onError: (String) -> Void
  @State private var data: Data?
  @State private var failed = false

  var body: some View {
    Group {
      if let data {
        PlatformImageView(data: data)
      } else {
        Color.clear
      }
    }
    .task(id: source) { await load() }
  }

  @MainActor
  private func load() async {
    data = nil
    failed = false
    do {
      let loaded = try await resolve()
      guard Self.canDecode(loaded) else { throw CupertinoSwitchImageError.invalidImage }
      data = loaded
    } catch is CancellationError {
      return
    } catch {
      guard !failed else { return }
      failed = true
      onError(error.localizedDescription)
    }
  }

  private func resolve() async throws -> Data {
    switch source {
    case .binary(let data): return data
    case .remote(let url) where url.isFileURL:
      return try Data(contentsOf: url)
    case .remote(let url):
      let (data, response) = try await URLSession.shared.data(from: url)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw CupertinoSwitchImageError.httpStatus(http.statusCode)
      }
      return data
    case .asset(let name):
      if let data = RufletImageSource.packagedData(named: name) { return data }
      if let url = RufletImageAssetURL.imageAsset(name, relativeTo: serverURL) {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
          throw CupertinoSwitchImageError.httpStatus(http.statusCode)
        }
        return data
      }
      throw CupertinoSwitchImageError.missingAsset(name)
    case .empty: throw CupertinoSwitchImageError.emptySource
    case .invalid(let description): throw CupertinoSwitchImageError.invalidSource(description)
    case .missing: throw CupertinoSwitchImageError.emptySource
    }
  }

  private static func canDecode(_ data: Data) -> Bool {
    if RufletSVGDocument.isSVG(data) { return true }
    #if canImport(UIKit)
      return UIImage(data: data) != nil
    #elseif canImport(AppKit)
      return NSImage(data: data) != nil
    #else
      return false
    #endif
  }
}

private enum CupertinoSwitchImageError: LocalizedError {
  case httpStatus(Int)
  case invalidImage
  case missingAsset(String)
  case emptySource
  case invalidSource(String)

  var errorDescription: String? {
    switch self {
    case .httpStatus(let status): return "Image request failed with HTTP status \(status)."
    case .invalidImage: return "Image data could not be decoded."
    case .missingAsset(let name): return "Image asset \(name) could not be resolved."
    case .emptySource: return "Image source is empty."
    case .invalidSource(let description): return description
    }
  }
}

/// `track_outline_color` and `track_outline_width` stroke the track, which
/// Cupertino draws around an off switch.
private struct SwitchTrackOutline: ViewModifier {
  let presentation: CupertinoSwitchPresentation

  func body(content: Content) -> some View {
    content.overlay(
      Capsule().strokeBorder(
        presentation.trackOutlineColor
          ?? (presentation.focused ? presentation.focusColor : nil)
          ?? .clear,
        lineWidth: presentation.trackOutlineWidth
          ?? (presentation.focused && presentation.focusColor != nil ? 2 : 0)))
  }
}

/// `CupertinoSlider` — the platform slider.
struct CupertinoSliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var currentValue: Double?

  var body: some View {
    let presentation = CupertinoSliderPresentation(node: node)
    Group {
      if let step = presentation.step {
        Slider(
          value: valueBinding(presentation), in: presentation.range, step: step,
          onEditingChanged: editingChanged(presentation))
      } else {
        // Flet passes `divisions: null` to CupertinoSlider for a genuinely
        // continuous control. Supplying an artificial epsilon step changes
        // native value quantisation and can overflow SwiftUI's step count.
        Slider(
          value: valueBinding(presentation), in: presentation.range,
          onEditingChanged: editingChanged(presentation))
      }
    }
    .modifier(OptionalSliderTint(color: presentation.activeColor))
    .disabled(node.bool("disabled") ?? false)
    .onAppear { currentValue = presentation.value }
    .onChange(of: node.double("value")) { _ in
      currentValue = CupertinoSliderPresentation(node: node).value
    }
  }

  private func valueBinding(_ presentation: CupertinoSliderPresentation) -> Binding<Double> {
    Binding(
      get: { currentValue ?? presentation.value },
      set: {
        currentValue = $0
        // Pinned Flet first updates the public value property and then emits
        // a data-less `change` event.
        RufletValueControlEvents.commit(
          node, value: .double($0), payload: .none, to: events)
      })
  }

  private func editingChanged(
    _ presentation: CupertinoSliderPresentation
  ) -> (Bool) -> Void {
    { editing in
      events.fire(
        node, editing ? "change_start" : "change_end",
        data: .double(currentValue ?? presentation.value))
    }
  }
}

/// Exact wire/default interpretation for Flet's CupertinoSlider.
struct CupertinoSliderPresentation {
  let node: ControlNode

  var minimum: Double { node.double("min") ?? 0 }
  var maximum: Double { max(node.double("max") ?? 1, minimum + .ulpOfOne) }
  var range: ClosedRange<Double> { minimum...maximum }
  var value: Double { min(max(node.double("value") ?? minimum, minimum), maximum) }
  var divisions: Int? { node.int("divisions") }
  var step: Double? {
    guard let divisions, divisions > 0 else { return nil }
    return (maximum - minimum) / Double(divisions)
  }
  var activeColor: Color? { MaterialPalette.color(node.string("active_color")) }
  /// Flutter's CupertinoSlider defaults the thumb to Cupertino white.
  var thumbColorName: String { node.string("thumb_color") ?? "white" }
}

private struct OptionalSliderTint: ViewModifier {
  let color: Color?

  func body(content: Content) -> some View {
    guard let color else { return AnyView(content) }
    return AnyView(content.tint(color))
  }
}

/// `CupertinoCheckbox` and `CupertinoRadio` share a registry entry, but their
/// Flet implementations do not share selection state: the checkbox owns its
/// nullable Bool while the radio inherits the nearest RadioGroup value.
struct CupertinoSelectionControlView: View {
  enum Kind { case checkbox, radio }

  let node: ControlNode
  let kind: Kind

  @ViewBuilder
  var body: some View {
    switch kind {
    case .checkbox: CupertinoCheckboxSelectionView(node: node)
    case .radio: CupertinoRadioSelectionView(node: node)
    }
  }
}

private struct CupertinoCheckboxSelectionView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletListTileClicks) private var listTileClicks

  var body: some View {
    HStack(spacing: CGFloat(node.double("spacing") ?? 10)) {
      if labelPosition == .left { label }
      mark
      if labelPosition == .right { label }
    }
    .contentShape(Rectangle())
    .onTapGesture { if node.bool("disabled") != true { advance() } }
    .modifier(SelectionScaling(node: node, natural: 20))
    .modifier(ListTileToggleListener(notifier: listTileClicks, action: advance))
    .modifier(FocusReporter(node: node, events: events))
    .modifier(SelectionAccessibilityLabel(label: RufletAccessibilitySemantics.label(node)))
    .disabled(node.bool("disabled") ?? false)
  }

  private enum LabelPlacement { case left, right }
  private var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  @ViewBuilder
  private var label: some View {
    if let labelID = node.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else if let text = node.string("label") {
      Text(text).rufletTextStyle(RufletTextStyle(map: node.map("label_style") ?? [:]))
    }
  }

  private var state: Bool? { RufletCheckboxState.resting(node) }
  private var states: Set<RufletWidgetState> { node.widgetStates(selected: state == true) }

  private var mark: some View {
    let side = ControlProps.statefulBorderSide(node.props["border_side"], in: states)
    let radius = ControlProps.cornerRadius(node.map("shape")?["radius"]) ?? 5
    return ZStack {
      RoundedRectangle(cornerRadius: radius)
        .fill(state == false ? .clear : fillColor)
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(
          state == false ? (side?.color ?? .secondary) : .clear,
          lineWidth: side?.width ?? 1.5)
      if state != false {
        Image(systemName: state == true ? "checkmark" : "minus")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(MaterialPalette.color(node.string("check_color"), default: .white))
      }
    }
    .frame(width: 20, height: 20)
  }

  private var fillColor: Color {
    MaterialPalette.color(stateful: node.props["fill_color"], in: states)
      ?? MaterialPalette.color(node.string("active_color"), default: .accentColor)
  }

  private func advance() {
    RufletValueControlEvents.commit(
      node,
      value: RufletCheckboxState.next(
        after: state, tristate: node.bool("tristate") == true),
      payload: .value,
      to: events)
  }
}

private struct CupertinoRadioSelectionView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    if group == nil {
      Text("CupertinoRadio must be enclosed within RadioGroup")
        .foregroundColor(.red)
    } else {
      HStack(spacing: 0) {
        if labelPosition == .left { label }
        mark
          .contentShape(Rectangle())
          .onTapGesture {
            if node.bool("disabled") != true { select(toggleIfSelected: true) }
          }
        if labelPosition == .right { label }
      }
      .modifier(FocusReporter(node: node, events: events))
      .disabled(node.bool("disabled") ?? false)
    }
  }

  private enum LabelPlacement { case left, right }
  private var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  @ViewBuilder
  private var label: some View {
    if let text = node.string("label"), !text.isEmpty {
      Text(text)
        .foregroundColor(node.bool("disabled") == true ? .secondary : nil)
        .contentShape(Rectangle())
        .onTapGesture {
          if node.bool("disabled") != true { select(toggleIfSelected: false) }
        }
    }
  }

  private var group: ControlNode? {
    RufletRadioGroupResolver.nearestGroup(containing: node.id, in: store.nodes)
  }
  private var value: String { node.string("value") ?? "" }
  private var selected: Bool { group?.string("value") == value }

  private var mark: some View {
    let active = MaterialPalette.color(
      node.string("active_color") ?? node.string("fill_color"), default: .accentColor)
    let inactive = MaterialPalette.color(node.string("inactive_color"), default: .secondary)
    return ZStack {
      if node.bool("use_checkmark_style") == true {
        Image(systemName: selected ? "checkmark" : "")
          .font(.system(size: 14, weight: .semibold))
      } else {
        Circle().strokeBorder(selected ? active : inactive, lineWidth: 1.5)
        if selected { Circle().fill(active).frame(width: 10, height: 10) }
      }
    }
    .foregroundColor(selected ? active : inactive)
    .frame(width: 20, height: 20)
  }

  private func select(toggleIfSelected: Bool) {
    guard let group, group.bool("disabled") != true else { return }
    let next: RufletValue = toggleIfSelected && selected && node.bool("toggleable") == true
      ? .null
      : .string(value)
    RufletValueControlEvents.commit(group, value: next, payload: .value, to: events)
  }
}

/// `CupertinoTextField` — a rounded iOS field.
struct CupertinoTextFieldControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var revealed = false
  @State private var observedValue = ""

  private var presentation: RufletCupertinoTextFieldPresentation {
    RufletCupertinoTextFieldPresentation(
      node: node, focused: focused, revealedPassword: revealed)
  }

  var body: some View {
    HStack(alignment: presentation.verticalAlignment, spacing: 0) {
      if presentation.showsPrefix {
        RufletFormFieldSlot(node: node, key: "prefix")
      }
      field
      suffixAttachment
    }
    .textFieldStyle(.plain)
    .padding(presentation.padding)
    .frame(width: presentation.defaultWidth)
    .frame(
      maxWidth: presentation.fitsParent ? .infinity : nil,
      maxHeight: presentation.fitsParent ? .infinity : nil)
    .background(fieldDecoration)
    .overlay(borderStroke)
    .modifier(ChromeClipModifier(behavior: presentation.clipBehavior))
    .modifier(CupertinoFieldShadows(value: node.props["shadows"]))
    .environment(\.layoutDirection, node.bool("rtl") == true ? .rightToLeft : .leftToRight)
    .disabled(node.bool("disabled") == true)
    .onAppear {
      observedValue = presentation.value
      focused = node.string("blur") == nil
        && (presentation.autofocus || node.string("focus") != nil)
      selection = presentation.initialSelection
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .onChange(of: selection) {
      RufletCupertinoTextFieldEvents.selection($0, on: node, to: events)
    }
    .onChange(of: node.string("value")) { value in
      let value = value ?? ""
      guard observedValue != value else { return }
      observedValue = value
      selection = node.map("selection") == nil
        ? NSRange(location: value.utf16.count, length: 0)
        : RufletTextSelection.explicit(on: node)
    }
    .onChange(of: node.string("focus")) { if $0 != nil { focused = true } }
    .onChange(of: node.string("blur")) { if $0 != nil { focused = false } }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus": focused = true; completion(.success(.null))
      default: completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
  }

  @ViewBuilder
  private var field: some View {
    // An adaptive TextField arrives here carrying Material's names, so Flet
    // falls back to the label when there is no placeholder.
    let placeholder = presentation.placeholder
    if presentation.isMultiline {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeMultilineTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          traits: presentation.traits,
          submitOnReturn: presentation.shiftEnter,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit") })
          .frame(
            minHeight: presentation.minimumHeight,
            maxHeight: presentation.maximumHeight)
          .modifier(
            CupertinoPlaceholder(
              node: node, text: placeholder,
              showing: binding.wrappedValue.isEmpty, multiline: true))
      #else
        TextEditor(text: binding)
          .rufletTextStyle(presentation.textStyle)
          .lineLimit(presentation.maxLines)
          .frame(
            minHeight: presentation.minimumHeight,
            maxHeight: presentation.maximumHeight)
          .modifier(
            CupertinoPlaceholder(
              node: node, text: placeholder,
              showing: binding.wrappedValue.isEmpty, multiline: true))
      #endif
    } else {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          placeholder: presentation.drawsCustomPlaceholder ? "" : placeholder,
          secure: presentation.obscuresText,
          traits: presentation.traits,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(
            CupertinoPlaceholder(
              node: node, text: placeholder,
              showing: binding.wrappedValue.isEmpty, multiline: false))
      #else
        TextField(placeholder, text: binding)
          .onSubmit { events.fire(node, "submit", data: .string(binding.wrappedValue)) }
      #endif
    }
  }

  /// Cupertino paints the field's box the way a Container does, so a gradient
  /// or an image stands in for the fill when Ruby supplies one.
  @ViewBuilder
  private var fieldDecoration: some View {
    GeometryReader { geometry in
      let shape = RufletRoundedRectangle(radii: presentation.cornerRadii)
      ZStack {
        shape.fill(presentation.backgroundColor)
        if let gradient = RufletGradientSpec(node.props["gradient"]) {
          shape.fill(gradient.shapeStyle(size: geometry.size))
        }
        if let image = RufletDecorationImageSpec(node.props["image"]) {
          CupertinoTextFieldDecorationImage(spec: image)
            .blendMode(ControlProps.blendMode(node.string("blend_mode")))
            .clipShape(shape)
        }
      }
    }
  }

  @ViewBuilder
  private var suffixAttachment: some View {
    switch presentation.suffixAttachment {
    case .suffix:
      if presentation.hasRevealSuffix {
        revealButton
      } else {
        RufletFormFieldSlot(node: node, key: "suffix")
      }
    case .clear:
      clearButton
    case .none:
      EmptyView()
    }
  }

  private var clearButton: some View {
    Button {
      observedValue = ""
      RufletCupertinoTextFieldEvents.change("", on: node, to: events)
    } label: {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: RufletCupertinoTextFieldDefaults.clearButtonSize))
        .foregroundColor(.secondary.opacity(0.45))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, RufletCupertinoTextFieldDefaults.clearButtonHorizontalPadding)
    .accessibilityLabel(presentation.clearButtonSemanticsLabel)
  }

  private var revealButton: some View {
    Button {
      revealed.toggle()
    } label: {
      Image(systemName: revealed ? "eye.slash" : "eye").foregroundColor(.secondary)
    }
    .buttonStyle(.plain)
    .padding(.trailing, RufletCupertinoTextFieldDefaults.revealTrailingPadding)
  }

  private var binding: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: {
        observedValue = $0
        RufletCupertinoTextFieldEvents.change($0, on: node, to: events)
      })
  }

  @ViewBuilder
  private var borderStroke: some View {
    if let border = presentation.border {
      CupertinoTextFieldBorderLayer(border: border, radii: presentation.cornerRadii)
    }
  }
}

enum RufletCupertinoOverlayVisibility: Equatable {
  case never, editing, notEditing, always

  init(_ value: String?, default fallback: Self) {
    switch value?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "never": self = .never
    case "editing": self = .editing
    case "notediting": self = .notEditing
    case "always": self = .always
    default: self = fallback
    }
  }

  func shows(hasText: Bool) -> Bool {
    switch self {
    case .never: return false
    case .editing: return hasText
    case .notEditing: return !hasText
    case .always: return true
    }
  }
}

enum RufletCupertinoTextFieldSuffixAttachment: Equatable {
  case none, suffix, clear
}

/// Values resolved by Flet 0.80.5 before constructing CupertinoTextField.
/// Keeping these independent of SwiftUI makes omission and attachment
/// precedence testable without relying on platform screenshots.
struct RufletCupertinoTextFieldPresentation {
  let node: ControlNode
  let focused: Bool
  let revealedPassword: Bool

  var value: String { node.string("value") ?? "" }
  var autofocus: Bool { node.bool("autofocus") ?? false }
  var shiftEnter: Bool { node.bool("shift_enter") ?? false }
  var isMultiline: Bool { node.bool("multiline") == true || shiftEnter }
  var minLines: Int { node.int("min_lines") ?? 1 }
  var maxLines: Int? { node.int("max_lines") ?? (isMultiline ? nil : 1) }
  var fitsParent: Bool { node.bool("fit_parent_size") ?? false }
  var clipBehavior: String { node.string("clip_behavior") ?? "hardEdge" }
  var obscuresText: Bool { node.bool("password") == true && !revealedPassword }
  var hasRevealSuffix: Bool {
    node.bool("password") == true && node.bool("can_reveal_password") == true
  }

  var placeholder: String {
    node.string("placeholder_text") ?? node.string("label") ?? ""
  }
  var drawsCustomPlaceholder: Bool {
    node.map("placeholder_style") != nil || node.map("label_style") != nil
  }
  var clearButtonSemanticsLabel: String {
    node.string("clear_button_semantics_label") ?? "Clear"
  }

  var padding: EdgeInsets {
    ControlProps.edgeInsets(node.props["padding"])
      ?? EdgeInsets(
        top: RufletCupertinoTextFieldDefaults.padding,
        leading: RufletCupertinoTextFieldDefaults.padding,
        bottom: RufletCupertinoTextFieldDefaults.padding,
        trailing: RufletCupertinoTextFieldDefaults.padding)
  }

  var scrollPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["scroll_padding"])
      ?? EdgeInsets(
        top: RufletCupertinoTextFieldDefaults.scrollPadding,
        leading: RufletCupertinoTextFieldDefaults.scrollPadding,
        bottom: RufletCupertinoTextFieldDefaults.scrollPadding,
        trailing: RufletCupertinoTextFieldDefaults.scrollPadding)
  }

  var defaultWidth: CGFloat? {
    guard node.double("width") == nil else { return nil }
    guard !Self.hasExpand(node) else { return nil }
    return RufletCupertinoTextFieldDefaults.defaultWidth
  }

  var textStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "text_style")
    if let size = node.double("text_size") { style.size = CGFloat(size) }
    let resting = MaterialPalette.color(node.string("color"))
    let active = MaterialPalette.color(node.string("focused_color"))
    if let color = focused ? (active ?? resting) : resting { style.color = color }
    return style
  }

  var traits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    if isMultiline { traits.keyboardType = "multiline" }
    if node.bool("rtl") == true {
      switch traits.textAlign {
      case nil, "start": traits.textAlign = "right"
      case "end": traits.textAlign = "left"
      default: break
      }
    }
    traits.textColor = textStyle.color
    traits.fontSize = textStyle.size
    traits.caretScrollPadding = scrollPadding
    traits.cursorRadius = ControlProps.cornerRadius(node.props["cursor_radius"])
      ?? RufletCupertinoTextFieldDefaults.cursorRadius
    return traits
  }

  var lineHeight: CGFloat { traits.lineHeight ?? RufletCupertinoTextFieldDefaults.lineHeight }
  var minimumHeight: CGFloat? {
    fitsParent ? nil : CGFloat(minLines) * lineHeight
  }
  var maximumHeight: CGFloat? {
    guard !fitsParent, let maxLines else { return nil }
    return CGFloat(maxLines) * lineHeight
  }

  var initialSelection: NSRange {
    guard node.map("selection") != nil else {
      return NSRange(location: value.utf16.count, length: 0)
    }
    return RufletTextSelection.explicit(on: node)
  }

  var prefixMode: RufletCupertinoOverlayVisibility {
    RufletCupertinoOverlayVisibility(
      node.string("prefix_visibility_mode"), default: .always)
  }
  var suffixMode: RufletCupertinoOverlayVisibility {
    RufletCupertinoOverlayVisibility(
      node.string("suffix_visibility_mode"), default: .always)
  }
  var clearMode: RufletCupertinoOverlayVisibility {
    RufletCupertinoOverlayVisibility(
      node.string("clear_button_visibility_mode"), default: .never)
  }
  var showsPrefix: Bool {
    node.props["prefix"] != nil && prefixMode.shows(hasText: !value.isEmpty)
  }
  var suffixAttachment: RufletCupertinoTextFieldSuffixAttachment {
    let hasSuffix = hasRevealSuffix || node.props["suffix"] != nil
    if hasSuffix, suffixMode.shows(hasText: !value.isEmpty) { return .suffix }
    if clearMode.shows(hasText: !value.isEmpty) { return .clear }
    return .none
  }

  var verticalAlignment: VerticalAlignment {
    switch node.double("text_vertical_align") {
    case .some(let value) where value <= -0.5: return .top
    case .some(let value) where value >= 0.5: return .bottom
    default: return .center
    }
  }

  var cornerRadii: RufletCornerRadii {
    if node.string("border")?.lowercased() == "underline" {
      return RufletCornerRadii(uniform: 0)
    }
    return ControlProps.cornerRadii(node.props["border_radius"])
      ?? RufletCornerRadii(uniform: RufletCupertinoTextFieldDefaults.cornerRadius)
  }

  var border: RufletBorder? {
    if let explicit = ControlProps.borderSides(node.props["border"]) { return explicit }
    let side = RufletBorderSide(
      color: MaterialPalette.color(node.string("border_color"), default: .black),
      width: CGFloat(node.double("border_width") ?? 1))
    switch node.string("border")?.lowercased() ?? "outline" {
    case "none": return nil
    case "underline": return RufletBorder(top: nil, right: nil, bottom: side, left: nil)
    default: return RufletBorder(top: side, right: side, bottom: side, left: side)
    }
  }

  var backgroundColor: Color {
    MaterialPalette.color(node.string("bgcolor"))
      ?? RufletCupertinoTextFieldDefaults.backgroundColor
  }

  private static func hasExpand(_ node: ControlNode) -> Bool {
    guard let expand = node.props["expand"] else { return false }
    return expand.boolValue == true || (expand.intValue ?? 0) > 0
  }
}

enum RufletCupertinoTextFieldDefaults {
  static let padding: CGFloat = 7
  static let scrollPadding: CGFloat = 20
  static let defaultWidth: CGFloat = 300
  static let cornerRadius: CGFloat = 5
  static let cursorRadius: CGFloat = 2
  static let lineHeight: CGFloat = 20
  static let clearButtonSize: CGFloat = 18
  static let clearButtonHorizontalPadding: CGFloat = 6
  static let revealTrailingPadding: CGFloat = 15

  static var backgroundColor: Color {
    #if canImport(UIKit)
      return Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
      return Color(nsColor: .textBackgroundColor)
    #else
      return .white
    #endif
  }
}

enum RufletCupertinoTextFieldEvents {
  static func change(_ value: String, on node: ControlNode, to events: RufletEventSink) {
    let wire = RufletValue.string(value)
    events.setLocal(node.id, "value", wire)
    events.update(node.id, ["value": wire])
    if node.bool("on_change") == true || node.handlesEvent("change") {
      events.fire(node, "change", data: wire)
    }
  }

  static func selection(_ range: NSRange, on node: ControlNode, to events: RufletEventSink) {
    guard node.bool("on_selection_change") == true || node.handlesEvent("selection_change") else {
      return
    }
    RufletTextSelection.report(range, on: node, to: events)
  }
}

private struct CupertinoTextFieldBorderLayer: View {
  let border: RufletBorder
  let radii: RufletCornerRadii

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let top = border.top {
          top.color.frame(width: geometry.size.width, height: top.width)
            .position(x: geometry.size.width / 2, y: top.width / 2)
        }
        if let right = border.right {
          right.color.frame(width: right.width, height: geometry.size.height)
            .position(x: geometry.size.width - right.width / 2, y: geometry.size.height / 2)
        }
        if let bottom = border.bottom {
          bottom.color.frame(width: geometry.size.width, height: bottom.width)
            .position(x: geometry.size.width / 2, y: geometry.size.height - bottom.width / 2)
        }
        if let left = border.left {
          left.color.frame(width: left.width, height: geometry.size.height)
            .position(x: left.width / 2, y: geometry.size.height / 2)
        }
      }
      .clipShape(RufletRoundedRectangle(radii: radii))
    }
    .allowsHitTesting(false)
  }
}

private struct CupertinoTextFieldDecorationImage: View {
  let spec: RufletDecorationImageSpec

  @ViewBuilder
  var body: some View {
    switch spec.source {
    case .binary(let data):
      PlatformImageView(data: data, repeatMode: spec.repeatMode, interpolation: spec.interpolation)
        .opacity(spec.opacity)
    case .remote(let url):
      AsyncImage(url: url) { image in
        image.resizable(resizingMode: spec.repeatMode.swiftUI).interpolation(spec.interpolation)
      } placeholder: { Color.clear }
      .opacity(spec.opacity)
    case .asset(let name):
      Image(name).resizable(resizingMode: spec.repeatMode.swiftUI)
        .interpolation(spec.interpolation).opacity(spec.opacity)
    case .empty, .invalid, .missing:
      Color.clear
    }
  }
}

/// Cupertino's `placeholder_style` and the hint's line limit and fade, which
/// neither platform field styles directly, so the text is drawn over an empty
/// field.
private struct CupertinoPlaceholder: ViewModifier {
  let node: ControlNode
  let text: String
  let showing: Bool
  let multiline: Bool

  func body(content: Content) -> some View {
    guard node.map("placeholder_style") != nil || node.map("label_style") != nil
    else { return AnyView(content) }
    let styleKey = node.map("placeholder_style") != nil ? "placeholder_style" : "label_style"
    return AnyView(
      content.overlay(alignment: multiline ? .topLeading : .leading) {
        Text(text)
          .lineLimit(multiline ? nil : 1)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: styleKey))
          .opacity(showing ? 1 : 0)
          .allowsHitTesting(false)
      })
  }
}

/// `shadows` is Flutter's BoxShadow list; SwiftUI takes them one at a time.
private struct CupertinoFieldShadows: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    var result = AnyView(content)
    for shadow in value?.arrayValue ?? [] {
      guard let map = shadow.mapValue else { continue }
      result = AnyView(
        result.shadow(
          color: MaterialPalette.color(map["color"]?.stringValue, default: .black.opacity(0.2)),
          radius: CGFloat(map["blur_radius"]?.doubleValue ?? 0),
          x: CGFloat(map["offset"]?.mapValue?["x"]?.doubleValue ?? 0),
          y: CGFloat(map["offset"]?.mapValue?["y"]?.doubleValue ?? 0)))
    }
    return result
  }
}

/// `CupertinoSegmentedButton` / `CupertinoSlidingSegmentedButton` — a native
/// segmented picker.
struct CupertinoSegmentedControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  private var configuration: RufletCupertinoSegmentedConfiguration {
    RufletCupertinoSegmentedConfiguration(node: node)
  }

  private var visibleControls: [ControlNode] {
    node.childIDs.compactMap { store.node($0) }.filter { $0.bool("visible") != false }
  }

  @ViewBuilder
  var body: some View {
    if let message = configuration.validationMessage(visibleCount: visibleControls.count) {
      Text(message).foregroundColor(.red)
    } else {
      switch configuration.kind {
      case .regular: regularControl
      case .sliding: slidingControl
      }
    }
  }

  private var nativePicker: some View {
    Picker(
      "",
      selection: Binding(
        // A regular CupertinoSegmentedControl accepts a nullable groupValue;
        // -1 is only the native Picker's no-selection tag and never goes on
        // the wire. The sliding variant has Flet's explicit zero default.
        get: { configuration.selectedIndex ?? -1 },
        set: { commitSelection($0) })
    ) {
      ForEach(Array(visibleControls.enumerated()), id: \.element.id) { index, control in
        ControlView(id: control.id, axis: .none)
          // CupertinoSegmentedControl pads every segment's content. The
          // sliding constructor instead pads between the native control and
          // its moving segment, so its content remains untouched here.
          .modifier(OptionalEdgeInsets(
            insets: configuration.kind == .regular ? configuration.padding : nil))
          .tag(index)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .disabled(node.bool("disabled") ?? false)
  }

  private var regularControl: some View {
    nativePicker
      // SwiftUI's segmented Picker remains the native Apple primitive. These
      // modifiers apply only explicit Flet overrides; omitted Cupertino
      // dynamic colours remain owned by the platform control.
      .tint(MaterialPalette.color(node.string("selected_color")))
      .background(regularBackground)
      .foregroundColor(regularForeground)
      .modifier(
        SegmentedPressTint(color: MaterialPalette.color(node.string("click_color"))))
      .modifier(
        CupertinoSegmentedBorder(color: MaterialPalette.color(node.string("border_color"))))
  }

  private var slidingControl: some View {
    nativePicker
      // CupertinoSlidingSegmentedControl names the selected surface
      // `thumb_color`, not `selected_color`.
      .tint(MaterialPalette.color(node.string("thumb_color")))
      .fixedSize(horizontal: configuration.proportionalWidth, vertical: false)
      // Applying the surface after padding makes this an inset between the
      // segment and its control, matching CupertinoSlidingSegmentedControl.
      .modifier(OptionalEdgeInsets(insets: configuration.padding))
      .background(MaterialPalette.color(node.string("bgcolor")))
  }

  private var regularBackground: Color? {
    if node.bool("disabled") == true {
      return MaterialPalette.color(node.string("disabled_color"))
        ?? MaterialPalette.color(node.string("unselected_color"))
    }
    return MaterialPalette.color(node.string("unselected_color"))
  }

  private var regularForeground: Color? {
    guard node.bool("disabled") == true else { return nil }
    return MaterialPalette.color(node.string("disabled_text_color"))
  }

  private func commitSelection(_ index: Int) {
    // Both pinned implementations send update_control before `change`, and
    // carry the selected integer as event data. This still updates Ruby when
    // no change handler is attached.
    RufletValueControlEvents.commit(
      node,
      key: "selected_index",
      value: .int(Int64(index)),
      payload: .value,
      to: events)
  }
}

/// The two similarly named controls use different Flutter constructors and
/// therefore different property namespaces. Keeping that distinction in one
/// source-derived model prevents a renderer refactor from conflating them.
struct RufletCupertinoSegmentedConfiguration {
  enum Kind: Equatable {
    case regular
    case sliding
  }

  let kind: Kind
  let selectedIndex: Int?
  let proportionalWidth: Bool
  let padding: EdgeInsets?

  init(node: ControlNode) {
    if node.type == "CupertinoSlidingSegmentedButton" {
      kind = .sliding
      selectedIndex = node.int("selected_index") ?? 0
      proportionalWidth = node.bool("proportional_width") ?? false
      padding = ControlProps.edgeInsets(node.props["padding"])
        ?? EdgeInsets(top: 2, leading: 3, bottom: 2, trailing: 3)
    } else {
      kind = .regular
      // CupertinoSegmentedControl.groupValue is nullable in the pinned Flet
      // constructor, so omission means no selected segment.
      selectedIndex = node.int("selected_index")
      proportionalWidth = false
      padding = ControlProps.edgeInsets(node.props["padding"])
    }
  }

  func validationMessage(visibleCount: Int) -> String? {
    guard visibleCount < 2 else { return nil }
    switch kind {
    case .regular:
      return "CupertinoSegmentedButton must have at minimum two visible controls"
    case .sliding:
      return "CupertinoSlidingSegmentedButton must have at minimum two visible controls"
    }
  }
}

private struct CupertinoSegmentedBorder: ViewModifier {
  let color: Color?

  func body(content: Content) -> some View {
    if let color {
      content.overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 1))
    } else {
      content
    }
  }
}

/// `click_color` is the wash Cupertino paints while a segment is held.
private struct SegmentedPressTint: ViewModifier {
  let color: Color?
  @State private var pressed = false

  func body(content: Content) -> some View {
    guard let color else { return AnyView(content) }
    return AnyView(
      content
        .background(pressed ? color : .clear)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }))
  }
}

/// `CupertinoPicker` — the scrolling wheel.
struct CupertinoPickerControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var wheelIndex: Int

  init(node: ControlNode) {
    self.node = node
    _wheelIndex = State(
      initialValue: CupertinoPickerParity.initialIndex(
        selected: node.int("selected_index") ?? 0,
        count: node.childIDs.count,
        looping: node.bool("looping") ?? false))
  }

  private var configuration: RufletCupertinoPickerConfiguration {
    RufletCupertinoPickerConfiguration(node: node)
  }

  var body: some View {
    Picker(
      "",
      selection: Binding(
        get: { wheelIndex },
        set: { newIndex in
          wheelIndex = newIndex
          let real = CupertinoPickerParity.realIndex(newIndex, count: node.childIDs.count)
          events.commit(node, key: "selected_index", value: .int(Int64(real)))
          guard configuration.looping,
            CupertinoPickerParity.shouldRecenter(newIndex, count: node.childIDs.count)
          else { return }
          // Keep the wheel far from either finite edge. The jump is invisible
          // because every repeated row has identical content.
          DispatchQueue.main.async {
            wheelIndex = CupertinoPickerParity.initialIndex(
              selected: real, count: node.childIDs.count, looping: true)
          }
        })
    ) {
      ForEach(0..<CupertinoPickerParity.itemCount(count: node.childIDs.count, looping: configuration.looping), id: \.self) { index in
        if !node.childIDs.isEmpty {
          ControlView(
            id: node.childIDs[CupertinoPickerParity.realIndex(index, count: node.childIDs.count)],
            axis: .none
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          .tag(index)
        }
      }
    }
    .modifier(WheelPickerStyle())
    .labelsHidden()
    .frame(height: CGFloat(configuration.itemExtent) * 5)
    // Flutter's wheel geometry: the squeeze packs the rows, the diameter
    // ratio curves the drum, and the off-axis fraction tilts it.
    .scaleEffect(
      x: 1, y: CGFloat(configuration.squeeze), anchor: .center)
    .rotation3DEffect(
      .degrees(configuration.offAxisFraction * 45),
      axis: (x: 0, y: 1, z: 0),
      perspective: 1 / max(configuration.diameterRatio, 0.1))
    .background(selectionOverlay)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .modifier(
      PickerMagnifier(
        enabled: configuration.useMagnifier,
        factor: configuration.magnification))
    .onChange(of: node.int("selected_index") ?? 0) { selected in
      let real = CupertinoPickerParity.realIndex(wheelIndex, count: node.childIDs.count)
      guard selected != real else { return }
      wheelIndex = CupertinoPickerParity.initialIndex(
        selected: selected, count: node.childIDs.count,
        looping: configuration.looping)
    }
  }

  /// `selection_overlay` is the band drawn behind the selected row; Flet lets
  /// it be a control, and names the default band's colour separately.
  @ViewBuilder
  private var selectionOverlay: some View {
    if let overlayID = node.controlID(forKey: "selection_overlay") {
      ControlView(id: overlayID, axis: .none)
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(
          MaterialPalette.color(
            node.string("default_selection_overlay_bgcolor"),
            default: .gray.opacity(0.2)))
        .frame(height: CGFloat(configuration.itemExtent))
    }
  }
}

struct RufletCupertinoPickerConfiguration {
  let diameterRatio: Double
  let magnification: Double
  let squeeze: Double
  let offAxisFraction: Double
  let itemExtent: Double
  let useMagnifier: Bool
  let looping: Bool

  init(node: ControlNode) {
    diameterRatio = node.double("diameter_ratio") ?? 1.07
    magnification = node.double("magnification") ?? 1
    squeeze = node.double("squeeze") ?? 1.45
    offAxisFraction = node.double("off_axis_fraction") ?? 0
    itemExtent = node.double("item_extent") ?? 32
    useMagnifier = node.bool("use_magnifier") ?? false
    looping = node.bool("looping") ?? false
  }
}

/// Flutter's `looping` wheel uses a looping child delegate. SwiftUI exposes
/// no equivalent, so the native host presents many identical cycles and keeps
/// the selection in the middle cycle. These helpers are deliberately pure so
/// the index contract is independently testable.
enum CupertinoPickerParity {
  static let cycles = 101

  static func realIndex(_ index: Int, count: Int) -> Int {
    guard count > 0 else { return 0 }
    return ((index % count) + count) % count
  }

  static func itemCount(count: Int, looping: Bool) -> Int {
    guard count > 0 else { return 0 }
    return looping ? count * cycles : count
  }

  static func initialIndex(selected: Int, count: Int, looping: Bool) -> Int {
    guard count > 0 else { return 0 }
    let real = realIndex(selected, count: count)
    return looping ? (cycles / 2) * count + real : real
  }

  static func shouldRecenter(_ index: Int, count: Int) -> Bool {
    guard count > 0 else { return false }
    return index < count * 2 || index >= count * (cycles - 2)
  }
}

/// `use_magnifier` scales the row under the selection band.
private struct PickerMagnifier: ViewModifier {
  let enabled: Bool
  let factor: Double

  func body(content: Content) -> some View {
    if enabled {
      content.scaleEffect(CGFloat(factor))
    } else {
      content
    }
  }
}

/// `CupertinoDatePicker` and `CupertinoTimerPicker`.
struct CupertinoDatePickerControlView: View {
  let node: ControlNode
  let timerMode: Bool
  @Environment(\.rufletEvents) private var events
  @State private var selection: Date
  @State private var timerSeconds: Int

  init(node: ControlNode, timerMode: Bool) {
    self.node = node
    self.timerMode = timerMode
    let formatter = ISO8601DateFormatter()
    _selection = State(initialValue: node.string("value").flatMap(formatter.date(from:)) ?? Date())
    _timerSeconds = State(initialValue: RufletCupertinoTimerModel.seconds(from: node.props["value"]))
  }

  @ViewBuilder
  var body: some View {
    if timerMode {
      timerPicker
    } else {
      datePicker
    }
  }

  private var datePicker: some View {
    VStack(spacing: 0) {
      if dateConfiguration.showsWeekday {
        Text(dateConfiguration.weekdayLabel(for: selection))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      DatePicker("", selection: $selection, in: allowedRange, displayedComponents: components)
        .modifier(WheelDatePickerStyle())
        .labelsHidden()
    }
    .environment(\.locale, pickerLocale)
    .frame(minHeight: CGFloat(dateConfiguration.itemExtent) * 5)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .onChange(of: selection) { value in
      let snapped = dateConfiguration.snapped(value)
      if snapped != value {
        selection = snapped
        return
      }
      events.commit(node, value: .string(ISO8601DateFormatter().string(from: value)))
    }
    .onChange(of: node.string("value")) { wireValue in
      guard let wireValue,
        let next = ISO8601DateFormatter().date(from: wireValue),
        next != selection
      else { return }
      selection = next
    }
  }

  private var timerPicker: some View {
    HStack(spacing: 0) {
      if timerColumns.hours {
        durationColumn(
          values: Array(0..<24), selection: hoursBinding,
          suffix: "h")
      }
      if timerColumns.minutes {
        durationColumn(
          values: strideValues(interval: node.int("minute_interval") ?? 1),
          selection: minutesBinding, suffix: "min")
      }
      if timerColumns.seconds {
        durationColumn(
          values: strideValues(interval: node.int("second_interval") ?? 1),
          selection: secondsBinding, suffix: "sec")
      }
    }
    .frame(minHeight: CGFloat(node.double("item_extent") ?? 32) * 5)
    .frame(
      maxWidth: .infinity,
      alignment: ControlProps.alignment(node.props["alignment"]) ?? .center)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .onChange(of: node.props["value"]) { value in
      let seconds = RufletCupertinoTimerModel.seconds(from: value)
      guard seconds != timerSeconds else { return }
      timerSeconds = seconds
    }
  }

  private func durationColumn(values: [Int], selection: Binding<Int>, suffix: String) -> some View {
    Picker("", selection: selection) {
      ForEach(values, id: \.self) { value in
        Text("\(value) \(suffix)").tag(value)
      }
    }
    .modifier(WheelPickerStyle())
    .labelsHidden()
    .frame(maxWidth: .infinity)
  }

  private var timerColumns: (hours: Bool, minutes: Bool, seconds: Bool) {
    RufletCupertinoTimerModel.columns(mode: node.string("mode"))
  }

  private func strideValues(interval: Int) -> [Int] {
    RufletCupertinoTimerModel.values(interval: interval)
  }

  private var hoursBinding: Binding<Int> {
    Binding(get: { timerSeconds / 3_600 }, set: { setTimer(hours: $0) })
  }

  private var minutesBinding: Binding<Int> {
    Binding(
      get: {
        RufletCupertinoTimerModel.snap(
          (timerSeconds % 3_600) / 60, interval: node.int("minute_interval") ?? 1)
      },
      set: { setTimer(minutes: $0) })
  }

  private var secondsBinding: Binding<Int> {
    Binding(
      get: {
        RufletCupertinoTimerModel.snap(
          timerSeconds % 60, interval: node.int("second_interval") ?? 1)
      },
      set: { setTimer(seconds: $0) })
  }

  private func setTimer(hours: Int? = nil, minutes: Int? = nil, seconds: Int? = nil) {
    let next = (hours ?? timerSeconds / 3_600) * 3_600
      + (minutes ?? (timerSeconds % 3_600) / 60) * 60
      + (seconds ?? timerSeconds % 60)
    timerSeconds = next
    events.commit(
      node,
      value: RufletCupertinoTimerModel.wireValue(
        seconds: next, preserving: node.props["value"]))
  }

  private var pickerLocale: Locale {
    dateConfiguration.locale
  }

  private var dateConfiguration: RufletCupertinoDatePickerConfiguration {
    RufletCupertinoDatePickerConfiguration(node: node)
  }

  /// `first_date`/`last_date` bound the wheel; `minimum_year`/`maximum_year`
  /// are the coarser form Flutter offers in year mode.
  private var allowedRange: ClosedRange<Date> {
    let calendar = Calendar.current
    let formatter = ISO8601DateFormatter()
    let lower = node.string("first_date").flatMap(formatter.date(from:))
      ?? node.int("minimum_year").flatMap {
        calendar.date(from: DateComponents(year: $0, month: 1, day: 1))
      }
      ?? Date.distantPast
    let upper = node.string("last_date").flatMap(formatter.date(from:))
      ?? node.int("maximum_year").flatMap {
        calendar.date(from: DateComponents(year: $0, month: 12, day: 31))
      }
      ?? Date.distantFuture
    return lower <= upper ? lower...upper : Date.distantPast...Date.distantFuture
  }

  private var components: DatePickerComponents {
    switch dateConfiguration.mode {
    case .time: return [.hourAndMinute]
    case .date, .monthYear: return [.date]
    case .dateAndTime: return [.date, .hourAndMinute]
    }
  }
}

enum RufletCupertinoDatePickerMode: Equatable {
  case time
  case date
  case dateAndTime
  case monthYear

  init(_ value: String?) {
    switch value?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "time": self = .time
    case "date": self = .date
    case "monthyear": self = .monthYear
    default: self = .dateAndTime
    }
  }
}

enum RufletCupertinoDateOrder: String, Equatable {
  case dmy
  case mdy
  case ymd
  case ydm

  init?(_ value: String?) {
    guard let value,
      let order = Self(rawValue: value.lowercased().replacingOccurrences(of: "_", with: ""))
    else { return nil }
    self = order
  }
}

/// Source-derived `CupertinoDatePicker` constructor contract. The visible
/// view reads this single model rather than accumulating local Apple defaults
/// that drift from the Flet engine.
struct RufletCupertinoDatePickerConfiguration {
  let mode: RufletCupertinoDatePickerMode
  let order: RufletCupertinoDateOrder?
  let showDayOfWeek: Bool
  let use24HourFormat: Bool
  let itemExtent: Double
  let minuteInterval: Int
  let baseLocaleIdentifier: String

  init(node: ControlNode) {
    mode = RufletCupertinoDatePickerMode(node.string("date_picker_mode"))
    order = RufletCupertinoDateOrder(node.string("date_order"))
    showDayOfWeek = node.bool("show_day_of_week") ?? false
    use24HourFormat = node.bool("use_24h_format") ?? false
    itemExtent = node.double("item_extent") ?? 32
    minuteInterval = max(node.int("minute_interval") ?? 1, 1)
    baseLocaleIdentifier = node.string("locale") ?? Locale.current.identifier
  }

  var showsWeekday: Bool {
    showDayOfWeek && mode != .time
  }

  /// Flutter receives `dateOrder` as a wheel-order override. SwiftUI exposes
  /// that choice through Locale, so choose an ICU locale with the same order
  /// and then apply Flet's independent 12/24-hour override.
  var locale: Locale {
    let ordered: String
    switch order {
    case .dmy: ordered = "en_GB"
    case .mdy: ordered = "en_US"
    case .ymd: ordered = "ja_JP"
    case .ydm: ordered = "fa_IR"
    case nil: ordered = baseLocaleIdentifier
    }
    guard use24HourFormat else { return Locale(identifier: ordered) }
    return Locale(identifier: "\(ordered)@hours=h23")
  }

  func weekdayLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }

  /// CupertinoDatePicker only permits minute intervals that divide 60. Flet
  /// passes the interval to Flutter's constructor; snapping here gives the
  /// native wheel the same value contract even though SwiftUI does not expose
  /// a `minuteInterval` parameter.
  func snapped(_ date: Date, calendar: Calendar = .current) -> Date {
    guard minuteInterval > 1 else { return date }
    let minute = calendar.component(.minute, from: date)
    let snappedMinute = (minute / minuteInterval) * minuteInterval
    guard snappedMinute != minute else { return date }
    return calendar.date(byAdding: .minute, value: snappedMinute - minute, to: date) ?? date
  }
}

enum RufletCupertinoTimerModel {
  static func columns(mode: String?) -> (hours: Bool, minutes: Bool, seconds: Bool) {
    switch mode?.lowercased() {
    case "hour_minute", "hm": return (true, true, false)
    case "minute_second", "minute_seconds", "ms": return (false, true, true)
    default: return (true, true, true)
    }
  }

  static func values(interval: Int) -> [Int] {
    Array(stride(from: 0, to: 60, by: max(interval, 1)))
  }

  static func snap(_ value: Int, interval: Int) -> Int {
    let interval = max(interval, 1)
    return min(max((value / interval) * interval, 0), values(interval: interval).last ?? 0)
  }

  /// Flet preserves the original wire representation when the timer changes:
  /// numeric values remain seconds and Duration extension values remain
  /// Duration values. Ruby uses MessagePack extension type 3 for Duration.
  static func seconds(from value: RufletValue?) -> Int {
    guard let value else { return 0 }
    if let seconds = value.intValue { return max(seconds, 0) }
    if case .extended(type: 3, let payload) = value {
      return max(parseDurationPayload(payload), 0)
    }
    if let map = value.mapValue {
      return max(
        (map["days"]?.intValue ?? 0) * 86_400
          + (map["hours"]?.intValue ?? 0) * 3_600
          + (map["minutes"]?.intValue ?? 0) * 60
          + (map["seconds"]?.intValue ?? 0),
        0)
    }
    return 0
  }

  static func wireValue(seconds: Int, preserving original: RufletValue?) -> RufletValue {
    let seconds = max(seconds, 0)
    // The upstream engine checks `control.get("value") is int`, not whether
    // the value can be converted to an integer. Maps, doubles and missing
    // values therefore change to a Duration value after the first gesture.
    if case .int = original { return .int(Int64(seconds)) }
    return .extended(type: 3, string: durationPayload(seconds: seconds))
  }

  private static func parseDurationPayload(_ payload: String) -> Int {
    // Ruby's duration extension is either a numeric seconds payload or an
    // ISO-8601 duration. Accept both without changing the public wire type.
    if let seconds = Int(payload) { return seconds }
    let expression = try? NSRegularExpression(
      pattern: #"^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$"#)
    let range = NSRange(payload.startIndex..<payload.endIndex, in: payload)
    guard let match = expression?.firstMatch(in: payload, range: range) else { return 0 }
    func component(_ index: Int) -> Int {
      let range = match.range(at: index)
      guard range.location != NSNotFound, let swiftRange = Range(range, in: payload) else { return 0 }
      return Int(payload[swiftRange]) ?? 0
    }
    return component(1) * 86_400 + component(2) * 3_600 + component(3) * 60 + component(4)
  }

  private static func durationPayload(seconds: Int) -> String {
    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60
    let remainder = seconds % 60
    let dayPart = days == 0 ? "" : "\(days)D"
    return "P\(dayPart)T\(hours)H\(minutes)M\(remainder)S"
  }
}

/// `CupertinoActivityIndicator` — the iOS spinner.
struct CupertinoActivityIndicatorControlView: View {
  let node: ControlNode

  private var presentation: RufletCupertinoActivityIndicatorPresentation {
    RufletCupertinoActivityIndicatorPresentation(node: node)
  }

  @ViewBuilder
  var body: some View {
    switch presentation.mode {
    case .indeterminate(let animating):
      RufletNativeCupertinoActivityIndicator(
        animating: animating,
        color: MaterialPalette.color(presentation.colorToken))
        .frame(width: presentation.diameter, height: presentation.diameter)
    case .partiallyRevealed(let progress):
      RufletPartiallyRevealedCupertinoActivityIndicator(
        radius: presentation.radius,
        color: MaterialPalette.color(presentation.colorToken)
          ?? RufletCupertinoActivityIndicatorDefaults.partiallyRevealedColor,
        progress: progress)
    }
  }
}

enum RufletCupertinoActivityIndicatorMode: Equatable {
  case indeterminate(animating: Bool)
  case partiallyRevealed(progress: Double)
}

/// The arguments Flet 0.80.5 passes to Flutter's two Cupertino constructors.
/// A supplied progress always selects `partiallyRevealed` and therefore
/// ignores `animating`.
struct RufletCupertinoActivityIndicatorPresentation {
  let radius: CGFloat
  let colorToken: String?
  let mode: RufletCupertinoActivityIndicatorMode

  init(node: ControlNode) {
    radius = CGFloat(node.double("radius") ?? RufletCupertinoActivityIndicatorDefaults.radius)
    colorToken = node.string("color")
    if let progress = node.double("progress") {
      mode = .partiallyRevealed(
        progress: RufletCupertinoActivityIndicatorMetrics.clamped(progress))
    } else {
      mode = .indeterminate(animating: node.bool("animating") ?? true)
    }
  }

  var diameter: CGFloat { radius * 2 }
}

enum RufletCupertinoActivityIndicatorDefaults {
  static let radius = 10.0
  static let nativeDiameter: CGFloat = 20
  static let partiallyRevealedOpacity = 147.0 / 255.0

  /// Flutter's fallback is the dynamic iOS tick colour extracted from the
  /// native control. `primary` is Apple's adaptive label colour equivalent;
  /// the painter applies Flutter's 147/255 partial-tick alpha separately.
  static var partiallyRevealedColor: Color { .primary }
}

/// Flutter must paint its partially-revealed variant because Apple's native
/// progress indicators do not expose individual ticks. Keep that exceptional
/// static adapter small; the normal indeterminate mode below stays native.
private struct RufletPartiallyRevealedCupertinoActivityIndicator: View {
  let radius: CGFloat
  let color: Color
  let progress: Double

  var body: some View {
    ZStack {
      ForEach(0..<RufletCupertinoActivityIndicatorMetrics.revealedTicks(progress: progress), id: \.self) {
        index in
        Capsule()
          .fill(color.opacity(RufletCupertinoActivityIndicatorDefaults.partiallyRevealedOpacity))
          .frame(
            width: radius / RufletCupertinoActivityIndicatorDefaults.radius * 2,
            height: radius * 2 / 3)
          .offset(y: -radius * 2 / 3)
          .rotationEffect(
            .degrees(Double(index) * 360 / Double(RufletCupertinoActivityIndicatorMetrics.tickCount)))
      }
    }
    .frame(width: radius * 2, height: radius * 2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Progress")
    .accessibilityValue(Text(progress, format: .percent))
  }
}

enum RufletCupertinoActivityIndicatorMetrics {
  /// Flutter's pinned Cupertino painter has eight alpha/tick entries.
  static let tickCount = 8

  static func clamped(_ progress: Double) -> Double {
    min(max(progress, 0), 1)
  }

  static func revealedTicks(progress: Double) -> Int {
    Int(ceil(clamped(progress) * Double(tickCount)))
  }
}

#if canImport(UIKit)
  private struct RufletNativeCupertinoActivityIndicator: UIViewRepresentable {
    let animating: Bool
    let color: Color?

    func makeUIView(context: Context) -> UIActivityIndicatorView {
      let indicator = UIActivityIndicatorView(style: .medium)
      indicator.hidesWhenStopped = false
      configure(indicator)
      return indicator
    }

    func updateUIView(_ indicator: UIActivityIndicatorView, context: Context) {
      configure(indicator)
    }

    private func configure(_ indicator: UIActivityIndicatorView) {
      indicator.color = color.map(UIColor.init)
      if animating { indicator.startAnimating() } else { indicator.stopAnimating() }
    }
  }
#elseif canImport(AppKit)
  private struct RufletNativeCupertinoActivityIndicator: NSViewRepresentable {
    let animating: Bool
    let color: Color?

    func makeNSView(context: Context) -> NSProgressIndicator {
      let indicator = NSProgressIndicator()
      indicator.style = .spinning
      indicator.isIndeterminate = true
      indicator.isDisplayedWhenStopped = true
      configure(indicator)
      return indicator
    }

    func updateNSView(_ indicator: NSProgressIndicator, context: Context) {
      configure(indicator)
    }

    private func configure(_ indicator: NSProgressIndicator) {
      // AppKit does not publish a progress-indicator tint API. Preserve the
      // native adaptive colour when Flet omits color; SwiftUI's accent tint is
      // the supported native customization path when one is supplied.
      if animating { indicator.startAnimation(nil) } else { indicator.stopAnimation(nil) }
    }
  }
#else
  private struct RufletNativeCupertinoActivityIndicator: View {
    let animating: Bool
    let color: Color?

    var body: some View {
      ProgressView().tint(color).opacity(animating ? 1 : 0.999)
    }
  }
#endif

/// `CupertinoAppBar` — the iOS title bar.
struct CupertinoAppBarControlView: View {
  let node: ControlNode

  private var configuration: RufletCupertinoAppBarConfiguration {
    RufletCupertinoAppBarConfiguration(node: node)
  }

  var body: some View {
    Group {
      if configuration.large {
        VStack(alignment: .leading, spacing: 0) {
          chromeRow
          title.font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        ZStack {
          chromeRow
          title.font(.headline)
        }
      }
    }
    .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(
      top: 0, leading: 12, bottom: 0, trailing: 12))
    .frame(minHeight: configuration.height)
    .background(appBarBackground)
    .overlay(alignment: .bottom) { appBarBorder }
    .preferredColorScheme(preferredColorScheme)
  }

  private var chromeRow: some View {
    HStack(spacing: 8) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      }
      Spacer(minLength: 0)
      HStack(spacing: 8) {
        if let trailingID = node.controlID(forKey: "trailing") {
          ControlView(id: trailingID, axis: .none)
        } else {
          ForEach(actionIDs, id: \.self) { ControlView(id: $0, axis: .none) }
        }
      }
    }
    .frame(minHeight: 44)
  }

  @ViewBuilder
  private var title: some View {
    if let titleID = node.controlID(forKey: "title") ?? node.controlID(forKey: "middle") {
      ControlView(id: titleID, axis: .none)
    }
  }

  private var actionIDs: [Int] {
    node.controlIDs(forKey: "actions")
  }

  @ViewBuilder
  private var appBarBackground: some View {
    if let color = MaterialPalette.color(node.string("bgcolor")) {
      color
    } else if configuration.backgroundFilterBlur {
      Rectangle().fill(.ultraThinMaterial)
    } else {
      Color.clear
    }
  }

  @ViewBuilder
  private var appBarBorder: some View {
    if let border = node.map("border") {
      Rectangle()
        .fill(MaterialPalette.color(border["color"]?.stringValue, default: .secondary.opacity(0.25)))
        .frame(height: CGFloat(border["width"]?.doubleValue ?? 0))
    } else {
      Divider()
    }
  }

  private var preferredColorScheme: ColorScheme? {
    switch node.string("brightness")?.lowercased() {
    case "dark": return .dark
    case "light": return .light
    default: return nil
    }
  }
}

struct RufletCupertinoAppBarConfiguration {
  let large: Bool
  let automaticallyImplyLeading: Bool
  let automaticallyImplyTitle: Bool
  let transitionBetweenRoutes: Bool
  let automaticBackgroundVisibility: Bool
  let backgroundFilterBlur: Bool
  let previousPageTitle: String?

  init(node: ControlNode) {
    large = node.bool("large") ?? false
    automaticallyImplyLeading = node.bool("automatically_imply_leading") ?? true
    automaticallyImplyTitle = node.bool("automatically_imply_title") ?? true
    transitionBetweenRoutes = node.bool("transition_between_routes") ?? true
    automaticBackgroundVisibility = node.bool("automatic_background_visibility") ?? true
    backgroundFilterBlur = node.bool("background_filter_blur") ?? true
    previousPageTitle = node.string("previous_page_title")
  }

  var height: CGFloat { large ? 88 : 44 }
}

/// Flutter Cupertino constructor constants used by the presentation family.
/// These are intentionally independent of SwiftUI defaults: changing the
/// deployment SDK must not restyle a Ruflet control whose source of truth is
/// Flet 0.80.5 / Flutter 3.41.2.
enum RufletCupertinoPresentationDefaults {
  static let actionSheetEdgePadding: CGFloat = 8
  static let actionSheetCancelPadding: CGFloat = 8
  static let actionSheetContentHorizontalPadding: CGFloat = 16
  static let actionSheetContentVerticalPadding: CGFloat = 13.5
  static let actionSheetActionMinimumHeight: CGFloat = 57.17
  static let actionSheetCornerRadius: CGFloat = 12
  static let contextMenuActionMinimumHeight: CGFloat = 43
  static let contextMenuActionPadding = EdgeInsets(
    top: 8, leading: 15.5, bottom: 8, trailing: 17.5)
  static let alertInsetDurationMilliseconds: Double = 100
  static let bottomSheetPickerHeight: CGFloat = 220

  static func actionIDs(_ node: ControlNode) -> [Int] {
    node.controlIDs(forKey: "actions")
  }

  static func isValidContextMenu(_ node: ControlNode) -> Bool {
    node.controlID(forKey: "content") != nil && !actionIDs(node).isEmpty
  }

  static func hasAlertContent(_ node: ControlNode) -> Bool {
    node.props["title"] != nil
      || node.props["content"] != nil
      || !actionIDs(node).isEmpty
  }

  static func isDefaultAction(_ node: ControlNode) -> Bool {
    node.bool("default") == true
  }

  static func isDestructiveAction(_ node: ControlNode) -> Bool {
    node.bool("destructive") == true
  }
}

/// Flet's `CupertinoNavigationBar` is a `CupertinoTabBar`, despite its name:
/// destinations select an index and emit that integer through `change`.
struct CupertinoNavigationBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(destinationIDs.enumerated()), id: \.element) { index, id in
        Button {
          events.commit(node, key: "selected_index", value: .int(Int64(index)))
        } label: {
          destination(id, selected: index == (node.int("selected_index") ?? 0))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(node.bool("disabled") ?? false)
      }
    }
    .padding(.vertical, 6)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(alignment: .top) { Divider() }
  }

  private var destinationIDs: [Int] {
    var seen = Set<Int>()
    return (node.controlIDs(forKey: "destinations") + node.childIDs)
      .filter { seen.insert($0).inserted }
  }

  @ViewBuilder
  private func destination(_ id: Int, selected: Bool) -> some View {
    if let destination = store.node(id) {
      VStack(spacing: 2) {
        let iconID = selected
          ? destination.controlID(forKey: "selected_icon") ?? destination.controlID(forKey: "icon")
          : destination.controlID(forKey: "icon")
        if let iconID { destinationIcon(iconID) }
        Text(destination.string("label") ?? "")
          .font(.caption2)
      }
      .foregroundColor(
        selected
          ? MaterialPalette.color(node.string("active_color"), default: .accentColor)
          : MaterialPalette.color(node.string("inactive_color"), default: .secondary))
    }
  }

  @ViewBuilder
  private func destinationIcon(_ id: Int) -> some View {
    if let icon = store.node(id), icon.type == "Icon" {
      RufletIcon(
        value: icon.props["name"] ?? icon.props["icon"],
        size: icon.double("size").map { CGFloat($0) }
          ?? CGFloat(node.double("icon_size") ?? 30),
        color: MaterialPalette.color(icon.string("color")))
    } else {
      ControlView(id: id, axis: .none)
    }
  }
}

/// `CupertinoActionSheet` — a titled list of actions above a cancel button.
struct CupertinoActionSheetControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    actionSheet
  }

  private var actionSheet: some View {
    VStack(spacing: hasMainSheet
      ? RufletCupertinoPresentationDefaults.actionSheetCancelPadding : 0) {
      VStack(spacing: 0) {
        if hasTextOrWidget("title") {
          textOrWidget("title")
            .font(.system(
              size: 13,
              weight: hasTextOrWidget("message") ? .semibold : .regular))
            .foregroundColor(contentTextColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal,
                     RufletCupertinoPresentationDefaults.actionSheetContentHorizontalPadding)
            .padding(.top,
                     RufletCupertinoPresentationDefaults.actionSheetContentVerticalPadding)
            .padding(.bottom, !hasTextOrWidget("message")
              ? RufletCupertinoPresentationDefaults.actionSheetContentVerticalPadding : 0)
        }
        if hasTextOrWidget("message") {
          textOrWidget("message")
            .font(.system(
              size: 13,
              weight: hasTextOrWidget("title") ? .regular : .semibold))
            .foregroundColor(contentTextColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal,
                     RufletCupertinoPresentationDefaults.actionSheetContentHorizontalPadding)
            .padding(.top, !hasTextOrWidget("title")
              ? RufletCupertinoPresentationDefaults.actionSheetContentVerticalPadding : 4)
            .padding(.bottom,
                     RufletCupertinoPresentationDefaults.actionSheetContentVerticalPadding)
        }
        ForEach(node.controlIDs(forKey: "actions"), id: \.self) { actionID in
          Divider().background(dividerColor)
          action(actionID)
        }
      }
      .background(sheetSurface, in: RoundedRectangle(
        cornerRadius: RufletCupertinoPresentationDefaults.actionSheetCornerRadius))
      .clipShape(RoundedRectangle(
        cornerRadius: RufletCupertinoPresentationDefaults.actionSheetCornerRadius))

      if let cancelID = node.controlID(forKey: "cancel") {
        action(cancelID)
          .background(cancelSurface, in: RoundedRectangle(
            cornerRadius: RufletCupertinoPresentationDefaults.actionSheetCornerRadius))
          .clipShape(RoundedRectangle(
            cornerRadius: RufletCupertinoPresentationDefaults.actionSheetCornerRadius))
      }
    }
    .padding(.horizontal, RufletCupertinoPresentationDefaults.actionSheetEdgePadding)
    .padding(.bottom, RufletCupertinoPresentationDefaults.actionSheetEdgePadding)
  }

  @ViewBuilder
  private func action(_ id: Int) -> some View {
    if let action = store.node(id) {
      Button {
        guard action.bool("disabled") != true else { return }
        events.fire(action, "click")
      } label: {
        actionContent(action)
          .font(.system(size: 17, weight: action.bool("default") == true ? .semibold : .regular))
          .foregroundColor(action.bool("destructive") == true ? .red : .accentColor)
          .frame(maxWidth: .infinity, minHeight:
            RufletCupertinoPresentationDefaults.actionSheetActionMinimumHeight)
          .padding(.horizontal, 10)
      }
      .buttonStyle(.plain)
      .background(sheetSurface)
      .disabled(action.bool("disabled") == true)
    }
  }

  @ViewBuilder
  private func actionContent(_ action: ControlNode) -> some View {
    if let contentID = action.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else if let content = action.string("content") {
      Text(content)
    } else {
      Text("content must be provided").foregroundColor(.red)
    }
  }

  @ViewBuilder
  private func textOrWidget(_ key: String) -> some View {
    if let id = node.controlID(forKey: key) {
      ControlView(id: id, axis: .none)
    } else if let text = node.string(key) {
      Text(text)
    }
  }

  private func hasTextOrWidget(_ key: String) -> Bool {
    node.controlID(forKey: key) != nil || node.string(key) != nil
  }

  private var hasMainSheet: Bool {
    hasTextOrWidget("title") || hasTextOrWidget("message")
      || !node.controlIDs(forKey: "actions").isEmpty
  }

  private var sheetSurface: Color {
    colorScheme == .dark
      ? Color(.sRGB, red: 41 / 255, green: 41 / 255, blue: 41 / 255, opacity: 190 / 255)
      : Color(.sRGB, red: 252 / 255, green: 252 / 255, blue: 252 / 255, opacity: 200 / 255)
  }

  private var cancelSurface: Color {
    colorScheme == .dark
      ? Color(.sRGB, red: 44 / 255, green: 44 / 255, blue: 44 / 255, opacity: 1)
      : .white
  }

  private var contentTextColor: Color {
    colorScheme == .dark
      ? Color(.sRGB, red: 241 / 255, green: 241 / 255, blue: 241 / 255, opacity: 150 / 255)
      : Color(.sRGB, red: 29 / 255, green: 29 / 255, blue: 29 / 255, opacity: 133 / 255)
  }

  private var dividerColor: Color {
    colorScheme == .dark
      ? Color(.sRGB, red: 125 / 255, green: 125 / 255, blue: 125 / 255, opacity: 213 / 255)
      : Color(.sRGB, red: 201 / 255, green: 201 / 255, blue: 201 / 255, opacity: 212 / 255)
  }
}

/// Native Apple context menu corresponding to Flutter's
/// `CupertinoContextMenu`. SwiftUI supplies the platform preview/animation and
/// closes the menu after a child action is selected.
struct CupertinoContextMenuControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    if !RufletCupertinoPresentationDefaults.isValidContextMenu(node) {
      Text(node.controlID(forKey: "content") == nil
        ? "CupertinoContextMenu.content must be visible"
        : "CupertinoContextMenu.actions requires at least one visible action")
        .foregroundColor(.red)
    } else if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
        .contextMenu {
          ForEach(RufletCupertinoPresentationDefaults.actionIDs(node), id: \.self) { id in
            contextAction(id)
          }
        }
    }
  }

  @ViewBuilder
  private func contextAction(_ id: Int) -> some View {
    if let action = store.node(id) {
      Button(role: action.bool("destructive") == true ? .destructive : nil) {
        guard action.bool("disabled") != true else { return }
        events.fire(action, "click")
      } label: {
        HStack {
          actionContent(action)
            .font(.system(size: 16,
                          weight: action.bool("default") == true ? .semibold : .regular))
          if let icon = action.props["trailing_icon"] {
            RufletIcon(value: icon, size: 21, color: nil)
          }
        }
      }
      .disabled(action.bool("disabled") == true)
    }
  }

  @ViewBuilder
  private func actionContent(_ action: ControlNode) -> some View {
    if let contentID = action.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      Text(action.string("content") ?? "").lineLimit(1)
    }
  }
}

/// The scrolling wheel exists only on iOS; macOS gets the menu picker, which is
/// what a Mac app would use for the same choice.
private struct WheelPickerStyle: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.pickerStyle(.wheel)
    #else
      content.pickerStyle(.menu)
    #endif
  }
}

private struct WheelDatePickerStyle: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.datePickerStyle(.wheel)
    #else
      content.datePickerStyle(.field)
    #endif
  }
}
