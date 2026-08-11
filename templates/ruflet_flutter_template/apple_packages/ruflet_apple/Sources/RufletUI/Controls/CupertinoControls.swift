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
      .modifier(OptionalTint(color: MaterialPalette.color(node.string("bgcolor"))))
      .modifier(OptionalForeground(color: MaterialPalette.color(node.string("color"))))
      .modifier(FocusReporter(node: node, events: events))
      .modifier(LongPressReporter(node: node, events: events))
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

  private func activate() {
    if let url = node.string("url").flatMap(URL.init(string:)) { openURL(url) }
    events.fire(node, "click")
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
    Toggle(
      isOn: Binding(
        get: { node.bool("value") ?? false },
        set: { events.commit(node, value: .bool($0)) })
    ) {
      if let label = node.string("label") { Text(label) }
    }
    .toggleStyle(.switch)
    // Ruby names the switch's colours after the parts they paint, the way
    // Flutter's CupertinoSwitch does: the track when on is `active_track_color`,
    // not the `active_color` the sliders and selection controls use.
    .tint(MaterialPalette.color(node.string("active_track_color")))
    .background(thumbImageValidation)
  }

  @ViewBuilder
  private var thumbImageValidation: some View {
    let source = node.bool("value") == true
      ? node.string("active_thumb_image_src") : node.string("inactive_thumb_image_src")
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

/// `CupertinoSlider` — the platform slider.
struct CupertinoSliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let minimum = node.double("min") ?? 0
    let maximum = node.double("max") ?? 1

    Slider(
      value: Binding(
        get: { node.double("value") ?? minimum },
        set: { events.commit(node, value: .double($0)) }),
      in: minimum...max(maximum, minimum + .ulpOfOne),
      onEditingChanged: { editing in
        events.fire(
          node, editing ? "change_start" : "change_end",
          data: .double(node.double("value") ?? minimum))
      }
    )
    .tint(MaterialPalette.color(node.string("active_color")))
  }
}

/// `CupertinoCheckbox` and `CupertinoRadio` — the iOS marks.
struct CupertinoSelectionControlView: View {
  enum Kind { case checkbox, radio }

  let node: ControlNode
  let kind: Kind
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button {
      events.commit(node, value: .bool(!(node.bool("value") ?? false)))
    } label: {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .foregroundColor(
            (node.bool("value") ?? false)
              ? MaterialPalette.color(node.string("active_color"))
              : .secondary)
        if let label = node.string("label") { Text(label) }
      }
    }
    .buttonStyle(.plain)
    .modifier(FocusReporter(node: node, events: events))
    .disabled(node.bool("disabled") ?? false)
  }

  private var symbol: String {
    let on = node.bool("value") ?? false
    switch kind {
    case .checkbox: return on ? "checkmark.circle.fill" : "circle"
    case .radio: return on ? "largecircle.fill.circle" : "circle"
    }
  }
}

/// `CupertinoTextField` — a rounded iOS field.
struct CupertinoTextFieldControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var revealed = false

  var body: some View {
    HStack(spacing: 6) {
      overlay(forKey: "prefix_icon", mode: node.string("prefix_visibility_mode"))
      overlay(forKey: "prefix", mode: node.string("prefix_visibility_mode"))
      field
      overlay(forKey: "suffix", mode: node.string("suffix_visibility_mode"))
      overlay(forKey: "suffix_icon", mode: node.string("suffix_visibility_mode"))
      revealButton
      clearButton
    }
    .padding(contentPadding)
    .background(
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(fieldBackground))
    .overlay(borderStroke)
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
    if node.bool("multiline") == true || (node.int("min_lines") ?? 1) > 1 {
      TextEditor(text: binding)
        .frame(minHeight: CGFloat((node.int("min_lines") ?? 3) * 20))
    } else {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          placeholder: placeholder,
          secure: obscure,
          traits: RufletTextInputTraits(node: node),
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
      #else
        TextField(placeholder, text: binding)
          .onSubmit { events.fire(node, "submit", data: .string(binding.wrappedValue)) }
      #endif
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
  private func overlay(forKey key: String, mode: String?) -> some View {
    if let id = node.controlID(forKey: key), shows(mode, default: true) {
      ControlView(id: id, axis: .none)
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

  private var cornerRadius: CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
  }

  private var contentPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["content_padding"])
      ?? ControlProps.edgeInsets(node.props["padding"])
      ?? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
  }

  private var fieldBackground: Color {
    let key = focused ? "focused_bgcolor" : "bgcolor"
    if let explicit = MaterialPalette.color(node.string(key) ?? node.string("bgcolor")) {
      return explicit
    }
    if node.bool("filled") == true {
      return MaterialPalette.color(node.string("fill_color"), default: .gray.opacity(0.12))
    }
    return MaterialPalette.color(node.string("fill_color"), default: .gray.opacity(0.12))
  }

  @ViewBuilder
  private var borderStroke: some View {
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
          MaterialPalette.color(
            node.string(focused ? "focused_border_color" : "border_color"),
            default: .clear),
          lineWidth: CGFloat(
            node.double(focused ? "focused_border_width" : "border_width") ?? 1))
    }
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
  }
}

/// `CupertinoDatePicker` and `CupertinoTimerPicker`.
struct CupertinoDatePickerControlView: View {
  let node: ControlNode
  let timerMode: Bool
  @Environment(\.rufletEvents) private var events
  @State private var selection = Date()

  var body: some View {
    DatePicker(
      "", selection: $selection,
      displayedComponents: components)
      .modifier(WheelDatePickerStyle())
      .labelsHidden()
      .onChange(of: selection) { value in
        events.commit(node, value: .string(ISO8601DateFormatter().string(from: value)))
      }
  }

  private var components: DatePickerComponents {
    if timerMode { return [.hourAndMinute] }
    switch node.string("date_picker_mode")?.lowercased() {
    case "time": return [.hourAndMinute]
    case "datetime": return [.date, .hourAndMinute]
    default: return [.date]
    }
  }
}

/// `CupertinoActivityIndicator` — the iOS spinner.
struct CupertinoActivityIndicatorControlView: View {
  let node: ControlNode

  var body: some View {
    ProgressView()
      .progressViewStyle(.circular)
      .scaleEffect(CGFloat(node.double("radius") ?? 10) / 10)
      .tint(MaterialPalette.color(node.string("color")))
  }
}

/// `CupertinoAppBar` — the iOS title bar.
struct CupertinoAppBarControlView: View {
  let node: ControlNode

  var body: some View {
    HStack(spacing: 8) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      }
      Spacer(minLength: 0)
      if let middleID = node.controlID(forKey: "middle") ?? node.controlID(forKey: "title") {
        ControlView(id: middleID, axis: .none).font(.headline)
      }
      Spacer(minLength: 0)
      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(alignment: .bottom) { Divider() }
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
