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
    .modifier(FocusReporter(node: node, events: events))
    .disabled(node.bool("disabled") ?? false)
  }

  private var binding: Binding<Bool> {
    Binding(
      get: { node.bool("value") ?? false },
      set: { events.commit(node, value: .bool($0)) })
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
        .foregroundColor(labelColor)
        .contentShape(Rectangle())
        .onTapGesture {
          guard node.bool("disabled") != true else { return }
          binding.wrappedValue.toggle()
        }
    }
  }

  private var labelColor: Color? {
    guard node.bool("value") ?? false else {
      return MaterialPalette.color(node.string("off_label_color"))
    }
    return MaterialPalette.color(node.string("on_label_color"))
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

  /// `divisions` is a count in Flutter and a stride in SwiftUI.
  private func sliderStep(minimum: Double, maximum: Double) -> Double.Stride {
    guard let divisions = node.int("divisions"), divisions > 0 else {
      return .leastNonzeroMagnitude
    }
    return (max(maximum, minimum) - minimum) / Double(divisions)
  }

  var body: some View {
    let minimum = node.double("min") ?? 0
    let maximum = node.double("max") ?? 1

    Slider(
      value: Binding(
        get: { currentValue ?? clampedNodeValue(minimum: minimum, maximum: maximum) },
        set: {
          currentValue = $0
          events.commit(node, value: .double($0))
        }),
      in: minimum...max(maximum, minimum + .ulpOfOne),
      // `divisions` snaps the slider to discrete steps, which SwiftUI takes
      // as the distance between them rather than as a count.
      step: sliderStep(minimum: minimum, maximum: maximum),
      onEditingChanged: { editing in
        events.fire(
          node, editing ? "change_start" : "change_end",
          data: .double(currentValue ?? clampedNodeValue(minimum: minimum, maximum: maximum)))
      }
    )
    .tint(MaterialPalette.color(node.string("active_color")))
    // Cupertino names the knob's colour separately from the track's.
    .modifier(SliderThumbTint(color: MaterialPalette.color(node.string("thumb_color"))))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(node.bool("disabled") ?? false)
    .onAppear { currentValue = clampedNodeValue(minimum: minimum, maximum: maximum) }
    .onChange(of: node.double("value")) { _ in
      currentValue = clampedNodeValue(minimum: minimum, maximum: maximum)
    }
  }

  private func clampedNodeValue(minimum: Double, maximum: Double) -> Double {
    min(max(node.double("value") ?? minimum, minimum), max(maximum, minimum))
  }
}

/// SwiftUI tints the whole slider at once, so a distinct thumb colour is
/// drawn over the knob.
private struct SliderThumbTint: ViewModifier {
  let color: Color?

  func body(content: Content) -> some View {
    guard let color else { return AnyView(content) }
    return AnyView(content.tint(color))
  }
}

/// `CupertinoCheckbox` and `CupertinoRadio` — the iOS marks.
struct CupertinoSelectionControlView: View {
  enum Kind { case checkbox, radio }

