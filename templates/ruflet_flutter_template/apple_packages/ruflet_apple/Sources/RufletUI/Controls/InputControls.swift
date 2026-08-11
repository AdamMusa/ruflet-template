import RufletEngine
import RufletProtocol
import SwiftUI

/// `Switch` — a native `Toggle`.
///
/// The value is written locally the instant the toggle flips, so the control
/// tracks the finger, and a `change` event follows. `Page#dispatch_event`
/// applies the same value to the Ruby control before running the handler, so
/// the two sides agree without a second round trip.
struct SwitchControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    HStack(spacing: 0) {
      if labelPosition == .left { label }
      Toggle("", isOn: binding)
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(MaterialPalette.color(for: node, property: "active_color"))
      if labelPosition == .right { label }
    }
    .modifier(FocusReporter(node: node, events: events))
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
    } else if let value = node.string("label") {
      Text(value).rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_text_style"))
    }
  }

  private var binding: Binding<Bool> {
    Binding(
      get: { node.bool("value") ?? false },
      set: { events.commit(node, value: .bool($0)) })
  }
}

/// `Checkbox` — a tri-state box when `tristate` is set, matching Flutter.
struct CheckboxControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button(action: advance) {
      HStack(spacing: 0) {
        if labelPosition == .left { label }
        checkboxMark
        if labelPosition == .right { label }
      }
    }
    .buttonStyle(.plain)
    .modifier(FocusReporter(node: node, events: events))
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
    } else if let value = node.string("label") {
      Text(value).rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_style"))
    }
  }

  private var checkboxMark: some View {
    let checked = node.bool("value") ?? false
    let fill = checked
      ? MaterialPalette.color(node.string("fill_color"))
        ?? MaterialPalette.color(for: node, property: "active_color", default: .accentColor)
      : Color.clear
    let check = MaterialPalette.color(node.string("check_color"), default: .white)
    let side = node.map("border_side")
    let borderColor = MaterialPalette.color(side?["color"]?.stringValue, default: .secondary)
    let borderWidth = CGFloat(side?["width"]?.doubleValue ?? 1.5)
    return ZStack {
      RoundedRectangle(cornerRadius: 3).fill(fill)
      RoundedRectangle(cornerRadius: 3).strokeBorder(borderColor, lineWidth: borderWidth)
      if checked { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(check) }
      else if node.props["value"]?.isNull == true && node.bool("tristate") == true {
        Image(systemName: "minus").font(.system(size: 12, weight: .bold)).foregroundColor(check)
      }
    }
    .frame(width: 20, height: 20)
  }

  private var symbolName: String {
    guard let value = node.props["value"], !value.isNull else {
      return node.bool("tristate") == true ? "minus.square.fill" : "square"
    }
    return (value.boolValue ?? false) ? "checkmark.square.fill" : "square"
  }

  /// false -> true -> (null when tristate) -> false
  private func advance() {
    let current = node.props["value"]
    let next: RufletValue
    if node.bool("tristate") == true {
      if current == nil || current!.isNull {
        next = .bool(false)
      } else if current!.boolValue == false {
        next = .bool(true)
      } else {
        next = .null
      }
    } else {
      next = .bool(!(current?.boolValue ?? false))
    }
    events.commit(node, value: next)
  }
}

/// `Radio` — one option of a `RadioGroup`.
///
/// The group owns the value: a radio reports `change` on the group control, the
/// way Flet's RadioGroup does, so a group-level Ruby handler fires once.
struct RadioControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button(action: select) {
      HStack(spacing: 0) {
        if labelPosition == .left { label }
        radioMark
        if labelPosition == .right { label }
      }
    }
    .buttonStyle(.plain)
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
    } else if let value = node.string("label") {
      Text(value).rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_style"))
    }
  }

  private var radioMark: some View {
    let fill = MaterialPalette.color(node.string("fill_color"))
      ?? MaterialPalette.color(for: node, property: "active_color", default: .accentColor)
    return ZStack {
      Circle().strokeBorder(isSelected ? fill : Color.secondary, lineWidth: 2)
      if isSelected { Circle().fill(fill).padding(5) }
    }
    .frame(width: 20, height: 20)
  }

  private var group: ControlNode? {
    // Radios sit inside their group's subtree, so the nearest ancestor that is
    // a RadioGroup owns the selection.
    store.nodes.values.first { candidate in
      candidate.type == "RadioGroup" && contains(group: candidate, radio: node.id)
    }
  }

  private func contains(group: ControlNode, radio: Int) -> Bool {
    var frontier = group.childIDs + group.controlIDs(forKey: "content")
    var seen: Set<Int> = []
    while let id = frontier.popLast() {
      guard seen.insert(id).inserted else { continue }
      if id == radio { return true }
      guard let child = store.node(id) else { continue }
      frontier.append(contentsOf: child.childIDs)
      frontier.append(contentsOf: child.controlIDs(forKey: "content"))
    }
    return false
  }

  private var isSelected: Bool {
    guard let value = node.string("value") else { return false }
    return group?.string("value") == value
  }

  private func select() {
    guard let value = node.string("value") else { return }
    if let group {
      if isSelected && node.bool("toggleable") == true {
        events.commit(group, value: .string(""))
      } else {
        events.commit(group, value: .string(value))
      }
    } else {
      events.commit(node, key: "selected", value: .bool(true), event: "change")
    }
  }
}

/// `RadioGroup` — holds the selected value; the radios inside it render.
struct RadioGroupControlView: View {
  let node: ControlNode

  var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .vertical)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }
}

