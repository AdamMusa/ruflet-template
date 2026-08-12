import RufletEngine
import RufletProtocol
import SwiftUI

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

  @ViewBuilder
  var body: some View {
    switch variant {
    case .plain:
      configuredButton.buttonStyle(.borderless)
    case .filled:
      configuredButton.buttonStyle(.borderedProminent)
    case .tinted:
      configuredButton.buttonStyle(.bordered)
    }
  }

  private enum Variant { case plain, filled, tinted }

  private var variant: Variant {
    switch node.type {
    case "CupertinoFilledButton": return .filled
    case "CupertinoTintedButton": return .tinted
    default: return .plain
    }
  }

  private var configuredButton: some View {
    Button(action: activate) { label }
      // CupertinoButton receives nil for omitted padding, color and bgcolor.
      // These optional modifiers preserve that native constructor behavior.
      .modifier(OptionalEdgeInsets(insets: RufletThemeDefaults.cupertinoButtonPadding(node)))
      .modifier(OptionalMinimumSize(value: node.props["min_size"]))
      .modifier(OptionalTint(color: cupertinoFill))
      .modifier(OptionalForeground(color: MaterialPalette.color(node.string("color"))))
      .modifier(FocusReporter(node: node, events: events))
      .modifier(LongPressReporter(node: node, events: events))
      // Cupertino dims a button while it is held rather than washing it.
      // Flet passes 0.4 when the property is omitted, matching
      // CupertinoButton.pressedOpacity rather than SwiftUI's button-style
      // feedback.
      .modifier(CupertinoPressOpacity(value: node.double("opacity_on_click") ?? 0.4))
      .disabled(node.bool("disabled") ?? false)
  }

  @ViewBuilder
  private var label: some View {
    let icon = node.props["icon"]
    HStack(spacing: RufletThemeDefaults.materialButtonIconSpacing) {
      if icon != nil {
        RufletIcon(
          value: icon,
          size: node.double("icon_size").map { CGFloat($0) }
            ?? RufletThemeDefaults.materialIconButtonSize,
          color: MaterialPalette.color(node.string("icon_color")))
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        Text(node.string("content") ?? node.string("text") ?? "")
      }
    }
  }

  /// A disabled Cupertino button has its own fill rather than a dimmed one.
  private var cupertinoFill: Color? {
    if node.bool("disabled") == true,
      let disabled = MaterialPalette.color(node.string("disabled_bgcolor"))
    {
      return disabled
    }
    return MaterialPalette.color(node.string("bgcolor"))
  }

  private func activate() {
    if let url = node.string("url").flatMap(URL.init(string:)) { openURL(url) }
    events.fire(node, "click")
  }
}

/// Cupertino's press feedback is a fade, and the button names how far.
private struct CupertinoPressOpacity: ViewModifier {
  let value: Double
  @State private var pressed = false

  func body(content: Content) -> some View {
    content
      .opacity(pressed ? value : 1)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in pressed = true }
          .onEnded { _ in pressed = false })
  }
}

private struct OptionalEdgeInsets: ViewModifier {
  let insets: EdgeInsets?
  func body(content: Content) -> some View {
    if let insets { content.padding(insets) } else { content }
  }
}

private struct OptionalMinimumSize: ViewModifier {
  let value: RufletValue?
  func body(content: Content) -> some View {
    if let map = value?.mapValue {
      let width = CGFloat(map["width"]?.doubleValue ?? 0)
      let height = CGFloat(map["height"]?.doubleValue ?? 0)
      content.frame(
        minWidth: width,
        minHeight: height)
    } else {
      content
    }
  }
}

