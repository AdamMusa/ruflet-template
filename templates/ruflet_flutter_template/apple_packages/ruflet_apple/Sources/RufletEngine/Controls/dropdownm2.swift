import RufletProtocol
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Apple-native port of pinned `dropdownm2.dart`.
@MainActor
public struct DropdownM2Control: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedValue: String?
  @State private var focused = false
  @State private var hovered = false
  @State private var menuPresented = false
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
          label
            .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("label_style"))))
            .frame(
              maxWidth: .infinity,
              alignment: presentation.alignLabelWithHint ? .topLeading : .leading)
        }
        menu
        supportingRow
      }
      .frame(width: control.number("width") == nil ? 300 : nil)
      .modifier(RufletDropdownM2ConstraintsModifier(presentation.sizeConstraints))
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
      .onHover { hovered = $0 }
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private var menu: some View {
    Button {
      guard !control.disabled else { return }
      focusRequest &+= 1
      control.triggerEvent("click")
      menuPresented.toggle()
    } label: {
      HStack(spacing: 6) {
        if let icon = control.buildIconOrWidget("icon") { icon }
        decoratedField
          .contentShape(Rectangle())
          .modifier(RufletDropdownM2Chrome(
            control: control, focused: focused, hovered: hovered,
            presentation: presentation))
      }
    }
    .buttonStyle(.plain)
    .disabled(control.disabled)
    .popover(isPresented: $menuPresented) { optionPanel }
  }

  private var decoratedField: some View {
    HStack(spacing: 6) {
      if let prefixIcon = control.buildIconOrWidget("prefix_icon") {
        prefixIcon.modifier(RufletDropdownM2ConstraintsModifier(presentation.prefixIconConstraints))
      }
      if let prefix = control.buildTextOrWidget("prefix") {
        prefix.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("prefix_style"))))
      }
      selectedContent
        .frame(
          maxWidth: control.boolean("options_fill_horizontally", default: true) ? .infinity : nil,
          alignment: optionAlignment)
      if let suffix = control.buildTextOrWidget("suffix") {
        suffix.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("suffix_style"))))
      }
      if let suffixIcon = control.buildIconOrWidget("suffix_icon") {
        suffixIcon.modifier(RufletDropdownM2ConstraintsModifier(presentation.suffixIconConstraints))
      }
      if let icon = control.buildIconOrWidget("select_icon") {
        icon.foregroundStyle(selectIconColor)
      } else {
        Image(systemName: "chevron.down")
          .font(.system(size: control.number("select_icon_size", default: 24) ?? 24))
          .foregroundStyle(selectIconColor)
      }
    }
    .frame(maxWidth: .infinity, alignment: optionAlignment)
  }

  private var optionPanel: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(options, id: \.id) { option in
          Button {
            select(option)
          } label: {
            RufletDropdownOptionLabel(option: option, richSlots: false)
              .frame(
                maxWidth: .infinity,
                alignment: parseAlignment(option.control.dynamicValue("alignment"))?.swiftUI ?? .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(option.disabled || control.disabled)
          .frame(minHeight: control.number("item_height").map { CGFloat($0) })
          .padding(.horizontal, 10)
          .padding(.vertical, presentation.dense ? 4 : 8)
        }
      }
    }
    .frame(maxHeight: presentation.maxMenuHeight)
    .padding(2)
    .background(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
    .clipShape(RufletCornerShape(radius: presentation.borderRadius))
    .shadow(color: .black.opacity(0.2), radius: presentation.elevation, y: presentation.elevation / 2)
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
      Text(hintText)
        .modifier(RufletTextStyleModifier(style: presentation.hintStyle))
        .foregroundStyle(presentation.hintStyle?.color ?? .secondary)
        .lineLimit(presentation.hintMaxLines)
    } else {
      Text("")
    }
  }

  @ViewBuilder
  private var supportingRow: some View {
    HStack(alignment: .top) {
      if let error = control.buildTextOrWidget("error") {
        error
          .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("error_style"))))
          .foregroundStyle(.red)
          .lineLimit(presentation.errorMaxLines)
      } else if let helper = control.buildTextOrWidget("helper") {
        helper
          .modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("helper_style"))))
          .lineLimit(presentation.helperMaxLines)
      }
      Spacer(minLength: 4)
      if let counter = control.buildTextOrWidget("counter") {
        counter.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("counter_style"))))
      } else if let counter = presentation.counterText {
        Text(counter).modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("counter_style"))))
      }
    }
    .font(.caption)
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

  private func select(_ option: RufletDropdownOption) {
    option.control.triggerEvent("click")
    selectedValue = option.value
    control.updateProperties(["value": .string(option.value)])
    control.triggerEvent("change", data: .string(option.value))
    menuPresented = false
    if presentation.enableFeedback { performSelectionFeedback() }
  }

  private func performSelectionFeedback() {
    #if canImport(UIKit)
    UISelectionFeedbackGenerator().selectionChanged()
    #elseif canImport(AppKit)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
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
    if control.disabled {
      return parseColor(control.string("select_icon_disabled_color")) ?? .secondary
    }
    return parseColor(control.string("select_icon_enabled_color")) ?? .secondary
  }
  private var presentation: RufletDropdownM2Presentation {
    RufletDropdownM2Presentation(control: control, focused: focused, hovered: hovered)
  }
}