/// `Slider` — a continuous or stepped value.
///
/// Reports `change_start` when the drag begins, `change` while it moves and
/// `change_end` when it settles, which is the trio Flet's Slider emits.
struct SliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let minimum = node.double("min") ?? 0
    let maximum = node.double("max") ?? 1
    let range = minimum...max(maximum, minimum + .ulpOfOne)

    Group {
      if let divisions = node.int("divisions"), divisions > 0 {
        Slider(
          value: binding, in: range,
          step: (range.upperBound - range.lowerBound) / Double(divisions),
          onEditingChanged: reportEditing)
      } else {
        Slider(value: binding, in: range, onEditingChanged: reportEditing)
      }
    }
    .tint(MaterialPalette.color(for: node, property: "active_color"))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(node.bool("disabled") ?? false)
  }

  private var binding: Binding<Double> {
    Binding(
      get: { node.double("value") ?? (node.double("min") ?? 0) },
      set: { events.commit(node, value: .double($0)) })
  }

  private func reportEditing(_ editing: Bool) {
    let value = RufletValue.double(node.double("value") ?? 0)
    events.fire(node, editing ? "change_start" : "change_end", data: value)
  }
}

/// `RangeSlider` — two thumbs over one track.
///
/// SwiftUI has no range slider, so this is built from two overlaid sliders that
/// clamp against each other, keeping `start_value` below `end_value`.
struct RangeSliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let minimum = node.double("min") ?? 0
    let maximum = node.double("max") ?? 1
    let values = RufletThemeDefaults.rangeSliderValues(node)
    let start = values.start
    let end = values.end

    RufletRangeSlider(
      start: start,
      end: end,
      minimum: minimum,
      maximum: maximum,
      divisions: node.int("divisions"),
      activeColor: MaterialPalette.color(for: node, property: "active_color", default: .accentColor),
      inactiveColor: MaterialPalette.color(node.string("inactive_color"), default: .secondary.opacity(0.25)),
      onChange: commit,
      onEditingChanged: { editing in events.fire(node, editing ? "change_start" : "change_end") })
    .disabled(node.bool("disabled") ?? false)
  }

  /// `Page#apply_event_value_to_control` looks for a `start_value`/`end_value`
  /// pair in the event data and writes both back, so send them together.
  private func commit(start: Double, end: Double) {
    events.setLocal(node.id, "start_value", .double(start))
    events.setLocal(node.id, "end_value", .double(end))
    guard node.handlesEvent("change") else { return }
    events.send(
      node.id, "change",
      .map(["start_value": .double(start), "end_value": .double(end)]))
  }
}

private struct RufletRangeSlider: View {
  let start: Double
  let end: Double
  let minimum: Double
  let maximum: Double
  let divisions: Int?
  let activeColor: Color
  let inactiveColor: Color
  let onChange: (Double, Double) -> Void
  let onEditingChanged: (Bool) -> Void

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width - 24, 1)
      let startX = 12 + width * fraction(start)
      let endX = 12 + width * fraction(end)
      ZStack(alignment: .leading) {
        Capsule().fill(inactiveColor).frame(height: 4).padding(.horizontal, 12)
        Capsule().fill(activeColor).frame(width: max(endX - startX, 0), height: 4).offset(x: startX)
        thumb(at: startX) { proposed in onChange(min(snapped(proposed, width: width), end), end) }
        thumb(at: endX) { proposed in onChange(start, max(snapped(proposed, width: width), start)) }
      }
    }
    .frame(minHeight: 44)
  }

  private func thumb(at x: CGFloat, changed: @escaping (Double) -> Void) -> some View {
    Circle()
      .fill(activeColor)
      .frame(width: 20, height: 20)
      .shadow(radius: 1)
      .offset(x: x - 10)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            onEditingChanged(true)
            changed(minimum + Double(max(0, value.location.x - 12)) * span / Double(max(1, value.startLocation.x + 1)))
          }
          .onEnded { _ in onEditingChanged(false) })
  }

  private var span: Double { max(maximum - minimum, .ulpOfOne) }
  private func fraction(_ value: Double) -> CGFloat { CGFloat((value - minimum) / span) }
  private func snapped(_ x: Double, width: CGFloat) -> Double {
    let raw = minimum + min(max(x / Double(width), 0), 1) * span
    guard let divisions, divisions > 0 else { return raw }
    let step = span / Double(divisions)
    return minimum + ((raw - minimum) / step).rounded() * step
  }
}

