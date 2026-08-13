import RufletProtocol
import SwiftUI

@MainActor
struct RufletDropdownOption {
  let control: RufletControl
  let value: String
  let label: String

  var id: Int { control.id }
  var disabled: Bool { control.disabled }
}

/// Apple-native port of pinned `dropdown.dart`.
@MainActor
public struct DropdownControl: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedValue: String?
  @State private var text: String
  @State private var focused = false
  @State private var focusRequest = 0
  @State private var invokeToken: UUID?

  public init(control: RufletControl) {
    self.control = control
    let value = control.string("value")
    _selectedValue = State(initialValue: value)
    _text = State(initialValue: control.string("text") ?? value ?? "")
  }

  public var body: some View {
    LayoutControl(control: control) {
      VStack(alignment: .leading, spacing: 4) {
        if let label = control.buildTextOrWidget("label") {
          label.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_style"))))
        }
        field
        supportingText
      }
      .opacity(control.disabled ? 0.55 : 1)
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  @ViewBuilder
  private var field: some View {
    if editable {
      HStack(spacing: 6) {
        if let leading = control.buildIconOrWidget("leading_icon") { leading }
        nativeInput
        menuButton(iconProperty: focused ? "selected_trailing_icon" : "trailing_icon")
      }
      .modifier(RufletDropdownChrome(control: control, focused: focused))
    } else {
      Menu {
        optionButtons
      } label: {
        HStack(spacing: 6) {
          if let leading = control.buildIconOrWidget("leading_icon") { leading }
          Text(displayedText)
            .foregroundStyle(displayedText.isEmpty ? Color.secondary : textColor)
            .frame(maxWidth: .infinity, alignment: textAlignment.frameAlignment)
          if let selected = control.buildIconOrWidget("selected_trailing_icon") {
            selected
          } else if let trailing = control.buildIconOrWidget("trailing_icon") {
            trailing
          } else {
            Image(systemName: "chevron.up.chevron.down")
          }
        }
        .contentShape(Rectangle())
        .modifier(RufletDropdownChrome(control: control, focused: focused))
      }
      .buttonStyle(.plain)
      .disabled(control.disabled)
    }
  }

  private var nativeInput: some View {
    RufletNativeTextInput(
      configuration: RufletNativeTextInputConfiguration(
        value: text,
        selection: nil,
        multiline: false,
        minLines: 1,
        maxLines: 1,
        fitParentSize: false,
        readOnly: false,
        password: false,
        enabled: !control.disabled,
        autofocus: control.boolean("autofocus", default: false),
        showCursor: nil,
        canRequestFocus: true,
        enableInteractiveSelection: true,
        keyboardType: "text",
        capitalization: parseEnum(
          RufletTextCapitalization.self,
          control.string("capitalization"),
          RufletTextCapitalization.none)!,
        autocorrect: true,
        enableSuggestions: true,
        smartDashes: true,
        smartQuotes: true,
        maxLength: nil,
        inputFilter: parseInputFilter(control.dynamicValue("input_filter")),
        textAlignment: textAlignment,
        fontSize: control.number("text_size") ?? textStyle?.size,
        fontFamily: textStyle?.fontFamily,
        fontWeight: textStyle?.weight,
        italic: textStyle?.italic ?? false,
        textColor: textColor,
        cursorColor: nil,
        selectionColor: nil,
        placeholder: control.string("hint_text"),
        placeholderColor: parseTextStyle(control.dynamicValue("hint_style"))?.color,
        obscuringCharacter: "•",
        clearButtonMode: .never,
        autofillHints: [],
        shiftEnter: false,
        ignoreUpDownKeys: false,
        keyboardBrightness: nil,
        alwaysCallOnTap: false,
        reportsTapOutside: false,
        focusRequest: focusRequest,
        blurRequest: 0),
      callbacks: RufletNativeTextInputCallbacks(
        onChange: textChanged,
        onSubmit: { _ in
          guard control.boolean("enable_search", default: true),
                let match = filteredOptions.first
          else { return }
          select(match)
        },
        onFocusChange: focusChanged,
        onSelectionChange: { _ in },
        onTap: {},
        onTapOutside: {}))
      .frame(minHeight: 24)
  }

  private func menuButton(iconProperty: String) -> some View {
    Menu {
      optionButtons
    } label: {
      if let icon = control.buildIconOrWidget(iconProperty) {
        icon
      } else {
        Image(systemName: "chevron.up.chevron.down")
      }
    }
    .menuStyle(.borderlessButton)
    .disabled(control.disabled)
    .simultaneousGesture(TapGesture().onEnded {
      if editable && !control.disabled { focusRequest &+= 1 }
    })
  }

  @ViewBuilder
  private var optionButtons: some View {
    ForEach(filteredOptions, id: \.id) { option in
      Button {
        select(option)
      } label: {
        RufletDropdownOptionLabel(option: option, richSlots: true)
      }
      .disabled(option.disabled || control.disabled)
    }
  }

  @ViewBuilder
  private var supportingText: some View {
    if let error = control.string("error_text") {
      Text(error)
        .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("error_style"))))
        .foregroundStyle(.red)
        .font(.caption)
    } else if let helper = control.string("helper_text") {
      Text(helper)
        .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("helper_style"))))
        .font(.caption)
    }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, _ in
      guard name == "focus" else { throw RufletDropdownError.unknownMethod(name) }
      if editable { focusRequest &+= 1 }
      return .null
    }
    synchronizeFromControl()
  }

  private func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func synchronizeFromControl() {
    let requested = control.string("value")
    let valid = options.first(where: { $0.value == requested })
    let nextValue = valid?.value
    guard selectedValue != nextValue else { return }
    let previous = selectedValue
    selectedValue = nextValue
    let nextText: String
    if let valid {
      nextText = valid.label
    } else if previous != nil {
      nextText = ""
    } else {
      nextText = text
    }
    if text != nextText {
      text = nextText
      control.updateProperties(["text": .string(nextText)], server: false)
    }
  }

  private func textChanged(_ next: String) {
    guard text != next else { return }
    text = next
    control.updateProperties(["text": .string(next)])
    control.triggerEvent("text_change", data: .string(next))
  }

  private func select(_ option: RufletDropdownOption) {
    // Flutter's DropdownMenu updates its controller before onSelected.
    textChanged(option.label)
    selectedValue = option.value
    control.updateProperties(["value": .string(option.value)])
    control.triggerEvent("select", data: .string(option.value))
  }

  private func focusChanged(_ next: Bool) {
    guard focused != next else { return }
    focused = next
    control.triggerEvent(next ? "focus" : "blur")
  }

  private var options: [RufletDropdownOption] {
    control.children("options").compactMap { option in
      option.notifyParent = true
      guard let value = option.string("key") ?? option.string("text"),
            let label = option.string("text") ?? option.string("key")
      else { return nil }
      return RufletDropdownOption(control: option, value: value, label: label)
    }
  }

  private var filteredOptions: [RufletDropdownOption] {
    guard editable, control.boolean("enable_filter", default: false), !text.isEmpty else { return options }
    return options.filter { $0.label.localizedCaseInsensitiveContains(text) }
  }

  private var displayedText: String {
    options.first(where: { $0.value == selectedValue })?.label
      ?? (selectedValue == nil ? control.string("hint_text", default: "")! : text)
  }
  private var editable: Bool { control.boolean("editable", default: false) }
  private var textAlignment: TextAlignment {
    parseEnum(RufletTextAlign.self, control.string("text_align"), .start)!.alignment
  }
  private var textStyle: RufletTextStyle? { parseTextStyle(control.dynamicValue("text_style")) }
  private var textColor: Color {
    parseColor(control.string("color")) ?? textStyle?.color ?? .primary
  }
}