struct RufletDropdownM2Presentation {
  let alignLabelWithHint: Bool
  let border: RufletDropdownM2Border
  let borderRadius: RufletBorderRadius
  let backgroundColor: Color?
  let collapsed: Bool
  let dense: Bool
  let elevation: CGFloat
  let enableFeedback: Bool
  let errorMaxLines: Int?
  let fillColor: Color?
  let filled: Bool
  let focusColor: Color?
  let focusedBackgroundColor: Color?
  let helperMaxLines: Int?
  let hintFadeDuration: TimeInterval
  let hintMaxLines: Int?
  let hintStyle: RufletTextStyle?
  let hoverColor: Color?
  let maxMenuHeight: CGFloat?
  let counterText: String?
  let prefixIconConstraints: RufletTextFieldConstraints
  let sizeConstraints: RufletTextFieldConstraints
  let suffixIconConstraints: RufletTextFieldConstraints

  @MainActor
  init(control: RufletControl, focused: Bool = false, hovered: Bool = false) {
    alignLabelWithHint = control.boolean("align_label_with_hint", default: false)
    border = parseEnum(
      RufletDropdownM2Border.self, control.string("border"), RufletDropdownM2Border.outline)!
    borderRadius = parseBorderRadius(
      control.dynamicValue("border_radius"),
      RufletBorderRadius(topLeft: 5, topRight: 5, bottomLeft: 5, bottomRight: 5))!
    backgroundColor = parseColor(control.string("bgcolor"))
    collapsed = control.boolean("collapsed", default: false)
    dense = control.boolean("dense", default: false)
    elevation = CGFloat(max(control.integer("elevation", default: 8) ?? 8, 0))
    enableFeedback = control.boolean("enable_feedback") ?? true
    errorMaxLines = control.integer("error_max_lines")
    fillColor = parseColor(control.string("fill_color"))
    filled = control.boolean("filled", default: false)
    focusColor = parseColor(control.string("focus_color"))
    focusedBackgroundColor = parseColor(control.string("focused_bgcolor"))
    helperMaxLines = control.integer("helper_max_lines")
    hintFadeDuration = parseDuration(control.dynamicValue("hint_fade_duration"), 0.2)!
    hintMaxLines = control.integer("hint_max_lines")
    hintStyle = parseTextStyle(control.dynamicValue("hint_style"))
    hoverColor = parseColor(control.string("hover_color"))
    maxMenuHeight = control.number("max_menu_height").map { CGFloat($0) }
    counterText = control.string("counter")?
      .replacingOccurrences(of: "{value_length}", with: "null")
      .replacingOccurrences(of: "{max_length}", with: "None")
      .replacingOccurrences(of: "{symbols_left}", with: "None")
    prefixIconConstraints = RufletTextFieldConstraints(
      control.dynamicValue("prefix_icon_constraints"))
    sizeConstraints = RufletTextFieldConstraints(control.dynamicValue("size_constraints"))
    suffixIconConstraints = RufletTextFieldConstraints(
      control.dynamicValue("suffix_icon_constraints"))
  }

  func resolvedBackgroundColor(focused: Bool, hovered: Bool) -> Color {
    if hovered, let hoverColor { return hoverColor }
    if focused, let focusColor { return focusColor }
    guard filled else { return .clear }
    return fillColor ?? (focused ? focusedBackgroundColor ?? backgroundColor : backgroundColor)
      ?? Color.rufletSystemBackground
  }

  var contentPadding: EdgeInsets {
    if collapsed { return EdgeInsets() }
    if dense { return EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7) }
    return EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
  }
}

private struct RufletDropdownM2Chrome: ViewModifier {
  @ObservedObject var control: RufletControl
  let focused: Bool
  let hovered: Bool
  let presentation: RufletDropdownM2Presentation

  func body(content: Content) -> some View {
    content
      .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
      .padding(parsePadding(control.dynamicValue("content_padding")) ?? presentation.contentPadding)
      .frame(minHeight: control.number("item_height").map { CGFloat($0) })
      .background(presentation.resolvedBackgroundColor(focused: focused, hovered: hovered))
      .clipShape(RufletCornerShape(radius: radius))
      .overlay { border }
      .animation(.linear(duration: presentation.hintFadeDuration), value: focused)
  }

  @ViewBuilder
  private var border: some View {
    switch presentation.border {
    case .none:
      EmptyView()
    case .underline:
      Rectangle().fill(borderColor).frame(height: borderWidth)
        .frame(maxHeight: .infinity, alignment: .bottom)
    case .outline:
      RufletCornerShape(radius: radius).stroke(borderColor, lineWidth: borderWidth)
    }
  }

  private var radius: RufletBorderRadius {
    if presentation.border == .underline { return .zero }
    return parseBorderRadius(control.dynamicValue("border_radius"),
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

private struct RufletDropdownM2ConstraintsModifier: ViewModifier {
  let constraints: RufletTextFieldConstraints
  init(_ constraints: RufletTextFieldConstraints) { self.constraints = constraints }
  func body(content: Content) -> some View {
    content.frame(
      minWidth: constraints.minWidth, maxWidth: constraints.maxWidth,
      minHeight: constraints.minHeight, maxHeight: constraints.maxHeight)
  }
}

enum RufletDropdownM2Border: String, CaseIterable, RufletStringEnum {
  case outline, underline, none
}

private enum RufletDropdownM2Error: Error {
  case unknownMethod(String)
}