/// `TextField` — the Material text input.
///
/// `on_change` fires per keystroke and `on_submit` on return, which is what
/// Flet's TextField reports. `password` picks a `SecureField`, and
/// `multiline`/`min_lines` a `TextEditor`.
struct TextFieldControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var hovering = false
  @State private var selection = NSRange(location: 0, length: 0)

  var body: some View {
    HStack(alignment: verticalAlignment, spacing: 8) {
      RufletFormFieldSlot(node: node, key: "prefix_icon")
        .modifier(SlotSizeConstraints(value: node.props["prefix_icon_size_constraints"]))
      RufletFormFieldSlot(node: node, key: "prefix", styleKey: "prefix_style")
      field
      RufletFormFieldSlot(node: node, key: "suffix", styleKey: "suffix_style")
      RufletFormFieldSlot(node: node, key: "suffix_icon")
        .modifier(SlotSizeConstraints(value: node.props["suffix_icon_size_constraints"]))
    }
    .textFieldStyle(.plain)
    .padding(contentPadding)
    .frame(maxWidth: fitsParent ? .infinity : nil, maxHeight: fitsParent ? .infinity : nil)
    .background(
      RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 8)
        .fill(fieldBackground))
    .overlay(borderStroke)
    // Flutter clips a decorated field to its border; hardEdge is the default.
    .modifier(
      ChromeClipModifier(behavior: node.string("clip_behavior") ?? "hardEdge"))
    .modifier(FieldHoverTracker(hovering: $hovering))
    .modifier(RufletFormFieldDecoration(node: node))
    .onAppear {
      focused = node.bool("autofocus") == true
      selection = explicitSelection
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .onChange(of: selection) { reportSelection($0) }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus": focused = true; completion(.success(.null))
      case "blur": focused = false; completion(.success(.null))
      default: completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
  }

  /// `shift_enter` implies multiline, the way Flet's textfield.dart reads it,
  /// and a min_lines above one does too.
  private var isMultiline: Bool {
    node.bool("multiline") == true || node.bool("shift_enter") == true
      || (node.int("min_lines") ?? 1) > 1
  }

  /// Flutter defaults max_lines to one for a single-line field and leaves a
  /// multiline one unbounded.
  private var maxLines: Int? {
    node.int("max_lines") ?? (isMultiline ? nil : 1)
  }

  @ViewBuilder
  private var field: some View {
    // A Material label rests inside an empty field and floats only while
    // editing. Native TextField's prompt is the closest Apple equivalent and
    // keeps fixed-height fields from clipping a separate label row.
    let prompt = node.string("hint_text") ?? node.string("label") ?? ""
    if isMultiline {
      TextEditor(text: binding)
        .rufletTextStyle(fieldTextStyle)
        .lineLimit(maxLines)
        .frame(minHeight: CGFloat((node.int("min_lines") ?? 3) * 20))
        // Flutter scrolls a multiline field with this padding held clear of
        // the caret; the inset is the closest equivalent.
        .modifier(ScrollInset(insets: scrollPadding))
    } else {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          placeholder: prompt,
          secure: node.bool("password") == true,
          traits: traits,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(PlaceholderStyle(node: node, showing: binding.wrappedValue.isEmpty))
      #else
        TextField(prompt, text: binding)
          .onSubmit { events.fire(node, "submit", data: .string(binding.wrappedValue)) }
          .modifier(KeyboardType(node: node))
      #endif
    }
  }

  /// Flet layers the field's text style: `text_style` first, then `text_size`,
  /// then `focused_color` while focused and `color` otherwise.
  private var fieldTextStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "text_style")
    if let size = node.double("text_size") { style.size = CGFloat(size) }
    let resting = MaterialPalette.color(node.string("color"))
    let active = MaterialPalette.color(node.string("focused_color"))
    if let color = focused ? (active ?? resting) : resting { style.color = color }
    return style
  }

  private var traits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    // The field's own style wins over the traits' colour and size, so the two
    // cannot disagree about which one painted the text.
    traits.textColor = fieldTextStyle.color
    traits.fontSize = fieldTextStyle.size
    return traits
  }

  private var scrollPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["scroll_padding"])
      ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
  }

  private var fitsParent: Bool { node.bool("fit_parent_size") == true }

  /// `text_vertical_align` runs -1 (top) to 1 (bottom) the way Flutter's
  /// alignment axes do.
  private var verticalAlignment: VerticalAlignment {
    switch node.double("text_vertical_align") {
    case .some(let value) where value <= -0.5: return .top
    case .some(let value) where value >= 0.5: return .bottom
    default: return .center
    }
  }

  /// `dense` and `collapsed` are Material's two tighter insets; anything else
  /// takes `content_padding` when Ruby supplies it.
  private var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if node.bool("collapsed") == true { return EdgeInsets() }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  private var hasError: Bool {
    node.controlID(forKey: "error") != nil || !(node.string("error") ?? "").isEmpty
  }

  @ViewBuilder
  private var borderStroke: some View {
    let radius = ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(borderColor, lineWidth: borderWidth)
    }
  }

  private var borderWidth: CGFloat {
    let resting = node.double("border_width") ?? 1
    guard focused else { return CGFloat(resting) }
    return CGFloat(node.double("focused_border_width") ?? resting)
  }

  private var borderColor: Color {
    if hasError {
      return MaterialPalette.color(for: node, property: "error_border_color", default: .red)
    }
    if focused,
      let focusedColor = MaterialPalette.color(
        node.string("focused_border_color") ?? node.string("focus_color"))
    {
      return focusedColor
    }
    return MaterialPalette.color(for: node, property: "border_color", default: .clear)
  }

  /// Material resolves a field's fill from its interaction state, so the
  /// focused, hovered and resting colours are tried in that order.
  private var fieldBackground: Color {
    if focused, let focusedFill = MaterialPalette.color(node.string("focused_bgcolor")) {
      return focusedFill
    }
    if hovering, let hover = MaterialPalette.color(node.string("hover_color")) {
      return hover
    }
    if let explicit = MaterialPalette.color(node.props["bgcolor"]?.stringValue) {
      return explicit
    }
    if node.bool("filled") == true, let fill = MaterialPalette.color(node.string("fill_color")) {
      return fill
    }
    return MaterialPalette.color(RufletThemeDefaults.backgroundToken(for: node)) ?? .clear
  }

  private var binding: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }

  private var explicitSelection: NSRange { RufletTextSelection.explicit(on: node) }

  private func reportSelection(_ range: NSRange) {
    RufletTextSelection.report(range, on: node, to: events)
  }
}

