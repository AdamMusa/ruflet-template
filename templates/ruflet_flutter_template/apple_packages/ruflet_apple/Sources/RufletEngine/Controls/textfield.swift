import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `TextFieldControl`.
@MainActor
public struct TextFieldControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletTextInputControl(control: control, style: .form)
  }
}

@MainActor
struct RufletTextInputControl: View {
  enum Style { case form, cupertino }

  @ObservedObject var control: RufletControl
  let style: Style
  @State private var value: String
  @State private var focused = false
  @State private var revealPassword = false
  @State private var selection: RufletTextSelection?
  @State private var focusRequest = 0
  @State private var blurRequest = 0
  @State private var invokeToken: UUID?
  @State private var lastFocusValue: String?
  @State private var lastBlurValue: String?

  init(control: RufletControl, style: Style) {
    self.control = control
    self.style = style
    _value = State(initialValue: control.string("value", default: "") ?? "")
    _selection = State(initialValue: Self.parseSelection(control.value("selection"), maximum: Int.max))
  }

  var body: some View {
    LayoutControl(control: control) {
      chrome
        .frame(width: control.number("width") == nil ? 300 : nil)
        .frame(maxWidth: fitParentSize ? .infinity : nil, maxHeight: fitParentSize ? .infinity : nil)
        .allowsHitTesting(!control.boolean("ignore_pointers", default: false))
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private var chrome: some View {
    VStack(alignment: .leading, spacing: 4) {
      if style == .form, let label = control.buildTextOrWidget("label") {
        label
          .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_style"))))
          .foregroundStyle(activeTextColor)
      }

      HStack(spacing: 6) {
        if style == .form, let icon = control.buildIconOrWidget("icon") { icon }
        if style == .form, let prefix = control.buildIconOrWidget("prefix_icon") { prefix }
        if overlayVisible("prefix_visibility_mode", default: .always),
           let prefix = control.buildTextOrWidget("prefix") {
          prefix.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("prefix_style"))))
        }

        nativeInput
          .frame(minHeight: minimumNativeHeight)

        if password && control.boolean("can_reveal_password", default: false) {
          Button { revealPassword.toggle() } label: {
            Image(systemName: revealPassword ? "eye.slash" : "eye")
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text(revealPassword ? "Hide password" : "Show password"))
        } else if style == .form, let suffix = control.buildIconOrWidget("suffix_icon") {
          suffix
        }
        if overlayVisible("suffix_visibility_mode", default: .always),
           let suffix = control.buildTextOrWidget("suffix") {
          suffix.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("suffix_style"))))
        }
      }
      .padding(inputPadding)
      .background(inputBackground)
      .overlay { inputBorder }
      .clipShape(RufletCornerShape(radius: borderRadius))

      if style == .form { supportingRow }
    }
    .opacity(control.disabled ? 0.55 : 1)
  }

  private var nativeInput: some View {
    RufletNativeTextInput(
      configuration: configuration,
      callbacks: RufletNativeTextInputCallbacks(
        onChange: valueChanged,
        onSubmit: { submitted in control.triggerEvent("submit", data: .string(submitted)) },
        onFocusChange: focusChanged,
        onSelectionChange: selectionChanged,
        onTap: { control.triggerEvent("click") },
        onTapOutside: { control.triggerEvent("tap_outside") }))
  }

  @ViewBuilder
  private var supportingRow: some View {
    let error = control.buildTextOrWidget("error")
    let helper = control.buildTextOrWidget("helper")
    HStack(alignment: .top) {
      if let error {
        error.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("error_style"))))
          .foregroundStyle(Color.red)
      } else if let helper {
        helper.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("helper_style"))))
      }
      Spacer(minLength: 4)
      if let counter = control.buildTextOrWidget("counter") {
        counter.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("counter_style"))))
      } else if control.value("counter") != nil, let counterText {
        Text(counterText)
          .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("counter_style"))))
      }
    }
    .font(.caption)
  }

  @ViewBuilder
  private var inputBackground: some View {
    if let gradient = style == .cupertino ? parseGradient(control.dynamicValue("gradient")) : nil {
      RufletGradientShapeStyle(gradient: gradient)
    } else {
      activeBackgroundColor
    }
  }

  @ViewBuilder
  private var inputBorder: some View {
    switch borderKind {
    case .none:
      EmptyView()
    case .underline:
      Rectangle()
        .fill(activeBorderColor)
        .frame(height: activeBorderWidth)
        .frame(maxHeight: .infinity, alignment: .bottom)
    case .outline:
      RufletCornerShape(radius: borderRadius)
        .stroke(activeBorderColor, lineWidth: activeBorderWidth)
    }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, _ in
      if name == "focus" { focusRequest &+= 1 }
      else { throw RufletTextFieldError.unknownMethod(name) }
      return .null
    }
    synchronizeFocusProperties()
  }

  private func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func synchronizeFromControl() {
    let next = control.string("value", default: "") ?? ""
    if next != value { value = next }
    if let nextSelection = Self.parseSelection(control.value("selection"), maximum: next.utf16.count),
       nextSelection != selection { selection = nextSelection }
    synchronizeFocusProperties()
  }

  private func synchronizeFocusProperties() {
    let nextFocus = control.string("focus")
    if let nextFocus, nextFocus != lastFocusValue {
      lastFocusValue = nextFocus
      focusRequest &+= 1
    }
    let nextBlur = control.string("blur")
    if let nextBlur, nextBlur != lastBlurValue {
      lastBlurValue = nextBlur
      blurRequest &+= 1
    }
  }

  private func valueChanged(_ next: String) {
    guard next != value else { return }
    value = next
    control.updateProperties(["value": .string(next)])
    control.triggerEvent("change", data: .string(next))
  }

  private func focusChanged(_ isFocused: Bool) {
    guard focused != isFocused else { return }
    focused = isFocused
    control.triggerEvent(isFocused ? "focus" : "blur")
  }

  private func selectionChanged(_ next: RufletTextSelection) {
    guard next != selection else { return }
    selection = next
    guard control.hasEventHandler("selection_change") else { return }
    control.updateProperties(["selection": next.value])
    let nsRange = next.range
    let selected: String
    if let range = Range(nsRange, in: value) { selected = String(value[range]) } else { selected = "" }
    control.triggerEvent("selection_change", data: [
      "selected_text": .string(selected),
      "selection": next.value,
    ])
  }

  private var configuration: RufletNativeTextInputConfiguration {
    let styleDetails = parseTextStyle(control.dynamicValue("text_style"))
    return RufletNativeTextInputConfiguration(
      value: value,
      selection: selection,
      multiline: multiline,
      minLines: control.integer("min_lines", default: 1) ?? 1,
      maxLines: control.integer("max_lines") ?? (multiline ? nil : 1),
      fitParentSize: fitParentSize,
      readOnly: control.boolean("read_only", default: false),
      password: password && !revealPassword,
      enabled: !control.disabled,
      autofocus: control.boolean("autofocus", default: false),
      showCursor: control.boolean("show_cursor"),
      canRequestFocus: control.boolean("can_request_focus", default: true),
      enableInteractiveSelection: control.boolean("enable_interactive_selection"),
      keyboardType: multiline ? "multiline" : control.string("keyboard_type", default: "text") ?? "text",
      capitalization: parseEnum(
        RufletTextCapitalization.self,
        control.string("capitalization"),
        RufletTextCapitalization.none)!,
      autocorrect: control.boolean("autocorrect", default: true),
      enableSuggestions: control.boolean("enable_suggestions", default: true),
      smartDashes: control.boolean("smart_dashes_type", default: true),
      smartQuotes: control.boolean("smart_quotes_type", default: true),
      maxLength: control.integer("max_length"),
      inputFilter: parseInputFilter(control.dynamicValue("input_filter")),
      textAlignment: parseEnum(RufletTextAlign.self, control.string("text_align"), .start)!.alignment,
      fontSize: control.number("text_size") ?? styleDetails?.size,
      fontFamily: styleDetails?.fontFamily,
      fontWeight: styleDetails?.weight,
      italic: styleDetails?.italic ?? false,
      textColor: activeTextColor,
      cursorColor: parseColor(control.string("cursor_color")),
      selectionColor: parseColor(control.string("selection_color")),
      placeholder: placeholder,
      placeholderColor: parseTextStyle(control.dynamicValue(style == .cupertino ? "placeholder_style" : "hint_style"))?.color,
      obscuringCharacter: control.string("obscuring_character", default: "•")?.first ?? "•",
      clearButtonMode: parseEnum(
        RufletOverlayVisibilityMode.self,
        control.string("clear_button_visibility_mode"),
        .never)!,
      autofillHints: parseAutofillHints(control.dynamicValue("autofill_hints"), []) ?? [],
      shiftEnter: control.boolean("shift_enter", default: false),
      ignoreUpDownKeys: control.boolean("ignore_up_down_keys", default: false),
      keyboardBrightness: control.string("keyboard_brightness"),
      alwaysCallOnTap: control.boolean("always_call_on_tap", default: false),
      reportsTapOutside: control.boolean("on_tap_outside", default: false),
      focusRequest: focusRequest,
      blurRequest: blurRequest)
  }

  private var multiline: Bool {
    control.boolean("multiline", default: false) || control.boolean("shift_enter", default: false)
  }
  private var fitParentSize: Bool { control.boolean("fit_parent_size", default: false) }
  private var password: Bool { control.boolean("password", default: false) }
  private var minimumNativeHeight: CGFloat {
    fitParentSize ? 0 : CGFloat(max(control.integer("min_lines", default: 1) ?? 1, 1)) * 20 + 4
  }
  private var placeholder: String? {
    if style == .cupertino {
      return control.string("placeholder_text") ?? control.string("label")
    }
    return control.string("hint_text")
  }
  private var inputPadding: EdgeInsets {
    parsePadding(control.dynamicValue(style == .cupertino ? "padding" : "content_padding"))
      ?? EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7)
  }
  private var borderKind: RufletFormFieldBorder {
    parseEnum(RufletFormFieldBorder.self, control.string("border"), .outline)!
  }
  private var borderRadius: RufletBorderRadius {
    if borderKind == .underline { return .zero }
    return parseBorderRadius(control.dynamicValue("border_radius"),
      RufletBorderRadius(topLeft: 5, topRight: 5, bottomLeft: 5, bottomRight: 5))!
  }
  private var activeBorderWidth: CGFloat {
    CGFloat(focused
      ? control.number("focused_border_width") ?? control.number("border_width") ?? 2
      : control.number("border_width") ?? 1)
  }
  private var activeBorderColor: Color {
    parseColor(focused
      ? control.string("focused_border_color") ?? control.string("border_color")
      : control.string("border_color"))
      ?? (focused ? .accentColor : .secondary.opacity(0.6))
  }
  private var activeBackgroundColor: Color {
    parseColor(focused
      ? control.string("focused_bgcolor") ?? control.string("fill_color") ?? control.string("bgcolor")
      : control.string("fill_color") ?? control.string("bgcolor"))
      ?? (style == .cupertino ? Color.rufletSystemBackground : .clear)
  }
  private var activeTextColor: Color {
    parseColor(focused
      ? control.string("focused_color") ?? control.string("color")
      : control.string("color"))
      ?? parseTextStyle(control.dynamicValue("text_style"))?.color
      ?? .primary
  }
  private var counterText: String? {
    guard var text = control.string("counter") else { return nil }
    let maxLength = control.integer("max_length")
    text = text.replacingOccurrences(of: "{value_length}", with: String(value.utf16.count))
    text = text.replacingOccurrences(of: "{max_length}", with: maxLength.map(String.init) ?? "None")
    text = text.replacingOccurrences(
      of: "{symbols_left}",
      with: maxLength.map { String($0 - value.utf16.count) } ?? "None")
    return text
  }

  private func overlayVisible(
    _ property: String,
    default defaultValue: RufletOverlayVisibilityMode
  ) -> Bool {
    let mode = parseEnum(RufletOverlayVisibilityMode.self, control.string(property), defaultValue)!
    return switch mode {
    case .never: false
    case .always: true
    case .editing: focused
    case .notEditing: !focused
    }
  }

  private static func parseSelection(_ value: RufletValue?, maximum: Int) -> RufletTextSelection? {
    guard let map = value?.map,
          let base = map["base_offset"]?.integer,
          let extent = map["extent_offset"]?.integer
    else { return nil }
    return RufletTextSelection(
      baseOffset: min(max(base, 0), maximum),
      extentOffset: min(max(extent, 0), maximum))
  }
}

private enum RufletFormFieldBorder: String, CaseIterable, RufletStringEnum {
  case outline, underline, none
}

private enum RufletTextFieldError: Error {
  case unknownMethod(String)
}