/// `CupertinoSwitch` — the same native toggle, which is already the iOS one.
struct CupertinoSwitchControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletListTileClicks) private var listTileClicks

  var body: some View {
    HStack(spacing: 8) {
      if labelPosition == .left { label }
      Toggle("", isOn: binding)
        .labelsHidden()
        .toggleStyle(.switch)
        // Ruby names the switch's colours after the parts they paint, the way
        // Flutter's CupertinoSwitch does: the track when on is
        // `active_track_color`, not the `active_color` the sliders and
        // selection controls use.
        .tint(trackColor)
        .overlay(thumbOverlay)
        .background(thumbImageValidation)
        .modifier(SwitchTrackOutline(node: node))
      if labelPosition == .right { label }
    }
    .modifier(ListTileToggleListener(notifier: listTileClicks, action: toggleFromListTile))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(node.bool("disabled") ?? false)
  }

  private var binding: Binding<Bool> {
    Binding(
      get: { node.bool("value") ?? false },
      set: {
        RufletValueControlEvents.commit(
          node, value: .bool($0), payload: .none, to: events)
      })
  }

  private func toggleFromListTile() {
    binding.wrappedValue.toggle()
  }

  private enum LabelPlacement { case left, right }

  private var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  /// The on and off label colours tint the tiny I/O marks Cupertino draws
  /// inside the track.
  @ViewBuilder
  private var label: some View {
    if let text = node.string("label") {
      Text(text)
        .foregroundColor(node.bool("disabled") == true ? .secondary : nil)
        .contentShape(Rectangle())
        .onTapGesture {
          guard node.bool("disabled") != true else { return }
          binding.wrappedValue.toggle()
        }
    }
  }

  private var trackColor: Color? {
    guard node.bool("value") ?? false else {
      return MaterialPalette.color(node.string("inactive_track_color"))
    }
    return MaterialPalette.color(node.string("active_track_color"))
  }

  /// `thumb_icon` and the thumb colours paint the knob, which SwiftUI's Toggle
  /// does not expose, so they are drawn over it.
  @ViewBuilder
  private var thumbOverlay: some View {
    let on = node.bool("value") ?? false
    let tint = on
      ? MaterialPalette.color(node.string("thumb_color"))
      : MaterialPalette.color(node.string("inactive_thumb_color"))
    if node.props["thumb_icon"] != nil || tint != nil {
      HStack {
        if on { Spacer(minLength: 0) }
        RufletIcon(value: node.props["thumb_icon"], size: 12, color: tint)
        if !on { Spacer(minLength: 0) }
      }
      .padding(.horizontal, 4)
      .allowsHitTesting(false)
    }
  }

  @ViewBuilder
  private var thumbImageValidation: some View {
    let source = node.bool("value") == true
      ? node.string("active_thumb_image") ?? node.string("active_thumb_image_src")
      : node.string("inactive_thumb_image") ?? node.string("inactive_thumb_image_src")
    if let source, let url = URL(string: source), url.scheme != nil {
      AsyncImage(url: url) { phase in
        if case .failure(let error) = phase {
          Color.clear.onAppear {
            events.fire(node, "image_error", data: .string(error.localizedDescription))
          }
        }
      }
      .frame(width: 0, height: 0)
      .hidden()
    }
  }
}

/// `track_outline_color` and `track_outline_width` stroke the track, which
/// Cupertino draws around an off switch.
private struct SwitchTrackOutline: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    guard let color = MaterialPalette.color(node.string("track_outline_color")) else {
      return AnyView(content)
    }
    return AnyView(
      content.overlay(
        Capsule().strokeBorder(
          color, lineWidth: CGFloat(node.double("track_outline_width") ?? 1))))
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
  @State private var hovering = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var revealed = false

  private var styling: RufletFieldStyling {
    RufletFieldStyling(node: node, focused: focused, hovering: hovering)
  }

  var body: some View {
    HStack(alignment: styling.verticalAlignment, spacing: 6) {
      overlay(key: "prefix_icon", mode: node.string("prefix_visibility_mode"))
        .modifier(CupertinoSlotConstraints(value: node.props["prefix_icon_size_constraints"]))
      overlay(key: "prefix", mode: node.string("prefix_visibility_mode"), styleKey: "prefix_style")
      field
      overlay(key: "suffix", mode: node.string("suffix_visibility_mode"), styleKey: "suffix_style")
      overlay(key: "suffix_icon", mode: node.string("suffix_visibility_mode"))
        .modifier(CupertinoSlotConstraints(value: node.props["suffix_icon_size_constraints"]))
      revealButton
      clearButton
    }
    .padding(styling.contentPadding)
    .frame(
      maxWidth: styling.fitsParent ? .infinity : nil,
      maxHeight: styling.fitsParent ? .infinity : nil)
    .background(fieldDecoration)
    .overlay(borderStroke)
    .modifier(ChromeClipModifier(behavior: styling.clipBehavior))
    .modifier(CupertinoFieldShadows(value: node.props["shadows"]))
    .onHover { hovering = $0 }
    .modifier(RufletFormFieldDecoration(node: node))
    .onAppear {
      focused = node.bool("autofocus") == true
      selection = RufletTextSelection.explicit(on: node)
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .onChange(of: selection) { RufletTextSelection.report($0, on: node, to: events) }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus": focused = true; completion(.success(.null))
      case "blur": focused = false; completion(.success(.null))
      default: completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
  }

  @ViewBuilder
  private var field: some View {
    // An adaptive TextField arrives here carrying Material's names, so Flet
    // falls back to the label when there is no placeholder.
    let placeholder = node.string("placeholder_text") ?? node.string("label") ?? ""
    let obscure = node.bool("password") == true && !revealed
    if styling.isMultiline {
      TextEditor(text: binding)
        .rufletTextStyle(styling.textStyle)
        .lineLimit(styling.maxLines)
        .frame(minHeight: CGFloat(styling.minLines * 20))
        .padding(styling.scrollPadding)
    } else {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          placeholder: placeholder,
          secure: obscure,
          traits: styling.traits,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(
            CupertinoPlaceholder(node: node, showing: binding.wrappedValue.isEmpty))
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
    let shape = RoundedRectangle(cornerRadius: styling.cornerRadius)
    if let gradient = GradientProps.linear(node.props["gradient"]) {
      shape.fill(gradient)
    } else if let source = node.string("image").flatMap({ URL(string: $0) }),
      source.scheme != nil
    {
      AsyncImage(url: source) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        shape.fill(styling.background(default: .gray.opacity(0.12)))
      }
      .clipShape(shape)
      .blendMode(ControlProps.blendMode(node.string("blend_mode")))
    } else {
      shape.fill(styling.background(default: .gray.opacity(0.12)))
    }
  }

  /// Flutter's `OverlayVisibilityMode`, which decides whether the clear button
  /// and the prefix and suffix slots are shown against the editing state.
  private func shows(_ mode: String?, default fallback: Bool) -> Bool {
    switch mode?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "never": return false
    case "editing": return focused
    case "notediting": return !focused
    case "always": return true
    default: return fallback
    }
  }

  @ViewBuilder
  private func overlay(key: String, mode: String?, styleKey: String? = nil) -> some View {
    if shows(mode, default: true) {
      RufletFormFieldSlot(node: node, key: key, styleKey: styleKey)
    }
  }

  /// `clear_button_visibility_mode` defaults to never, the way
  /// CupertinoTextField's own does.
  @ViewBuilder
  private var clearButton: some View {
    if shows(node.string("clear_button_visibility_mode"), default: false),
      !(node.string("value") ?? "").isEmpty {
      Button {
        events.commit(node, value: .string(""))
      } label: {
        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(node.string("clear_button_semantics_label") ?? "Clear")
    }
  }

  @ViewBuilder
  private var revealButton: some View {
    if node.bool("password") == true, node.bool("can_reveal_password") == true {
      Button {
        revealed.toggle()
      } label: {
        Image(systemName: revealed ? "eye.slash" : "eye").foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
  }

  private var binding: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }

  @ViewBuilder
  private var borderStroke: some View {
    if styling.drawsBorder {
      RoundedRectangle(cornerRadius: styling.cornerRadius)
        .strokeBorder(
          styling.borderColor(default: .clear), lineWidth: styling.borderWidth)
    }
  }
}

/// Cupertino's `placeholder_style` and the hint's line limit and fade, which
/// neither platform field styles directly, so the text is drawn over an empty
/// field.
private struct CupertinoPlaceholder: ViewModifier {
  let node: ControlNode
  let showing: Bool

  func body(content: Content) -> some View {
    guard node.map("placeholder_style") != nil || node.map("hint_style") != nil
      || node.int("hint_max_lines") != nil
    else { return AnyView(content) }
    let text = node.string("placeholder_text") ?? node.string("hint_text") ?? ""
    let styleKey = node.map("placeholder_style") != nil ? "placeholder_style" : "hint_style"
    let duration = (node.double("hint_fade_duration") ?? 0) / 1_000
    return AnyView(
      content.overlay(alignment: .leading) {
        Text(text)
          .lineLimit(node.int("hint_max_lines"))
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: styleKey))
          .opacity(showing ? 1 : 0)
          .animation(.easeInOut(duration: duration), value: showing)
          .allowsHitTesting(false)
      })
  }
}