/// `CodeEditor` — a native, monospaced multiline editor.
///
/// The Flutter extension uses a themed editor widget; on Apple the same wire
/// contract maps to `TextEditor`, including live value changes, read-only
/// previews, focus/blur events and the imperative `focus` command.
struct CodeEditorControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @FocusState private var focused: Bool
  @State private var nativeFocused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var folds: [CodeFoldRegion] = []

  var body: some View {
    #if canImport(UIKit) || canImport(AppKit)
      HighlightedCodeTextView(
        text: editorValue,
        focused: $nativeFocused,
        selection: $selection,
        editable: node.bool("read_only") != true && folds.isEmpty,
        dark: isDark,
        fontSize: CGFloat(node.double("text_size") ?? 14))
      .onChange(of: nativeFocused) { isFocused in
        events.fire(node, isFocused ? "focus" : "blur")
      }
      .onChange(of: selection) { range in
        reportSelection(range)
      }
      .modifier(CodeEditorChrome(node: node, dark: isDark))
      .onAppear {
        selection = explicitSelection
        if node.bool("autofocus") == true, node.bool("read_only") != true {
          nativeFocused = true
        }
      }
      .rufletCommandHandler(node.id) { call, completion in
        switch call.name {
        case "focus":
          if node.bool("read_only") != true { nativeFocused = true }
          completion(.success(.null))
        case "blur":
          nativeFocused = false
          completion(.success(.null))
        case "fold_at":
          toggleFold(at: call.argument("line_number")?.intValue ?? 0)
          completion(.success(.null))
        case "fold_comment_at_line_zero":
          folds = CodeFoldProjection.leadingCommentRegion(in: source).map { [$0] } ?? []
          completion(.success(.null))
        case "fold_imports":
          folds = CodeFoldProjection.importRegions(in: source)
          completion(.success(.null))
        default:
          completion(.failure(rufletUnsupported("CodeEditor", call)))
        }
      }
    #else
    Group {
      if node.bool("read_only") == true {
        ScrollView([.horizontal, .vertical]) {
          Text(node.string("value") ?? "")
            .font(editorFont)
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
        }
      } else {
        TextEditor(text: value)
          .font(editorFont)
          .foregroundColor(foreground)
          .focused($focused)
          .padding(8)
          .colorScheme(isDark ? .dark : .light)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(background)
    .onAppear {
      if node.bool("autofocus") == true, node.bool("read_only") != true {
        focused = true
      }
    }
    .onChange(of: focused) { isFocused in
      events.fire(node, isFocused ? "focus" : "blur")
    }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus":
        if node.bool("read_only") != true { focused = true }
        completion(.success(.null))
      case "blur":
        focused = false
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("CodeEditor", call)))
      }
    }
    #endif
  }

  private var value: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }

  private var source: String { node.string("value") ?? "" }

  private var editorValue: Binding<String> {
    Binding(
      get: { CodeFoldProjection.project(source, folding: folds) },
      set: { newValue in
        guard folds.isEmpty else { return }
        events.commit(node, value: .string(newValue))
      })
  }

  private var explicitSelection: NSRange {
    guard let map = node.map("selection"),
      let base = map["base_offset"]?.intValue,
      let extent = map["extent_offset"]?.intValue
    else { return NSRange(location: 0, length: 0) }
    let start = max(0, min(base, extent))
    let end = min(source.utf16.count, max(base, extent))
    return NSRange(location: min(start, end), length: max(0, end - start))
  }

  private func reportSelection(_ range: NSRange) {
    guard folds.isEmpty else { return }
    let length = source.utf16.count
    let location = min(max(range.location, 0), length)
    let selectedLength = min(max(range.length, 0), length - location)
    let resolved = NSRange(location: location, length: selectedLength)
    let selectionValue: RufletValue = .map([
      "base_offset": .int(Int64(resolved.location)),
      "extent_offset": .int(Int64(NSMaxRange(resolved))),
      "affinity": .string("downstream"),
      "directional": .bool(false),
    ])
    events.setLocal(node.id, "selection", selectionValue)
    events.update(node.id, ["selection": selectionValue])
    let selected = (source as NSString).substring(with: resolved)
    events.fire(node, "selection_change", data: .map([
      "selected_text": .string(selected),
      "selection": selectionValue,
    ]))
  }

  private func toggleFold(at line: Int) {
    if let index = folds.firstIndex(where: { $0.startLine == line }) {
      folds.remove(at: index)
      return
    }
    if let region = CodeFoldProjection.blockRegion(in: source, startingAt: line) {
      folds.append(region)
    }
  }

  private var editorFont: Font {
    .system(size: CGFloat(node.double("text_size") ?? 14), design: .monospaced)
  }

  private var isDark: Bool {
    (node.string("code_theme") ?? "").lowercased().contains("dark")
  }

  private var background: Color {
    MaterialPalette.color(node.string("bgcolor"), default: isDark ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white)
  }

  private var foreground: Color {
    MaterialPalette.color(node.string("color"), default: isDark ? Color(red: 0.67, green: 0.70, blue: 0.75) : .primary)
  }
}

struct CodeFoldRegion: Equatable {
  let startLine: Int
  let endLine: Int
}

/// A source-preserving projection for the imperative folding API exposed by
/// Flet's CodeEditor. While a projection is folded it is read-only; invoking
/// `fold_at` for the same line expands it without ever replacing the DSL value.
enum CodeFoldProjection {
  static func project(_ source: String, folding regions: [CodeFoldRegion]) -> String {
    guard !regions.isEmpty else { return source }
    let lines = source.components(separatedBy: "\n")
    let byStart = Dictionary(uniqueKeysWithValues: regions.map { ($0.startLine, $0) })
    var output: [String] = []
    var line = 0
    while line < lines.count {
      if let region = byStart[line], region.endLine > line {
        output.append(lines[line] + "  …")
        line = min(region.endLine + 1, lines.count)
      } else {
        output.append(lines[line])
        line += 1
      }
    }
    return output.joined(separator: "\n")
  }

  static func blockRegion(in source: String, startingAt line: Int) -> CodeFoldRegion? {
    let lines = source.components(separatedBy: "\n")
    guard lines.indices.contains(line), line + 1 < lines.count else { return nil }
    let startIndent = indentation(lines[line])
    var end = line
    for index in (line + 1)..<lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { end = index; continue }
      if indentation(lines[index]) <= startIndent {
        if trimmed == "end" || trimmed.hasPrefix("}") { end = index }
        break
      }
      end = index
    }
    return end > line ? CodeFoldRegion(startLine: line, endLine: end) : nil
  }

  static func leadingCommentRegion(in source: String) -> CodeFoldRegion? {
    let lines = source.components(separatedBy: "\n")
    var end = -1
    for (index, line) in lines.enumerated() {
      let value = line.trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("#") || value.hasPrefix("//") || value.hasPrefix("/*") || value.hasPrefix("*") {
        end = index
      } else if !value.isEmpty {
        break
      }
    }
    return end > 0 ? CodeFoldRegion(startLine: 0, endLine: end) : nil
  }

  static func importRegions(in source: String) -> [CodeFoldRegion] {
    let lines = source.components(separatedBy: "\n")
    let prefixes = ["import ", "from ", "require ", "require(", "use ", "using "]
    var regions: [CodeFoldRegion] = []
    var start: Int?
    for index in 0...lines.count {
      let isImport = index < lines.count && prefixes.contains {
        lines[index].trimmingCharacters(in: .whitespaces).hasPrefix($0)
      }
      if isImport, start == nil { start = index }
      if !isImport, let first = start {
        if index - 1 > first { regions.append(CodeFoldRegion(startLine: first, endLine: index - 1)) }
        start = nil
      }
    }
    return regions
  }

  private static func indentation(_ line: String) -> Int {
    line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { result, character in
      result + (character == "\t" ? 2 : 1)
    }
  }
}

