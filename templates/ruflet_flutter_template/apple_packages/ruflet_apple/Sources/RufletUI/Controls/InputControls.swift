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
    Toggle(isOn: binding) {
      if let labelID = node.controlID(forKey: "label") {
        ControlView(id: labelID, axis: .none)
      } else if let label = node.string("label") {
        Text(label).rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_text_style"))
      }
    }
    .toggleStyle(.switch)
    .tint(MaterialPalette.color(node.string("active_color") ?? "primary"))
    // `label_position: "left"` puts the label before the switch, which is the
    // platform default; "right" flips it.
    .environment(
      \.layoutDirection,
      node.string("label_position")?.lowercased() == "right" ? .rightToLeft : .leftToRight)
    .modifier(FocusReporter(node: node, events: events))
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
      HStack(spacing: 8) {
        Image(systemName: symbolName)
          .foregroundColor(
            (node.bool("value") ?? false)
              ? MaterialPalette.color(node.string("active_color") ?? "primary", default: .primary)
              : .secondary)
          .font(.system(size: 20))
        if let labelID = node.controlID(forKey: "label") {
          ControlView(id: labelID, axis: .none)
        } else if let label = node.string("label") {
          Text(label)
        }
      }
    }
    .buttonStyle(.plain)
    .modifier(FocusReporter(node: node, events: events))
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
      HStack(spacing: 8) {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
          .foregroundColor(
            isSelected
              ? MaterialPalette.color(node.string("active_color") ?? "primary", default: .primary)
              : .secondary)
          .font(.system(size: 20))
        if let labelID = node.controlID(forKey: "label") {
          ControlView(id: labelID, axis: .none)
        } else if let label = node.string("label") {
          Text(label)
        }
      }
    }
    .buttonStyle(.plain)
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
      events.commit(group, value: .string(value))
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
    .tint(MaterialPalette.color(node.string("active_color") ?? "primary"))
    .modifier(FocusReporter(node: node, events: events))
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
    let start = node.double("start_value") ?? minimum
    let end = node.double("end_value") ?? maximum

    VStack(spacing: 4) {
      Slider(
        value: Binding(
          get: { start },
          set: { commit(start: min($0, end), end: end) }),
        in: minimum...max(maximum, minimum + .ulpOfOne))
      Slider(
        value: Binding(
          get: { end },
          set: { commit(start: start, end: max($0, start)) }),
        in: minimum...max(maximum, minimum + .ulpOfOne))
    }
    .tint(MaterialPalette.color(node.string("active_color") ?? "primary"))
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

/// `TextField` — the Material text input.
///
/// `on_change` fires per keystroke and `on_submit` on return, which is what
/// Flet's TextField reports. `password` picks a `SecureField`, and
/// `multiline`/`min_lines` a `TextEditor`.
struct TextFieldControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        if let prefixID = node.controlID(forKey: "prefix_icon") {
          ControlView(id: prefixID, axis: .none)
        }
        field
        if let suffixID = node.controlID(forKey: "suffix_icon") {
          ControlView(id: suffixID, axis: .none)
        }
      }
        .textFieldStyle(.plain)
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 8)
            .fill(fieldBackground))
        .overlay(borderStroke)
      if let helper = node.string("helper_text"), !helper.isEmpty {
        Text(helper).font(.caption2).foregroundColor(.secondary)
      }
      if let error = node.string("error_text"), !error.isEmpty {
        Text(error).font(.caption2).foregroundColor(.red)
      }
    }
    .modifier(FocusReporter(node: node, events: events))
  }

  @ViewBuilder
  private var field: some View {
    // A Material label rests inside an empty field and floats only while
    // editing. Native TextField's prompt is the closest Apple equivalent and
    // keeps fixed-height fields from clipping a separate label row.
    let prompt = node.string("hint_text") ?? node.string("label") ?? ""
    if node.bool("password") == true {
      SecureField(prompt, text: binding)
        .onSubmit { events.fire(node, "submit", data: .string(binding.wrappedValue)) }
    } else if node.bool("multiline") == true || (node.int("min_lines") ?? 1) > 1 {
      TextEditor(text: binding)
        .frame(minHeight: CGFloat((node.int("min_lines") ?? 3) * 20))
    } else {
      TextField(prompt, text: binding)
        .onSubmit { events.fire(node, "submit", data: .string(binding.wrappedValue)) }
        .modifier(KeyboardType(node: node))
    }
  }

  @ViewBuilder
  private var borderStroke: some View {
    let radius = ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(
          node.string("error_text").map { _ in
            MaterialPalette.color(for: node, property: "error_border_color", default: .red)
          }
            ?? MaterialPalette.color(for: node, property: "border_color", default: .clear),
          lineWidth: CGFloat(node.double("border_width") ?? 1))
    }
  }

  private var fieldBackground: Color {
    if let explicit = MaterialPalette.color(node.props["bgcolor"]?.stringValue) {
      return explicit
    }
    return MaterialPalette.color(FletThemeDefaults.backgroundToken(for: node)) ?? .clear
  }

  private var binding: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
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

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").foregroundColor(.secondary)
      TextField(
        node.string("bar_hint_text") ?? node.string("view_hint_text") ?? "",
        text: Binding(
          get: { node.string("value") ?? "" },
          set: { events.commit(node, value: .string($0)) })
      )
      .textFieldStyle(.plain)
      .focused($focused)
      .onSubmit { events.fire(node, "submit", data: .string(node.string("value") ?? "")) }

      if !(node.string("value") ?? "").isEmpty {
        Button {
          events.commit(node, value: .string(""))
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Capsule().fill(Color.gray.opacity(0.14)))
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus", "open_view":
        focused = true
        completion(.success(.null))
      case "close_view":
        focused = false
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
}

/// `Dropdown` / `DropdownM2` — a native `Picker` over the control's options.
struct DropdownControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let options = optionNodes

    VStack(alignment: .leading, spacing: 4) {
      if let label = node.string("label"), !label.isEmpty {
        Text(label).font(.caption).foregroundColor(.secondary)
      }
      Picker(
        node.string("hint_text") ?? "",
        selection: Binding(
          get: { node.string("value") ?? "" },
          set: { events.commit(node, value: .string($0)) })
      ) {
        ForEach(options, id: \.id) { option in
          optionLabel(option).tag(option.string("key") ?? option.string("text") ?? "")
        }
      }
      .pickerStyle(.menu)
      .modifier(FocusReporter(node: node, events: events))
    }
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
        DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
          .datePickerStyle(.graphical)
          .labelsHidden()
      case .time:
        #if os(iOS)
        DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
          .datePickerStyle(.wheel)
          .labelsHidden()
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
    }
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
