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
  @Environment(\.rufletPageBackgroundColor) private var pageBackgroundColor
  @Environment(\.rufletPageTheme) private var pageTheme
  let style: Style
  @State private var value: String
  @State private var focused = false
  @State private var hovered = false
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
        .frame(width: usesPinnedDefaultWidth ? 300 : nil)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
        .frame(maxHeight: fitParentSize ? .infinity : nil)
        .modifier(RufletTextFieldConstraintsModifier(presentation.sizeConstraints))
        .modifier(RufletTextFieldClipModifier(behavior: presentation.clipBehavior))
        .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
        .modifier(RufletTextFieldShadowModifier(shadows: presentation.shadows))
        .allowsHitTesting(!control.boolean("ignore_pointers", default: false))
        .onHover { hovered = $0 }
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  private var chrome: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        if style == .form, let icon = control.buildIconOrWidget("icon") { icon }
        HStack(spacing: 6) {
          if style == .form, let prefix = control.buildIconOrWidget("prefix_icon") {
            prefix.modifier(RufletTextFieldConstraintsModifier(presentation.prefixIconConstraints))
          }
          if presentation.isVisible(presentation.prefixVisibilityMode, focused: focused),
             let prefix = control.buildTextOrWidget("prefix") {
            prefix.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("prefix_style"))))
          }

          inputLayer
            .frame(minHeight: minimumNativeHeight)

          if password && control.boolean("can_reveal_password", default: false) {
            Button { revealPassword.toggle() } label: {
              Image(systemName: revealPassword ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(revealPassword ? "Hide password" : "Show password"))
          } else if style == .form, let suffix = control.buildIconOrWidget("suffix_icon") {
            suffix.modifier(RufletTextFieldConstraintsModifier(presentation.suffixIconConstraints))
          }
          if presentation.isVisible(presentation.suffixVisibilityMode, focused: focused),
             let suffix = control.buildTextOrWidget("suffix") {
            suffix.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("suffix_style"))))
          }
        }
        .padding(inputPadding)
        .background(inputBackground)
        .overlay { inputBorder }
        .clipShape(RufletCornerShape(radius: borderRadius))
        .overlay(alignment: .topLeading) { floatingLabel }
        .animation(.linear(duration: presentation.hintFadeDuration), value: focused)
      }

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
      // A platform-view representable is vertically flexible by default and so
      // absorbs all slack a Column hands down. Flutter sizes a non-multiline
      // EditableText to its line metrics instead.
      .fixedSize(horizontal: false, vertical: !fitParentSize && !multiline)
  }

  private var inputLayer: some View {
    ZStack(alignment: presentation.textVerticalAlignment.swiftUI) {
      nativeInput
      if style == .form, hasVisibleLabel, !labelFloats,
         let label = control.buildTextOrWidget("label") {
        label
          .modifier(RufletTextStyleModifier(style: resolvedLabelStyle(floating: false)))
          .foregroundStyle(inlineLabelColor)
          .frame(
            maxWidth: .infinity,
            alignment: presentation.alignLabelWithHint && multiline ? .topLeading : .leading)
          .allowsHitTesting(false)
      }
      if value.isEmpty, let placeholder {
        Text(placeholder)
          .modifier(RufletTextStyleModifier(style: presentation.placeholderStyle))
          .foregroundStyle(presentation.placeholderStyle?.color ?? .secondary)
          .lineLimit(presentation.hintMaxLines)
          .frame(maxWidth: .infinity, alignment: configuration.textAlignment.rufletSwiftUIAlignment)
          .opacity(placeholderIsVisible ? 1 : 0)
          .allowsHitTesting(false)
      }
    }
  }

  @ViewBuilder
  private var floatingLabel: some View {
    if style == .form, labelFloats, let label = control.buildTextOrWidget("label") {
      label
        .modifier(RufletTextStyleModifier(style: resolvedLabelStyle(floating: true)))
        .foregroundStyle(floatingLabelColor)
        .padding(.horizontal, 4)
        .background(floatingLabelBackground)
        .offset(x: 8, y: -7)
        .allowsHitTesting(false)
    }
  }

  @ViewBuilder
  private var supportingRow: some View {
    let error = control.buildTextOrWidget("error")
    let helper = control.buildTextOrWidget("helper")
    // Material only lays out the subtext line when it has content; an always
    // present row adds a caption-height band under every field.
    if error != nil || helper != nil || control.value("counter") != nil {
      supportingContent(error: error, helper: helper)
    }
  }

  @ViewBuilder
  private func supportingContent(error: AnyView?, helper: AnyView?) -> some View {
    HStack(alignment: .top) {
      if let error {
        error.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("error_style"))))
          .foregroundStyle(Color.red)
          .lineLimit(presentation.errorMaxLines)
      } else if let helper {
        helper.modifier(RufletTextStyleModifier(style: parseTextStyle(control.dynamicValue("helper_style"))))
          .lineLimit(presentation.helperMaxLines)
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
    ZStack {
      if let gradient = style == .cupertino ? parseGradient(control.dynamicValue("gradient")) : nil {
        RufletGradientShapeStyle(gradient: gradient)
      } else {
        effectiveBackgroundColor
      }
      if let image = presentation.decorationImage {
        RufletImageSourceView(
          source: image.source,
          contentMode: image.fit.contentMode,
          onError: nil,
          resizingMode: image.repeatMode.resizingMode,
          interpolation: image.quality.interpolation,
          antiAlias: image.antiAlias,
          tint: image.tint,
          svgFit: image.fit)
          .opacity(image.opacity)
          .scaleEffect(image.scale)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: image.alignment)
          .blendMode(image.colorBlendMode)
          .modifier(RufletTextFieldInvertModifier(enabled: image.invertColors))
          .flipsForRightToLeftLayoutDirection(image.matchTextDirection)
      }
    }
    .blendMode(presentation.blendMode)
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
      fontSize: control.number("text_size") ?? styleDetails?.size
        ?? (style == .form ? 16 : 17),
      fontFamily: styleDetails?.fontFamily,
      fontWeight: styleDetails?.weight,
      italic: styleDetails?.italic ?? false,
      textColor: activeTextColor,
      cursorColor: presentation.hasError
        ? parseColor(control.string("cursor_error_color")) ?? parseColor(control.string("cursor_color"))
        : parseColor(control.string("cursor_color")),
      cursorHeight: presentation.cursorHeight,
      cursorWidth: presentation.cursorWidth,
      cursorRadius: presentation.cursorRadius,
      animateCursorOpacity: presentation.animateCursorOpacity,
      selectionColor: parseColor(control.string("selection_color")),
      placeholder: nil,
      placeholderColor: presentation.placeholderStyle?.color,
      scrollPadding: presentation.scrollPadding,
      textVerticalAlignment: presentation.textVerticalAlignment,
      strutStyle: presentation.strutStyle,
      enableStylusHandwriting: presentation.enableStylusHandwriting,
      clearButtonSemanticsLabel: presentation.clearButtonSemanticsLabel,
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
  private var presentation: RufletTextFieldPresentation {
    RufletTextFieldPresentation(control: control, style: style)
  }
  private var placeholderIsVisible: Bool {
    style == .cupertino || !hasVisibleLabel || labelFloats
  }
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
    rufletFormFieldDensityAdjustedPadding(
      presentation.contentPadding,
      verticalOffset: style == .form ? effectiveDensityVerticalOffset : 0)
  }
  private var borderKind: RufletFormFieldBorder {
    parseEnum(RufletFormFieldBorder.self, control.string("border"), .outline)!
  }
  private var borderRadius: RufletBorderRadius {
    if borderKind == .underline { return .zero }
    let defaultRadius: Double = style == .cupertino ? 8 : 4
    return parseBorderRadius(control.dynamicValue("border_radius"),
      RufletBorderRadius(
        topLeft: defaultRadius,
        topRight: defaultRadius,
        bottomLeft: defaultRadius,
        bottomRight: defaultRadius))!
  }
  private var activeBorderWidth: CGFloat {
    if style == .cupertino, control.number("border_width") == nil {
      return focused ? 1 : 0.5
    }
    return CGFloat(focused
      ? control.number("focused_border_width") ?? control.number("border_width") ?? 2
      : control.number("border_width") ?? 1)
  }
  private var activeBorderColor: Color {
    parseColor(focused
      ? control.string("focused_border_color") ?? control.string("border_color")
      : control.string("border_color"))
      ?? (focused ? .accentColor : (style == .cupertino ? Color.secondary.opacity(0.35) : .black))
  }
  private var activeBackgroundColor: Color {
    parseColor(focused
      ? control.string("focused_bgcolor") ?? control.string("fill_color") ?? control.string("bgcolor")
      : control.string("fill_color") ?? control.string("bgcolor"))
      ?? (style == .cupertino ? Color.secondary.opacity(0.1) : .clear)
  }
  private var effectiveBackgroundColor: Color {
    if hovered, let color = presentation.hoverColor { return color }
    if focused, let color = presentation.focusColor { return color }
    if style == .form, !presentation.filled { return .clear }
    return activeBackgroundColor
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

  private var hasVisibleLabel: Bool {
    control.child("label") != nil || control.string("label") != nil
  }
  private var labelFloats: Bool {
    rufletTextFieldLabelFloats(
      hasLabel: hasVisibleLabel,
      focused: focused,
      isEmpty: value.isEmpty)
  }
  private var inlineLabelColor: Color {
    parseTextStyle(control.dynamicValue("label_style"))?.color ?? .secondary
  }
  private var floatingLabelColor: Color {
    parseTextStyle(control.dynamicValue("label_style"))?.color
      ?? (focused ? .accentColor : .secondary)
  }
  private var floatingLabelBackground: Color {
    presentation.filled ? effectiveBackgroundColor
      : pageBackgroundColor ?? Color.rufletSystemBackground
  }
  private func resolvedLabelStyle(floating: Bool) -> RufletTextStyle {
    let explicit = parseTextStyle(control.dynamicValue("label_style"))
    return RufletTextStyle(
      size: explicit?.size ?? (floating ? 12 : 16),
      weight: explicit?.weight,
      italic: explicit?.italic ?? false,
      fontFamily: explicit?.fontFamily,
      height: explicit?.height,
      decoration: explicit?.decoration ?? 0,
      decorationColor: explicit?.decorationColor,
      decorationThickness: explicit?.decorationThickness,
      color: explicit?.color,
      backgroundColor: explicit?.backgroundColor,
      letterSpacing: explicit?.letterSpacing,
      wordSpacing: explicit?.wordSpacing,
      overflow: explicit?.overflow)
  }
  private var parentStretchesHorizontally: Bool {
    guard let parent = control.parent else { return false }
    return ["Column", "View"].contains(parent.type)
      && parent.string("horizontal_alignment")?.lowercased() == "stretch"
  }
  private var expandFactor: Int {
    parseExpand(control.dynamicValue("expand"), 0) ?? 0
  }
  private var usesPinnedDefaultWidth: Bool {
    rufletTextFieldUsesDefaultWidth(
      hasExplicitWidth: control.number("width") != nil,
      expandFactor: expandFactor,
      parentCrossAxisStretch: parentStretchesHorizontally)
  }
  private var fillsAvailableWidth: Bool {
    expandFactor > 0 || parentStretchesHorizontally
  }
  private var effectiveDensityVerticalOffset: CGFloat {
    #if os(macOS)
      let desktop = true
    #else
      let desktop = false
    #endif
    return rufletFormFieldDensityVerticalOffset(pageTheme?.visualDensity, desktop: desktop)
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

func rufletTextFieldLabelFloats(
  hasLabel: Bool,
  focused: Bool,
  isEmpty: Bool
) -> Bool {
  hasLabel && (focused || !isEmpty)
}

func rufletTextFieldUsesDefaultWidth(
  hasExplicitWidth: Bool,
  expandFactor: Int,
  parentCrossAxisStretch: Bool
) -> Bool {
  !hasExplicitWidth && expandFactor <= 0 && !parentCrossAxisStretch
}

func rufletFormFieldDensityVerticalOffset(
  _ density: RufletVisualDensity?,
  desktop: Bool
) -> CGFloat {
  switch density {
  case .compact: return -8
  case .comfortable: return -4
  case .adaptivePlatformDensity: return desktop ? -8 : 0
  case .standard: return 0
  case nil: return desktop ? -8 : 0
  }
}

func rufletFormFieldDensityAdjustedPadding(
  _ padding: EdgeInsets,
  verticalOffset: CGFloat
) -> EdgeInsets {
  let half = verticalOffset / 2
  return EdgeInsets(
    top: max(padding.top + half, 0),
    leading: padding.leading,
    bottom: max(padding.bottom + half, 0),
    trailing: padding.trailing)
}

private enum RufletFormFieldBorder: String, CaseIterable, RufletStringEnum {
  case outline, underline, none
}

private enum RufletTextFieldError: Error {
  case unknownMethod(String)
}

struct RufletTextFieldConstraints: Equatable {
  let minWidth: CGFloat?
  let maxWidth: CGFloat?
  let minHeight: CGFloat?
  let maxHeight: CGFloat?

  init(_ value: Any?) {
    let values = rufletDictionary(value)
    minWidth = parseDouble(values?["min_width"]).map { CGFloat($0) }
    maxWidth = parseDouble(values?["max_width"]).map { CGFloat($0) }
    minHeight = parseDouble(values?["min_height"]).map { CGFloat($0) }
    maxHeight = parseDouble(values?["max_height"]).map { CGFloat($0) }
  }
}

private struct RufletTextFieldConstraintsModifier: ViewModifier {
  let constraints: RufletTextFieldConstraints

  init(_ constraints: RufletTextFieldConstraints) { self.constraints = constraints }

  func body(content: Content) -> some View {
    content.frame(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight)
  }
}

enum RufletTextFieldVerticalAlignment: Equatable {
  case top, center, bottom

  init(_ value: Double?) {
    guard let value else { self = .center; return }
    if value < 0 { self = .top }
    else if value > 0 { self = .bottom }
    else { self = .center }
  }

  var swiftUI: Alignment {
    switch self {
    case .top: .topLeading
    case .center: .leading
    case .bottom: .bottomLeading
    }
  }
}

struct RufletTextFieldStrutStyle: Equatable {
  let size: Double?
  let height: Double?
  let leading: Double?
  let forceHeight: Bool

  init?(_ value: Any?) {
    guard let values = rufletDictionary(value) else { return nil }
    size = parseDouble(values["size"])
    height = parseDouble(values["height"])
    leading = parseDouble(values["leading"])
    forceHeight = parseBool(values["force_strut_height"], false)!
  }

  var lineHeight: CGFloat? {
    guard let size else { return nil }
    return CGFloat(size * (height ?? 1) + (leading ?? 0))
  }
}

struct RufletTextFieldShadow {
  let color: Color
  let radius: CGFloat
  let x: CGFloat
  let y: CGFloat

  init?(_ value: Any?) {
    guard let values = rufletDictionary(value) else { return nil }
    let offset = parseOffset(values["offset"])
    color = parseColor(values["color"] as? String, .black)!
    radius = CGFloat(parseDouble(values["blur_radius"], 0)!)
    x = offset?.width ?? 0
    y = offset?.height ?? 0
  }
}

struct RufletTextFieldDecorationImage {
  let source: RufletImageSource
  let fit: RufletImageFit
  let repeatMode: RufletImageRepeat
  let quality: RufletFilterQuality
  let alignment: Alignment
  let scale: CGFloat
  let opacity: Double
  let antiAlias: Bool
  let invertColors: Bool
  let matchTextDirection: Bool
  let tint: Color?
  let colorBlendMode: BlendMode

  @MainActor
  init?(_ value: Any?, control: RufletControl) {
    guard let values = rufletDictionary(value),
          let source = parseImageSource(values["src"], backend: control.backend)
    else { return nil }
    self.source = source
    fit = parseEnum(RufletImageFit.self, values["fit"] as? String, .fill)!
    repeatMode = parseEnum(RufletImageRepeat.self, values["repeat"] as? String, .noRepeat)!
    quality = parseEnum(RufletFilterQuality.self, values["filter_quality"] as? String, .medium)!
    alignment = parseAlignment(values["alignment"], .center)!.swiftUI
    scale = CGFloat(parseDouble(values["scale"], 1)!)
    opacity = parseDouble(values["opacity"], 1)!
    antiAlias = parseBool(values["anti_alias"], false)!
    invertColors = parseBool(values["invert_colors"], false)!
    matchTextDirection = parseBool(values["match_text_direction"], false)!
    let colorFilter = rufletDictionary(values["color_filter"])
    tint = parseColor(colorFilter?["color"] as? String)
    colorBlendMode = rufletTextFieldBlendMode(colorFilter?["blend_mode"] as? String)
  }
}

@MainActor
struct RufletTextFieldPresentation {
  let alignLabelWithHint: Bool
  let animateCursorOpacity: Bool
  let clipBehavior: String
  let contentPadding: EdgeInsets
  let cursorHeight: CGFloat?
  let cursorWidth: CGFloat
  let cursorRadius: CGFloat?
  let enableStylusHandwriting: Bool
  let errorMaxLines: Int?
  let filled: Bool
  let focusColor: Color?
  let helperMaxLines: Int?
  let hintFadeDuration: TimeInterval
  let hintMaxLines: Int?
  let hoverColor: Color?
  let mouseCursor: String?
  let placeholderStyle: RufletTextStyle?
  let prefixIconConstraints: RufletTextFieldConstraints
  let prefixVisibilityMode: RufletOverlayVisibilityMode
  let scrollPadding: EdgeInsets
  let shadows: [RufletTextFieldShadow]
  let sizeConstraints: RufletTextFieldConstraints
  let strutStyle: RufletTextFieldStrutStyle?
  let suffixIconConstraints: RufletTextFieldConstraints
  let suffixVisibilityMode: RufletOverlayVisibilityMode
  let textVerticalAlignment: RufletTextFieldVerticalAlignment
  let clearButtonSemanticsLabel: String?
  let decorationImage: RufletTextFieldDecorationImage?
  let blendMode: BlendMode
  let hasError: Bool

  init(control: RufletControl, style: RufletTextInputControl.Style) {
    alignLabelWithHint = control.boolean("align_label_with_hint", default: false)
    #if os(iOS)
    let cursorAnimationDefault = true
    #else
    let cursorAnimationDefault = false
    #endif
    animateCursorOpacity = control.boolean("animate_cursor_opacity", default: cursorAnimationDefault)
    clipBehavior = control.string("clip_behavior", default: "hardEdge") ?? "hardEdge"
    if style == .cupertino {
      contentPadding = parsePadding(control.dynamicValue("padding"))
        ?? EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7)
    } else {
      contentPadding = parsePadding(control.dynamicValue("content_padding"))
        ?? RufletLayoutDefaults.formField(
          outline: control.string("border", default: "outline")?.lowercased() == "outline",
          filled: control.boolean("filled", default: false),
          dense: control.boolean("dense", default: false),
          collapsed: control.boolean("collapsed", default: false))
    }
    cursorHeight = control.number("cursor_height").map { CGFloat($0) }
    cursorWidth = CGFloat(control.number("cursor_width", default: 2) ?? 2)
    cursorRadius = control.number("cursor_radius").map { CGFloat($0) }
      ?? (style == .cupertino ? 2 : nil)
    enableStylusHandwriting = control.boolean("enable_stylus_handwriting", default: true)
    errorMaxLines = control.integer("error_max_lines")
    filled = control.boolean("filled", default: false)
    focusColor = parseColor(control.string("focus_color"))
    helperMaxLines = control.integer("helper_max_lines")
    hintFadeDuration = parseDuration(control.dynamicValue("hint_fade_duration"), 0.2)!
    hintMaxLines = control.integer("hint_max_lines")
    hoverColor = parseColor(control.string("hover_color"))
    mouseCursor = control.string("mouse_cursor")
    if style == .cupertino {
      placeholderStyle = parseTextStyle(control.dynamicValue("placeholder_style"))
        ?? parseTextStyle(control.dynamicValue("label_style"))
    } else {
      placeholderStyle = parseTextStyle(control.dynamicValue("hint_style"))
    }
    prefixIconConstraints = RufletTextFieldConstraints(
      control.dynamicValue("prefix_icon_constraints")
        ?? control.dynamicValue("prefix_icon_size_constraints"))
    prefixVisibilityMode = parseEnum(
      RufletOverlayVisibilityMode.self,
      control.string("prefix_visibility_mode"),
      .always)!
    scrollPadding = parsePadding(
      control.dynamicValue("scroll_padding"),
      EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))!
    let shadowValue = control.dynamicValue("shadows")
    if let values = rufletArray(shadowValue) {
      shadows = values.compactMap(RufletTextFieldShadow.init)
    } else {
      shadows = RufletTextFieldShadow(shadowValue).map { [$0] } ?? []
    }
    sizeConstraints = RufletTextFieldConstraints(control.dynamicValue("size_constraints"))
    strutStyle = RufletTextFieldStrutStyle(control.dynamicValue("strut_style"))
    suffixIconConstraints = RufletTextFieldConstraints(
      control.dynamicValue("suffix_icon_constraints")
        ?? control.dynamicValue("suffix_icon_size_constraints"))
    suffixVisibilityMode = parseEnum(
      RufletOverlayVisibilityMode.self,
      control.string("suffix_visibility_mode"),
      .always)!
    textVerticalAlignment = RufletTextFieldVerticalAlignment(
      control.number("text_vertical_align"))
    clearButtonSemanticsLabel = control.string("clear_button_semantics_label")
    decorationImage = style == .cupertino
      ? RufletTextFieldDecorationImage(control.dynamicValue("image"), control: control)
      : nil
    blendMode = rufletTextFieldBlendMode(control.string("blend_mode"))
    hasError = control.value("error") != nil
  }

  func isVisible(_ mode: RufletOverlayVisibilityMode, focused: Bool) -> Bool {
    switch mode {
    case .never: false
    case .always: true
    case .editing: focused
    case .notEditing: !focused
    }
  }
}