private struct CodeEditorChrome: ViewModifier {
  let node: ControlNode
  let dark: Bool

  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(
        MaterialPalette.color(
          node.string("bgcolor"),
          default: dark ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white))
  }
}

/// Flet's `KeyboardType`, where the platform has an equivalent.
/// Tracks the pointer so a field can paint its `hover_color`.
private struct FieldHoverTracker: ViewModifier {
  @Binding var hovering: Bool

  func body(content: Content) -> some View {
    content.onHover { hovering = $0 }
  }
}

/// `prefix_icon_size_constraints` and its suffix twin are Flutter
/// `BoxConstraints` on the slot rather than on the field.
private struct SlotSizeConstraints: ViewModifier {
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

/// `scroll_padding` is the margin Flutter keeps between the caret and the
/// edge while a multiline field scrolls.
private struct ScrollInset: ViewModifier {
  let insets: EdgeInsets

  func body(content: Content) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      content.contentMargins(.all, insets, for: .scrollContent)
    } else {
      content.padding(insets)
    }
  }
}

/// `hint_style`, `hint_max_lines` and `hint_fade_duration` describe the
/// placeholder, which neither platform field styles directly, so it is drawn
/// over an empty field.
private struct PlaceholderStyle: ViewModifier {
  let node: ControlNode
  let showing: Bool

  func body(content: Content) -> some View {
    guard let hint = node.string("hint_text"), !hint.isEmpty,
      node.map("hint_style") != nil || node.int("hint_max_lines") != nil
    else { return AnyView(content) }
    let duration = (node.double("hint_fade_duration") ?? 0) / 1_000
    return AnyView(
      content.overlay(alignment: .leading) {
        Text(hint)
          .lineLimit(node.int("hint_max_lines"))
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "hint_style"))
          .opacity(showing ? 1 : 0)
          .animation(.easeInOut(duration: duration), value: showing)
          .allowsHitTesting(false)
      })
  }
}

/// Flutter lists dropdown options in the order they were given, but SwiftUI
/// reverses a menu that opens upwards. `menuOrder` pins it, and arrived in
/// iOS 16 against a package that ships to iOS 15.
private struct FixedMenuOrder: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 16.0, macOS 13.0, *) {
      content.menuOrder(.fixed)
    } else {
      content
    }
  }
}

private struct KeyboardType: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    #if os(iOS)
      switch node.string("keyboard_type")?.lowercased() {
      case "number": return AnyView(content.keyboardType(.numberPad))
      case "phone": return AnyView(content.keyboardType(.phonePad))
      case "email": return AnyView(content.keyboardType(.emailAddress))
      case "url": return AnyView(content.keyboardType(.URL))
      case "datetime": return AnyView(content.keyboardType(.numbersAndPunctuation))
      default: return AnyView(content)
      }
    #else
      return AnyView(content)
    #endif
  }
}