@MainActor
private struct RufletDropdownOptionLabel: View {
  let option: RufletDropdownOption
  let richSlots: Bool

  var body: some View {
    HStack {
      if richSlots, let leading = option.control.buildIconOrWidget("leading_icon") { leading }
      if let content = option.control.buildWidget("content") {
        content
      } else {
        Text(option.label)
          .modifier(RufletTextStyleModifier(style: parseTextStyle(option.control.dynamicValue("text_style"))))
      }
      if richSlots, let trailing = option.control.buildIconOrWidget("trailing_icon") { trailing }
    }
  }
}

private struct RufletDropdownChrome: ViewModifier {
  @ObservedObject var control: RufletControl
  let focused: Bool

  func body(content: Content) -> some View {
    content
      .padding(parsePadding(control.dynamicValue("content_padding")) ?? EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
      .background(backgroundColor)
      .clipShape(RufletCornerShape(radius: radius))
      .overlay { border }
  }

  @ViewBuilder
  private var border: some View {
    switch parseEnum(RufletDropdownBorder.self, control.string("border"), .outline)! {
    case .none:
      EmptyView()
    case .underline:
      Rectangle().fill(borderColor).frame(height: borderWidth).frame(maxHeight: .infinity, alignment: .bottom)
    case .outline:
      RufletCornerShape(radius: radius).stroke(borderColor, lineWidth: borderWidth)
    }
  }

  private var radius: RufletBorderRadius {
    parseBorderRadius(control.dynamicValue("border_radius"),
      RufletBorderRadius(topLeft: 5, topRight: 5, bottomLeft: 5, bottomRight: 5))!
  }
  private var borderWidth: CGFloat {
    CGFloat(focused
      ? control.number("focused_border_width") ?? control.number("border_width") ?? 2
      : control.number("border_width") ?? 1)
  }
  private var borderColor: Color {
    parseColor(focused
      ? control.string("focused_border_color") ?? control.string("border_color")
      : control.string("border_color"))
      ?? (focused ? .accentColor : .secondary.opacity(0.6))
  }
  private var backgroundColor: Color {
    guard control.boolean("filled", default: false) else { return .clear }
    return parseColor(control.string("fill_color")) ?? Color.rufletSystemBackground
  }
}

private enum RufletDropdownBorder: String, CaseIterable, RufletStringEnum {
  case outline, underline, none
}

private enum RufletDropdownError: Error {
  case unknownMethod(String)
}

private extension TextAlignment {
  var frameAlignment: Alignment {
    switch self {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }
}