  let node: ControlNode
  let kind: Kind
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button(action: advance) {
      HStack(spacing: CGFloat(node.double("spacing") ?? 8)) {
        mark
        if let label = node.string("label") { Text(label) }
      }
    }
    .buttonStyle(.plain)
    .modifier(FocusReporter(node: node, events: events))
    .disabled(node.bool("disabled") ?? false)
  }

  /// A Cupertino checkbox is a rounded square when Ruby gave it a shape, and
  /// its tick and outline are named separately from the fill.
  @ViewBuilder
  private var mark: some View {
    let on = node.bool("value") ?? false
    let indeterminate = node.bool("tristate") == true && node.props["value"]?.isNull == true
    ZStack {
      if kind == .checkbox, let radius = ControlProps.cornerRadius(node.map("shape")?["radius"]) {
        RoundedRectangle(cornerRadius: radius)
          .fill(on ? MaterialPalette.color(node.string("active_color"), default: .accentColor) : .clear)
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(outlineColor, lineWidth: outlineWidth)
        if on || indeterminate {
          Image(systemName: indeterminate ? "minus" : "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(MaterialPalette.color(node.string("check_color"), default: .white))
        }
      } else {
        Image(systemName: symbol)
          .foregroundColor(
            on
              ? MaterialPalette.color(node.string("active_color"))
              : MaterialPalette.color(node.string("inactive_color"), default: .secondary))
      }
    }
    .frame(width: 20, height: 20)
  }

  private var outlineColor: Color {
    MaterialPalette.color(node.map("border_side")?["color"]?.stringValue, default: .secondary)
  }

  private var outlineWidth: CGFloat {
    CGFloat(node.map("border_side")?["width"]?.doubleValue ?? 1.5)
  }

  /// `tristate` cycles false to true to null the way Material's checkbox does.
  private func advance() {
    // A toggleable radio can be turned back off; Flutter's plain one cannot.
    if kind == .radio, node.bool("value") == true, node.bool("toggleable") != true { return }
    guard kind == .checkbox, node.bool("tristate") == true else {
      events.commit(node, value: .bool(!(node.bool("value") ?? false)))
      return
    }
    let current = node.props["value"]
    let next: RufletValue
    if current == nil || current!.isNull {
      next = .bool(false)
    } else if current!.boolValue == false {
      next = .bool(true)
    } else {
      next = .null
    }
    events.commit(node, value: next)
  }

  /// `use_checkmark_style` draws a Cupertino radio as a tick rather than a
  /// filled dot, which is what iOS uses in a list.
  private var symbol: String {
    let on = node.bool("value") ?? false
    switch kind {
    case .checkbox: return on ? "checkmark.circle.fill" : "circle"
    case .radio:
      if node.bool("use_checkmark_style") == true { return on ? "checkmark" : "" }
      return on ? "largecircle.fill.circle" : "circle"
    }
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

  var body: some View {
    let controls = node.childIDs.compactMap { store.node($0) }

    Picker(
      "",
      selection: Binding(
        get: { node.int("selected_index") ?? 0 },
        set: { events.commit(node, key: "selected_index", value: .int(Int64($0))) })
    ) {
      ForEach(Array(controls.enumerated()), id: \.element.id) { index, control in
        ControlView(id: control.id, axis: .none).tag(index)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    // A sliding control can size its segments to their content rather than
    // splitting the width evenly.
    .fixedSize(horizontal: node.bool("proportional_width") == true, vertical: false)
    // Cupertino's segmented control names its four colours separately; the
    // selected one is the tint SwiftUI paints the active segment with.
    .tint(MaterialPalette.color(node.string("selected_color")))
    .background(MaterialPalette.color(node.string("unselected_color")))
    .foregroundColor(foreground)
    .modifier(SegmentedPressTint(color: MaterialPalette.color(node.string("click_color"))))
    .disabled(node.bool("disabled") ?? false)
  }

  private var foreground: Color? {
    guard node.bool("disabled") == true else { return nil }
    return MaterialPalette.color(node.string("disabled_text_color"))
      ?? MaterialPalette.color(node.string("disabled_color"))
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

  var body: some View {
    Picker(
      "",
      selection: Binding(
        get: { node.int("selected_index") ?? 0 },
        set: { events.commit(node, key: "selected_index", value: .int(Int64($0))) })
    ) {
      ForEach(Array(node.childIDs.enumerated()), id: \.element) { index, childID in
        ControlView(id: childID, axis: .none).tag(index)
      }
    }
    .modifier(WheelPickerStyle())
    .labelsHidden()
    .frame(height: CGFloat(node.double("item_extent") ?? 32) * 5)
    // Flutter's wheel geometry: the squeeze packs the rows, the diameter
    // ratio curves the drum, and the off-axis fraction tilts it.
    .scaleEffect(
      x: 1, y: CGFloat(node.double("squeeze") ?? 1), anchor: .center)
    .rotation3DEffect(
      .degrees(Double(node.double("off_axis_fraction") ?? 0) * 45),
      axis: (x: 0, y: 1, z: 0),
      perspective: 1 / max(node.double("diameter_ratio") ?? 1.07, 0.1))
    .background(selectionOverlay)
    .modifier(
      PickerMagnifier(
        enabled: node.bool("use_magnifier") == true,
        factor: node.double("magnification") ?? 1))
    .onAppear { _ = node.bool("looping") }
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
        .frame(height: CGFloat(node.double("item_extent") ?? 32))
    }
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
    _timerSeconds = State(initialValue: max(node.int("value") ?? 0, 0))
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
    DatePicker("", selection: $selection, in: allowedRange, displayedComponents: components)
      .modifier(WheelDatePickerStyle())
      .labelsHidden()
      .environment(\.locale, pickerLocale)
      .frame(minHeight: node.double("item_extent").map { CGFloat($0) * 5 })
      .background(MaterialPalette.color(node.string("bgcolor")))
      .onChange(of: selection) { value in
        events.commit(node, value: .string(ISO8601DateFormatter().string(from: value)))
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
    .background(MaterialPalette.color(node.string("bgcolor")))
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
    events.commit(node, value: .int(Int64(next)))
  }

  private var pickerLocale: Locale {
    node.string("locale").map { Locale(identifier: $0) } ?? .current
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
    switch node.string("date_picker_mode")?.lowercased() {
    case "time": return [.hourAndMinute]
    case "date": return [.date]
    case "date_and_time", "datetime": return [.date, .hourAndMinute]
    default: return [.date, .hourAndMinute]
    }
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

  var body: some View {
    VStack(spacing: 8) {
      VStack(spacing: 0) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none).padding(12).font(.footnote)
        }
        if let messageID = node.controlID(forKey: "message") {
          ControlView(id: messageID, axis: .none).padding(.horizontal, 12).font(.footnote)
        }
        ForEach(node.controlIDs(forKey: "actions"), id: \.self) { actionID in
          Divider()
          ControlView(id: actionID, axis: .none)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
      }
      .background(sheetSurface, in: RoundedRectangle(cornerRadius: 12))

      if let cancelID = node.controlID(forKey: "cancel") {
        ControlView(id: cancelID, axis: .none)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(sheetSurface, in: RoundedRectangle(cornerRadius: 12))
      }
    }
    .padding(12)
  }

  private var sheetSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.secondarySystemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.controlBackgroundColor)
    #else
      return .white
    #endif
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