private struct RufletTextFieldClipModifier: ViewModifier {
  let behavior: String

  @ViewBuilder
  func body(content: Content) -> some View {
    switch behavior.replacingOccurrences(of: "_", with: "").lowercased() {
    case "none": content
    case "antialias", "antialiaswithsavelayer": content.clipped(antialiased: true)
    default: content.clipped()
    }
  }
}

private struct RufletTextFieldShadowModifier: ViewModifier {
  let shadows: [RufletTextFieldShadow]

  func body(content: Content) -> some View {
    var result = AnyView(content)
    for shadow in shadows {
      result = AnyView(result.shadow(
        color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y))
    }
    return result
  }
}

private struct RufletTextFieldInvertModifier: ViewModifier {
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled { content.colorInvert() } else { content }
  }
}

private extension TextAlignment {
  var rufletSwiftUIAlignment: Alignment {
    switch self {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }
}

private func rufletTextFieldBlendMode(_ value: String?) -> BlendMode {
  switch value?.lowercased() {
  case "multiply": .multiply
  case "screen": .screen
  case "overlay": .overlay
  case "darken": .darken
  case "lighten": .lighten
  case "colordodge": .colorDodge
  case "colorburn": .colorBurn
  case "softlight": .softLight
  case "hardlight": .hardLight
  case "difference": .difference
  case "exclusion": .exclusion
  case "hue": .hue
  case "saturation": .saturation
  case "color": .color
  case "luminosity": .luminosity
  default: .normal
  }
}
