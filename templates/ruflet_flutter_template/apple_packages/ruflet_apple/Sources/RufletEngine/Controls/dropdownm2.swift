import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `dropdownm2.dart`.
@MainActor
public struct DropdownM2Control: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedValue: String?
  @State private var focused = false
  @State private var focusRequest = 0
  @State private var invokeToken: UUID?

  public init(control: RufletControl) {
    self.control = control
    _selectedValue = State(initialValue: control.string("value"))
  }

  public var body: some View {
    LayoutControl(control: control) {
      VStack(alignment: .leading, spacing: 4) {
        if let label = control.buildTextOrWidget("label") {
          label.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_style"))))
        }
        menu
        supportingRow
      }
      .frame(width: control.number("width") == nil ? 300 : nil)
      .background {
        RufletNativeFocusTarget(
          enabled: !control.disabled,
          autofocus: control.boolean("autofocus", default: false),
          request: focusRequest,
          onFocusChange: focusChanged)
          .frame(width: 1, height: 1)
          .opacity(0.001)
      }
      .opacity(control.disabled ? 0.55 : 1)
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private var menu: some View {
    Menu {
      ForEach(options, id: \.id) { option in
        Button {
          option.control.triggerEvent("click")
          selectedValue = option.value
          control.updateProperties(["value": .string(option.value)])
          control.triggerEvent("change", data: .string(option.value))
        } label: {
          HStack {
            if let content = option.control.buildWidget("content") {
              content
            } else {
              Text(option.label)
                .modifier(RufletTextStyleModifier(style: parseTextStyle(option.control.dynamicValue("text_style"))))
            }
          }
        }
        .disabled(option.disabled)
      }
    } label: {
      HStack(spacing: 8) {
        selectedContent
          .frame(maxWidth: control.boolean("options_fill_horizontally", default: true) ? .infinity : nil,
                 alignment: optionAlignment)
        if let icon = control.buildIconOrWidget("select_icon") {
          icon
        } else {
          Image(systemName: "chevron.down")
            .font(.system(size: control.number("select_icon_size", default: 24) ?? 24))
            .foregroundStyle(selectIconColor)
        }
      }
      .contentShape(Rectangle())
      .modifier(RufletDropdownM2Chrome(control: control, focused: focused))
    }
    .buttonStyle(.plain)
    .disabled(control.disabled)
    .simultaneousGesture(TapGesture().onEnded {
      guard !control.disabled else { return }
      focusRequest &+= 1
      control.triggerEvent("click")
    })
  }

  @ViewBuilder
  private var selectedContent: some View {
    if let selected = options.first(where: { $0.value == selectedValue }) {
      if let content = selected.control.buildWidget("content") {
        content
      } else {
        Text(selected.label).modifier(RufletTextStyleModifier(style: resolvedTextStyle))
      }
    } else if control.disabled, let disabledHint = control.buildWidget("disabled_hint") {
      disabledHint
    } else if let hint = control.buildWidget("hint") {
      hint
    } else if let hintText = control.string("hint_text") {
      Text(hintText).foregroundStyle(.secondary)
    } else {
      Text("")
    }
  }

  @ViewBuilder
  private var supportingRow: some View {
    if let error = control.buildTextOrWidget("error") {
      error
        .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("error_style"))))
        .foregroundStyle(.red)
        .font(.caption)
    } else if let helper = control.buildTextOrWidget("helper") {
      helper
        .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("helper_style"))))
        .font(.caption)
    }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, _ in
      guard name == "focus" else { throw RufletDropdownM2Error.unknownMethod(name) }
      focusRequest &+= 1
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
    selectedValue = options.contains(where: { $0.value == requested }) ? requested : nil
  }

  private func focusChanged(_ next: Bool) {
    guard focused != next else { return }
    focused = next
    control.triggerEvent(next ? "focus" : "blur")
  }

  private var options: [RufletDropdownOption] {
    control.children("options").map { option in
      option.notifyParent = true
      let value = option.string("key") ?? option.string("text") ?? String(option.id)
      return RufletDropdownOption(control: option, value: value, label: option.string("text") ?? value)
    }
  }

  private var resolvedTextStyle: RufletTextStyle? {
    let style = parseTextStyle(control.dynamicValue("text_style"))
    return RufletTextStyle(
      size: control.number("text_size") ?? style?.size,
      weight: style?.weight,
      italic: style?.italic ?? false,
      fontFamily: style?.fontFamily,
      height: style?.height,
      decoration: style?.decoration ?? 0,
      decorationColor: style?.decorationColor,
      decorationThickness: style?.decorationThickness,
      color: focused
        ? parseColor(control.string("focused_color")) ?? parseColor(control.string("color")) ?? style?.color
        : parseColor(control.string("color")) ?? style?.color,
      backgroundColor: style?.backgroundColor,
      letterSpacing: style?.letterSpacing,
      wordSpacing: style?.wordSpacing,
      overflow: style?.overflow)
  }

  private var optionAlignment: Alignment {
    parseAlignment(control.dynamicValue("alignment"))?.swiftUI ?? .leading
  }
  private var selectIconColor: Color {
    parseColor(control.string(control.disabled ? "select_icon_disabled_color" : "select_icon_enabled_color"))
      ?? .secondary
  }
}

private struct RufletDropdownM2Chrome: ViewModifier {
  @ObservedObject var control: RufletControl
  let focused: Bool

  func body(content: Content) -> some View {
    content
      .padding(parsePadding(control.dynamicValue("padding"))
        ?? parsePadding(control.dynamicValue("content_padding"))
        ?? EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
      .frame(minHeight: control.number("item_height").map { CGFloat($0) })
      .background(parseColor(control.string("bgcolor")) ?? .clear)
      .clipShape(RufletCornerShape(radius: radius))
      .overlay {
        RufletCornerShape(radius: radius)
          .stroke(borderColor, lineWidth: borderWidth)
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
}

private enum RufletDropdownM2Error: Error {
  case unknownMethod(String)
}