private struct CupertinoSlotConstraints: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    if let constraints = ControlProps.sizeConstraints(value) {
      content.frame(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight)
    } else {
      content
    }
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

  var body: some View {
    RufletCupertinoActivityIndicator(
      radius: CGFloat(node.double("radius") ?? 10),
      color: MaterialPalette.color(node.string("color")) ?? .secondary,
      progress: node.double("progress"),
      animating: node.double("progress") == nil && (node.bool("animating") ?? true))
  }
}

/// Flet uses `CupertinoActivityIndicator.partiallyRevealed` when `progress`
/// is supplied. SwiftUI's determinate `ProgressView` is a ring, not
/// Cupertino's twelve spokes, so the native renderer draws the same spoke
/// model and only reveals the requested fraction.
struct RufletCupertinoActivityIndicator: View {
  let radius: CGFloat
  let color: Color
  let progress: Double?
  let animating: Bool
  @State private var rotation = 0.0

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let spokeCount = RufletCupertinoActivityIndicatorMetrics.spokeCount
      let visible = RufletCupertinoActivityIndicatorMetrics.revealedSpokes(progress: progress)
      let length = max(radius * 0.46, 1)
      let width = max(radius * 0.22, 1)

      for index in 0..<visible {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius + width / 2))
        path.addLine(
          to: CGPoint(x: center.x, y: center.y - radius + width / 2 + length))
        var spoke = context
        spoke.translateBy(x: center.x, y: center.y)
        spoke.rotate(by: .degrees(Double(index) * 360 / Double(spokeCount)))
        spoke.translateBy(x: -center.x, y: -center.y)
        spoke.opacity = progress == nil
          ? 0.25 + (0.75 * Double(index + 1) / Double(spokeCount))
          : 1
        spoke.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
      }
    }
    .frame(width: radius * 2, height: radius * 2)
    .rotationEffect(.degrees(rotation))
    .onAppear { updateAnimation() }
    .onChange(of: animating) { _ in updateAnimation() }
  }

  private func updateAnimation() {
    guard animating else {
      rotation = 0
      return
    }
    rotation = 0
    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
      rotation = 360
    }
  }
}

enum RufletCupertinoActivityIndicatorMetrics {
  static let spokeCount = 12

  static func revealedSpokes(progress: Double?) -> Int {
    guard let progress else { return spokeCount }
    return Int(ceil(min(max(progress, 0), 1) * Double(spokeCount)))
  }
}

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