/// `SearchBar` — a text field that reports `change`, `submit` and `tap`, and
/// answers Ruby's `focus`, `open_view` and `close_view`.
struct SearchBarControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @FocusState private var focused: Bool
  @State private var nativeFocused = false
  @State private var selection = NSRange(location: 0, length: 0)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      bar
      // Flet's SearchView is the sheet the bar opens onto: its own header,
      // padding and surface, with the suggestion controls beneath a divider.
      if nativeFocused, !node.controlIDs(forKey: "controls").isEmpty {
        Divider().background(MaterialPalette.color(node.string("divider_color")))
        suggestions
      }
    }
    .frame(maxWidth: node.bool("full_screen") == true ? .infinity : nil)
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus", "open_view":
        focused = true
        nativeFocused = true
        completion(.success(.null))
      case "close_view":
        focused = false
        nativeFocused = false
        // Flet's close_view also sets the bar's text to the value it carries.
        if let value = call.argument("text")?.stringValue {
          events.setLocal(node.id, "value", .string(value))
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("SearchBar", call)))
      }
    }
  }

  /// The suggestion sheet. `shrink_wrap` sizes it to its content rather than
  /// letting it fill, and `view_header_height` fixes the header row.
  private var suggestions: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let header = node.string("view_hint_text") {
        Text(header)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "view_header_text_style"))
          .frame(height: node.double("view_header_height").map { CGFloat($0) })
          .padding(ControlProps.edgeInsets(node.props["view_bar_padding"]) ?? EdgeInsets())
      }
      ControlList(ids: node.controlIDs(forKey: "controls"), axis: .vertical)
    }
    .padding(ControlProps.edgeInsets(node.props["view_padding"]) ?? EdgeInsets())
    .frame(maxWidth: node.bool("shrink_wrap") == true ? nil : .infinity, alignment: .leading)
    .modifier(SlotSizeConstraints(value: node.props["view_size_constraints"]))
    .background(
      RoundedRectangle(cornerRadius: shapeRadius(node.props["view_shape"]))
        .fill(MaterialPalette.color(node.string("view_bgcolor"), default: .clear)))
    .overlay(
      RoundedRectangle(cornerRadius: shapeRadius(node.props["view_shape"]))
        .strokeBorder(
          MaterialPalette.color(node.map("view_side")?["color"]?.stringValue, default: .clear),
          lineWidth: CGFloat(node.map("view_side")?["width"]?.doubleValue ?? 0)))
    .shadow(radius: CGFloat(node.double("view_elevation") ?? 0))
  }

  private func shapeRadius(_ value: RufletValue?) -> CGFloat {
    ControlProps.cornerRadius(value?.mapValue?["radius"]) ?? 0
  }

  private var bar: some View {
    HStack(spacing: 8) {
      if let leading = node.controlID(forKey: "bar_leading") {
        ControlView(id: leading, axis: .none)
      } else if let viewLeading = node.controlID(forKey: "view_leading") {
        ControlView(id: viewLeading, axis: .none)
      } else {
        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
      }
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: searchValue,
          focused: $nativeFocused,
          selection: $selection,
          placeholder: node.string("bar_hint_text") ?? node.string("view_hint_text") ?? "",
          secure: false,
          traits: barTraits,
          onTap: { events.fire(node, "tap") },
          onTapOutside: { events.fire(node, "tap_outside_bar") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(SearchBarHint(node: node, showing: (node.string("value") ?? "").isEmpty))
      #else
        TextField(
          node.string("bar_hint_text") ?? node.string("view_hint_text") ?? "",
          text: searchValue)
        .textFieldStyle(.plain)
        .focused($focused)
        .onSubmit { events.fire(node, "submit", data: .string(node.string("value") ?? "")) }
      #endif

      if !(node.string("value") ?? "").isEmpty {
        Button {
          events.commit(node, value: .string(""))
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      if let trailing = node.controlIDs(forKey: "bar_trailing").first
        ?? node.controlIDs(forKey: "view_trailing").first
      {
        ControlView(id: trailing, axis: .none)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["bar_padding"])
      ?? EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
    // The bar keeps this margin clear of the caret while its text scrolls.
    .padding(ControlProps.edgeInsets(node.props["bar_scroll_padding"]) ?? EdgeInsets())
    .modifier(SlotSizeConstraints(value: node.props["bar_size_constraints"]))
    .background(
      RoundedRectangle(cornerRadius: barRadius)
        .fill(MaterialPalette.color(node.string("bar_bgcolor"), default: .gray.opacity(0.14))))
    .overlay(
      RoundedRectangle(cornerRadius: barRadius)
        .strokeBorder(
          MaterialPalette.color(
            node.map("bar_border_side")?["color"]?.stringValue, default: .clear),
          lineWidth: CGFloat(node.map("bar_border_side")?["width"]?.doubleValue ?? 0)))
    .shadow(
      color: MaterialPalette.color(node.string("bar_shadow_color"), default: .black.opacity(0.2)),
      radius: CGFloat(node.double("bar_elevation") ?? 0))
    .onAppear { nativeFocused = node.bool("autofocus") == true }
    .onChange(of: nativeFocused) { events.fire(node, $0 ? "focus" : "blur") }
  }

  /// `bar_shape` is an OutlinedBorder; a search bar is a capsule by default,
  /// so an absent radius takes half the bar's height.
  private var barRadius: CGFloat {
    ControlProps.cornerRadius(node.map("bar_shape")?["radius"]) ?? 22
  }

  /// The bar's own text styling, plus the scroll padding Flet names for it.
  private var barTraits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    let style = RufletTextStyle(node: node, styleKey: "bar_text_style")
    traits.textColor = style.color
    traits.fontSize = style.size
    if let overlay = MaterialPalette.color(node.string("bar_overlay_color")) {
      traits.selectionColor = overlay
    }
    return traits
  }

  private var searchValue: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }
}

/// `bar_hint_text_style` and `view_hint_text_style` style the placeholder,
/// which neither platform field does directly.
private struct SearchBarHint: ViewModifier {
  let node: ControlNode
  let showing: Bool

  func body(content: Content) -> some View {
    guard node.map("bar_hint_text_style") != nil || node.map("view_hint_text_style") != nil
    else { return AnyView(content) }
    let key = node.map("bar_hint_text_style") != nil
      ? "bar_hint_text_style" : "view_hint_text_style"
    let text = node.string("bar_hint_text") ?? node.string("view_hint_text") ?? ""
    return AnyView(
      content.overlay(alignment: .leading) {
        Text(text)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: key))
          .opacity(showing ? 1 : 0)
          .allowsHitTesting(false)
      })
  }
}

/// `Dropdown` / `DropdownM2` — a native `Picker` over the control's options.
struct DropdownControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var selection = NSRange(location: 0, length: 0)

  var body: some View {
    let options = optionNodes

    HStack(spacing: 8) {
      RufletFormFieldSlot(node: node, key: "leading_icon")
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: dropdownText,
          focused: $focused,
          selection: $selection,
          placeholder: node.string("hint_text") ?? "",
          secure: false,
          traits: RufletTextInputTraits(node: node),
          onTap: { events.fire(node, "click") },
          onTapOutside: {},
          onSubmit: { _ in })
      #else
        TextField(node.string("hint_text") ?? "", text: dropdownText)
      #endif
      RufletFormFieldSlot(node: node, key: "selected_suffix", styleKey: "text_style")
      Menu {
        ForEach(options, id: \.id) { option in
          Button {
            select(option)
          } label: {
            optionLabel(option)
          }
        }
      } label: {
        trailingIcon
      }
      .modifier(FixedMenuOrder())
      .frame(maxHeight: node.double("menu_height").map { CGFloat($0) })
    }
    .padding(contentPadding)
    .background(RoundedRectangle(cornerRadius: 8).fill(fieldBackground))
    .overlay(borderStroke)
    .frame(width: node.double("menu_width").map { CGFloat($0) })
    .modifier(RufletFormFieldDecoration(node: node))
    .onAppear {
      focused = node.bool("autofocus") == true
      if node.string("text") == nil, let value = node.string("value") {
        events.setLocal(node.id, "text", .string(label(for: value)))
      }
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "focus" else {
        completion(.failure(rufletUnsupported(node.type, call))); return
      }
      focused = true
      completion(.success(.null))
    }
  }

  /// Flet shows `selected_trailing_icon` while the menu is open and
  /// `trailing_icon` while it is closed; SwiftUI's Menu does not report that
  /// state, so the selected form stands in once a value exists.
  @ViewBuilder
  private var trailingIcon: some View {
    let key = node.string("value") == nil ? "trailing_icon" : "selected_trailing_icon"
    if let id = node.controlID(forKey: key) ?? node.controlID(forKey: "trailing_icon") {
      ControlView(id: id, axis: .none)
    } else {
      Image(systemName: "chevron.down").foregroundColor(.secondary)
    }
  }

  private var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  private var fieldBackground: Color {
    MaterialPalette.color(node.string("fill_color"), default: .gray.opacity(0.10))
  }

  @ViewBuilder
  private var borderStroke: some View {
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(
          MaterialPalette.color(
            node.string(focused ? "focused_border_color" : "border_color"), default: .clear),
          lineWidth: CGFloat(
            node.double(focused ? "focused_border_width" : "border_width") ?? 1))
    }
  }

  private var dropdownText: Binding<String> {
    Binding(
      get: { node.string("text") ?? label(for: node.string("value") ?? "") },
      set: {
        events.setLocal(node.id, "text", .string($0))
        events.update(node.id, ["text": .string($0)])
        events.fire(node, "text_change", data: .string($0))
      })
  }

  private func select(_ option: ControlNode) {
    let key = option.string("key") ?? option.string("text") ?? ""
    let text = option.string("text") ?? key
    events.setLocal(node.id, "value", .string(key))
    events.setLocal(node.id, "text", .string(text))
    events.update(node.id, ["value": .string(key), "text": .string(text)])
    events.fire(node, "select", data: .string(key))
  }

  private func label(for key: String) -> String {
    optionNodes.first(where: { ($0.string("key") ?? $0.string("text") ?? "") == key })?
      .string("text") ?? key
  }

  /// Options arrive under `options` on a Dropdown and `controls` on the M2
  /// variant, so both are accepted.
  private var optionNodes: [ControlNode] {
    let ids = node.controlIDs(forKey: "options") + node.childIDs
    return ids.compactMap { store.node($0) }
  }

  @ViewBuilder
  private func optionLabel(_ option: ControlNode) -> some View {
    if let contentID = option.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      Text(option.string("text") ?? option.string("key") ?? "")
    }
  }
}

/// The legacy Material 2 dropdown is intentionally separate from the modern
/// editable DropdownMenu. Flet builds it with `DropdownButtonFormField`: the
/// field itself reports `click`, selecting an option reports `change`, and an
/// option can independently report its own `click` event.
struct DropdownM2ControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Menu {
      ForEach(optionNodes, id: \.id) { option in
        Button {
          select(option)
        } label: {
          optionLabel(option)
        }
        .disabled(option.bool("disabled") ?? false)
      }
    } label: {
      HStack(spacing: 8) {
        RufletFormFieldSlot(node: node, key: "icon")
        RufletFormFieldSlot(node: node, key: "prefix_icon")
        RufletFormFieldSlot(node: node, key: "prefix", styleKey: "prefix_style")
        selectedLabel
        Spacer(minLength: 8)
        RufletFormFieldSlot(node: node, key: "suffix", styleKey: "suffix_style")
        RufletFormFieldSlot(node: node, key: "suffix_icon")
        selectIcon
      }
      .contentShape(Rectangle())
      .padding(contentPadding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius).fill(fieldBackground))
      .overlay(borderStroke)
    }
    .modifier(FixedMenuOrder())
    .simultaneousGesture(TapGesture().onEnded { events.fire(node, "click") })
    .modifier(FocusReporter(node: node, events: events))
    .modifier(RufletFormFieldDecoration(node: node))
    .disabled(node.bool("disabled") ?? false)
  }

  @ViewBuilder
  private var selectIcon: some View {
    let disabled = node.bool("disabled") == true
    if let iconID = node.controlID(forKey: "select_icon") {
      ControlView(id: iconID, axis: .none)
    } else {
      Image(systemName: "chevron.down")
        .font(.system(size: CGFloat(node.double("select_icon_size") ?? 13)))
        .foregroundColor(
          MaterialPalette.color(
            node.string(disabled ? "select_icon_disabled_color" : "select_icon_enabled_color"),
            default: disabled ? .secondary : .primary))
    }
  }

  private var hintStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "hint_style")
    if style.color == nil { style.color = .secondary }
    return style
  }

  private var cornerRadius: CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
  }

  private var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if node.bool("collapsed") == true { return EdgeInsets() }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  private var fieldBackground: Color {
    if let focused = MaterialPalette.color(node.string("focused_bgcolor")) { return focused }
    if node.bool("filled") == true {
      return MaterialPalette.color(node.string("fill_color"), default: .gray.opacity(0.12))
    }
    return MaterialPalette.color(node.string("fill_color"), default: .clear)
  }

  @ViewBuilder
  private var borderStroke: some View {
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
          MaterialPalette.color(node.string("border_color"), default: .secondary.opacity(0.4)),
          lineWidth: CGFloat(node.double("border_width") ?? 1))
    }
  }

  private func select(_ option: ControlNode) {
    let value = option.string("key") ?? option.string("text") ?? String(option.id)
    events.setLocal(node.id, "value", .string(value))
    events.update(node.id, ["value": .string(value)])
    events.fire(option, "click")
    events.fire(node, "change", data: .string(value))
  }

  private var optionNodes: [ControlNode] {
    let ids = node.controlIDs(forKey: "options") + node.childIDs
    var seen = Set<Int>()
    return ids.filter { seen.insert($0).inserted }.compactMap { store.node($0) }
  }

  @ViewBuilder
  private var selectedLabel: some View {
    if let value = node.string("value"),
      let option = optionNodes.first(where: {
        ($0.string("key") ?? $0.string("text") ?? String($0.id)) == value
      })
    {
      optionLabel(option)
    } else if let hintID = node.controlID(
      forKey: node.bool("disabled") == true ? "disabled_hint_content" : "hint_content")
    {
      ControlView(id: hintID, axis: .none)
    } else {
      Text(node.string("hint_text") ?? "")
        .lineLimit(node.int("hint_max_lines"))
        .rufletTextStyle(hintStyle)
    }
  }

  @ViewBuilder
  private func optionLabel(_ option: ControlNode) -> some View {
    if let contentID = option.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      Text(option.string("text") ?? option.string("key") ?? String(option.id))
    }
  }
}

/// `AutoComplete` — a field with a filtered suggestion list underneath.
struct AutoCompleteControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var query = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TextField(node.string("hint_text") ?? "", text: $query)
        .textFieldStyle(.plain)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
        .onChange(of: query) { value in
          events.commit(node, value: .string(value))
        }

      if !query.isEmpty {
        ForEach(matches, id: \.id) { suggestion in
          Button {
            let key = suggestion.string("key") ?? suggestion.string("value") ?? ""
            let value = suggestion.string("value") ?? suggestion.string("key") ?? ""
            query = key
            let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) ?? 0
            events.setLocal(node.id, "_selected_index", .int(Int64(index)))
            events.update(node.id, ["_selected_index": .int(Int64(index))])
            events.fire(node, "select", data: .map([
              "index": .int(Int64(index)),
              "selection": .map(["key": .string(key), "value": .string(value)]),
            ]))
          } label: {
            Text(suggestion.string("value") ?? "")
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 6)
              .padding(.horizontal, 8)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .onAppear { query = node.string("value") ?? "" }
  }

  private var suggestions: [ControlNode] {
    node.controlIDs(forKey: "suggestions").compactMap { store.node($0) }
  }

  private var matches: [ControlNode] {
    suggestions
      .filter {
        ($0.string("key") ?? $0.string("value") ?? "")
          .localizedCaseInsensitiveContains(query)
      }
      .prefix(node.int("suggestions_max_height").map { _ in 8 } ?? 8)
      .map { $0 }
  }
}

/// `DatePicker`, `TimePicker` and `DateRangePicker`.
///
/// Ruflet drives these by flipping `open`; the native pickers are presented in
/// a sheet so the control reads the same from Ruby.
struct DateTimePickerControlView: View {
  enum Kind { case date, time, dateRange }

  let node: ControlNode
  let kind: Kind
  @Environment(\.rufletEvents) private var events
  @State private var selection = Date()
  @State private var rangeStart = Date()
  @State private var rangeEnd = Date()
  @State private var entryMode = ""

  var body: some View {
    picker
      .padding(20)
      .frame(maxWidth: 420)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(MaterialPalette.color(node.string("bgcolor"), default: pickerSurface)))
      .shadow(radius: 20)
      .padding(24)
  }

  private var isOpen: Binding<Bool> {
    Binding(
      get: { node.bool("open") ?? false },
      set: { open in
        events.setLocal(node.id, "open", .bool(open))
        if !open {
          events.update(node.id, ["open": .bool(false)])
          events.fire(node, "dismiss")
        }
      })
  }

  @ViewBuilder
  private var picker: some View {
    VStack(spacing: 16) {
      if let help = node.string("help_text"), !help.isEmpty {
        Text(help).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
      }

      switch kind {
      case .date:
        if entryMode == "input" {
          DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
            .datePickerStyle(.compact)
            .labelsHidden()
        } else {
          DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
      case .time:
        #if os(iOS)
        if entryMode == "input" {
          DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
            .datePickerStyle(.compact)
            .labelsHidden()
        } else {
          DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
            .datePickerStyle(.wheel)
            .labelsHidden()
        }
        #else
        DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
          .datePickerStyle(.field)
          .labelsHidden()
        #endif
      case .dateRange:
        VStack(spacing: 14) {
          DatePicker(
            node.string("field_start_label_text") ?? "Start date",
            selection: $rangeStart,
            in: allowedDates,
            displayedComponents: [.date])
          DatePicker(
            node.string("field_end_label_text") ?? "End date",
            selection: $rangeEnd,
            in: rangeStart...allowedDates.upperBound,
            displayedComponents: [.date])
        }
        .datePickerStyle(.compact)
      }

      if kind != .dateRange {
        Button(entryMode == "input" ? "Calendar" : "Keyboard") { toggleEntryMode() }
          .buttonStyle(.plain)
          .accessibilityLabel(entryMode == "input" ? "Switch to picker mode" : "Switch to input mode")
      }

      HStack {
        Button(node.string("cancel_text") ?? "Cancel") { isOpen.wrappedValue = false }
        Spacer()
        Button(node.string("confirm_text") ?? "OK") { confirm() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding()
    .onAppear {
      selection = parsedValue(node.string("value")) ?? selection
      rangeStart = parsedValue(node.string("start_value")) ?? selection
      rangeEnd = max(parsedValue(node.string("end_value")) ?? rangeStart, rangeStart)
      entryMode = node.string("entry_mode") ?? (kind == .time ? "dial" : "calendar")
    }
  }

  private func toggleEntryMode() {
    let next = entryMode == "input" ? (kind == .time ? "dial" : "calendar") : "input"
    entryMode = next
    events.setLocal(node.id, "entry_mode", .string(next))
    events.update(node.id, ["entry_mode": .string(next)])
    events.fire(node, "entry_mode_change", data: .map(["entry_mode": .string(next)]))
  }

  private func confirm() {
    let data: RufletValue
    if kind == .dateRange {
      let start = formattedDate(rangeStart)
      let end = formattedDate(rangeEnd)
      events.setLocal(node.id, "start_value", .string(start))
      events.setLocal(node.id, "end_value", .string(end))
      data = .map(["start_value": .string(start), "end_value": .string(end)])
    } else {
      let value = kind == .time ? formattedTime(selection) : formattedDate(selection)
      events.setLocal(node.id, "value", .string(value))
      data = .map(["value": .string(value)])
    }
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, ["open": .bool(false)])
    events.fire(node, "change", data: data)
  }

  private var allowedDates: ClosedRange<Date> {
    let distantPast = Calendar.current.date(byAdding: .year, value: -100, to: Date())!
    let distantFuture = Calendar.current.date(byAdding: .year, value: 100, to: Date())!
    let lower = parsedValue(node.string("first_date")) ?? distantPast
    let upper = parsedValue(node.string("last_date")) ?? distantFuture
    return min(lower, upper)...max(lower, upper)
  }

  private func parsedValue(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    if kind == .time {
      return Self.timeFormatter.date(from: value)
    }
    return Self.dateFormatter.date(from: String(value.prefix(10)))
      ?? ISO8601DateFormatter().date(from: value)
  }

  private func formattedDate(_ date: Date) -> String { Self.dateFormatter.string(from: date) }
  private func formattedTime(_ date: Date) -> String { Self.timeFormatter.string(from: date) }

  private var pickerSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.windowBackgroundColor)
    #else
      return .white
    #endif
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return formatter
  }()
}
