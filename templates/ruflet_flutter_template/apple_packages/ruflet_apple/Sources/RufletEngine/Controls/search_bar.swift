import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `SearchBarControl` / `SearchAnchor`.
@MainActor
public struct SearchBarControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletSearchBarCoordinator

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletSearchBarCoordinator(control: control))
  }

  public var body: some View {
    LayoutControl(control: control) {
      anchor
        .overlay(alignment: .topLeading) {
          if coordinator.isOpen && !fullScreen {
            suggestionsView
              .offset(y: anchorHeight + 6)
              .zIndex(20)
          }
        }
        .zIndex(coordinator.isOpen ? 20 : 0)
    }
    .sheet(isPresented: openSheetBinding) {
      suggestionsView
    }
    .onAppear { coordinator.mount() }
    .onDisappear { coordinator.unmount() }
    .onChange(of: control.properties) { _ in coordinator.synchronizeFromControl() }
  }

  private var anchor: some View {
    HStack(spacing: 8) {
      if let leading = control.buildWidget("bar_leading") {
        leading
      } else {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      }

      RufletNativeTextInput(
        configuration: nativeConfiguration(
          placeholder: control.string("bar_hint_text"),
          textStyle: widgetStateTextStyle(control.dynamicValue("bar_text_style")),
          hintStyle: widgetStateTextStyle(control.dynamicValue("bar_hint_text_style")),
          scrollPadding: parsePadding(control.dynamicValue("bar_scroll_padding"))
            ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)),
        callbacks: RufletNativeTextInputCallbacks(
          onChange: coordinator.textChanged,
          onSubmit: coordinator.submitted,
          onFocusChange: coordinator.focusChanged,
          onSelectionChange: { _ in },
          onTap: coordinator.tapped,
          onTapOutside: coordinator.tappedOutside)
      )
      .frame(minHeight: 28)

      ForEach(Array(control.buildWidgets("bar_trailing").enumerated()), id: \.offset) { _, item in
        item
      }
    }
    .padding(
      widgetStatePadding(control.dynamicValue("bar_padding"))
        ?? EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
    )
    .frame(minHeight: anchorHeight)
    .modifier(RufletSearchConstraintsModifier(constraints: barConstraints))
    .background(barBackground, in: barShape)
    .overlay { barBorder }
    .shadow(
      color: barShadowColor,
      radius: max(barElevation, 0),
      y: max(barElevation, 0) / 2
    )
    .overlay {
      if coordinator.focused,
        let overlay = widgetStateColor(control.dynamicValue("bar_overlay_color"))
      {
        barShape.fill(overlay).allowsHitTesting(false)
      }
    }
    .opacity(control.disabled ? 0.55 : 1)
  }

  private var suggestionsView: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        if let leading = control.buildWidget("view_leading") {
          leading
        } else {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        }

        RufletNativeTextInput(
          configuration: nativeConfiguration(
            placeholder: control.string("view_hint_text") ?? control.string("bar_hint_text"),
            textStyle: parseTextStyle(control.dynamicValue("view_header_text_style")),
            hintStyle: parseTextStyle(control.dynamicValue("view_hint_text_style")),
            scrollPadding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)),
          callbacks: RufletNativeTextInputCallbacks(
            onChange: coordinator.textChanged,
            onSubmit: coordinator.submitted,
            onFocusChange: coordinator.focusChanged,
            onSelectionChange: { _ in },
            onTap: {},
            onTapOutside: coordinator.tappedOutside)
        )
        .frame(minHeight: max(viewHeaderHeight - 16, 28))

        ForEach(Array(control.buildWidgets("view_trailing").enumerated()), id: \.offset) {
          _, item in
          item
        }
        Button {
          coordinator.closeView()
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close search"))
      }
      .padding(viewBarPadding)
      .frame(minHeight: viewHeaderHeight)

      Divider().overlay(viewDividerColor)

      suggestionControls
        .padding(viewPadding)
    }
    .modifier(RufletSearchConstraintsModifier(constraints: viewConstraints))
    .background(viewBackground, in: viewShape)
    .overlay { viewBorder }
    .shadow(
      color: .black.opacity(0.16), radius: max(viewElevation, 0), y: max(viewElevation, 0) / 2
    )
    .padding(fullScreen ? 16 : 0)
  }

  @ViewBuilder
  private var suggestionControls: some View {
    let suggestions = control.children("controls")
    if suggestions.isEmpty {
      EmptyView()
    } else if control.boolean("shrink_wrap", default: false) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(suggestions, id: \.id) { ControlWidget(control: $0) }
      }
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(suggestions, id: \.id) { ControlWidget(control: $0) }
        }
      }
      .frame(maxHeight: viewConstraints.maxHeight ?? 360)
    }
  }

  private func nativeConfiguration(
    placeholder: String?,
    textStyle: RufletTextStyle?,
    hintStyle: RufletTextStyle?,
    scrollPadding: EdgeInsets
  ) -> RufletNativeTextInputConfiguration {
    var configuration = RufletNativeTextInputConfiguration(
      value: coordinator.value,
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
      keyboardType: control.string("keyboard_type", default: "text") ?? "text",
      capitalization: coordinator.capitalization,
      autocorrect: true,
      enableSuggestions: true,
      smartDashes: true,
      smartQuotes: true,
      maxLength: nil,
      inputFilter: nil,
      textAlignment: .leading,
      fontSize: textStyle?.size,
      fontFamily: textStyle?.fontFamily,
      fontWeight: textStyle?.weight,
      italic: textStyle?.italic ?? false,
      textColor: textStyle?.color,
      cursorColor: nil,
      selectionColor: nil,
      placeholder: placeholder,
      placeholderColor: hintStyle?.color,
      obscuringCharacter: "•",
      clearButtonMode: .editing,
      autofillHints: [],
      shiftEnter: false,
      ignoreUpDownKeys: false,
      keyboardBrightness: nil,
      alwaysCallOnTap: true,
      reportsTapOutside: control.boolean("on_tap_outside_bar", default: false),
      focusRequest: coordinator.focusRequest,
      blurRequest: coordinator.blurRequest)
    configuration.scrollPadding = scrollPadding
    return configuration
  }

  private var activeStates: Set<RufletWidgetState> {
    var result: Set<RufletWidgetState> = []
    if control.disabled { result.insert(.disabled) }
    if coordinator.focused { result.insert(.focused) }
    return result
  }

  private func widgetStateColor(_ value: Any?) -> Color? {
    RufletWidgetStateProperty(
      value,
      converter: { raw in
        if let text = raw as? String { return parseColor(text) }
        if let value = raw as? RufletValue { return parseColor(value.text) }
        return nil
      }
    )
    .resolve(activeStates)
  }

  private func widgetStateDouble(_ value: Any?) -> Double? {
    RufletWidgetStateProperty(value, converter: { parseDouble($0) })
      .resolve(activeStates)
  }

  private func widgetStatePadding(_ value: Any?) -> EdgeInsets? {
    RufletWidgetStateProperty(value, converter: { parsePadding($0) })
      .resolve(activeStates)
  }

  private func widgetStateTextStyle(_ value: Any?) -> RufletTextStyle? {
    RufletWidgetStateProperty(value, converter: { parseTextStyle($0) })
      .resolve(activeStates)
  }

  private func widgetStateBorderSide(_ value: Any?) -> RufletBorderSide? {
    RufletWidgetStateProperty(value, converter: { parseBorderSide($0) })
      .resolve(activeStates)
  }

  private var barBackground: Color {
    widgetStateColor(control.dynamicValue("bar_bgcolor")) ?? .rufletSearchFieldBackground
  }

  private var barShadowColor: Color {
    widgetStateColor(control.dynamicValue("bar_shadow_color")) ?? .black.opacity(0.16)
  }

  private var barElevation: Double {
    widgetStateDouble(control.dynamicValue("bar_elevation")) ?? 0
  }
  private var anchorHeight: CGFloat { max(barConstraints.minHeight ?? 44, 36) }
  private var barConstraints: RufletSearchConstraints {
    RufletSearchConstraints(control.dynamicValue("bar_size_constraints"))
  }
  private var viewConstraints: RufletSearchConstraints {
    RufletSearchConstraints(control.dynamicValue("view_size_constraints"))
  }
  private var barRadius: RufletBorderRadius {
    searchRadius(control.dynamicValue("bar_shape"), defaultValue: 12)
  }
  private var viewRadius: RufletBorderRadius {
    searchRadius(control.dynamicValue("view_shape"), defaultValue: fullScreen ? 0 : 14)
  }
  private var barShape: RufletCornerShape { RufletCornerShape(radius: barRadius) }
  private var viewShape: RufletCornerShape { RufletCornerShape(radius: viewRadius) }
  private var viewBackground: Color {
    parseColor(control.string("view_bgcolor")) ?? .rufletSearchViewBackground
  }
  private var viewDividerColor: Color {
    parseColor(control.string("divider_color")) ?? .secondary.opacity(0.25)
  }
  private var viewPadding: EdgeInsets {
    parsePadding(control.dynamicValue("view_padding")) ?? EdgeInsets()
  }
  private var viewBarPadding: EdgeInsets {
    parsePadding(control.dynamicValue("view_bar_padding"))
      ?? EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
  }
  private var viewHeaderHeight: CGFloat {
    CGFloat(control.number("view_header_height", default: 56) ?? 56)
  }
  private var viewElevation: Double { control.number("view_elevation", default: 8) ?? 8 }
  private var fullScreen: Bool { control.boolean("full_screen", default: false) }

  @ViewBuilder private var barBorder: some View {
    if let side = widgetStateBorderSide(control.dynamicValue("bar_border_side")) {
      barShape.stroke(side.color, lineWidth: side.width)
    }
  }

  @ViewBuilder private var viewBorder: some View {
    if let side = parseBorderSide(control.dynamicValue("view_side")) {
      viewShape.stroke(side.color, lineWidth: side.width)
    }
  }

  private var openSheetBinding: Binding<Bool> {
    Binding(
      get: { coordinator.isOpen && fullScreen },
      set: { if !$0 { coordinator.closeView() } })
  }

  private func searchRadius(_ value: Any?, defaultValue: Double) -> RufletBorderRadius {
    let dictionary = rufletDictionary(value)
    return parseBorderRadius(dictionary?["radius"] ?? dictionary?["border_radius"] ?? value)
      ?? RufletBorderRadius(
        topLeft: defaultValue, topRight: defaultValue,
        bottomLeft: defaultValue, bottomRight: defaultValue)
  }
}

@MainActor
final class RufletSearchBarCoordinator: ObservableObject {
  @Published private(set) var value: String
  @Published private(set) var isOpen = false
  @Published private(set) var focused = false
  @Published private(set) var focusRequest = 0
  @Published private(set) var blurRequest = 0

  let control: RufletControl
  private var invokeToken: UUID?
  private var lastFocusValue: String?
  private var lastBlurValue: String?

  init(control: RufletControl) {
    self.control = control
    value = control.string("value", default: "") ?? ""
  }

  var capitalization: RufletTextCapitalization {
    parseEnum(
      RufletTextCapitalization.self,
      control.string("capitalization"),
      RufletTextCapitalization.none) ?? RufletTextCapitalization.none
  }

  func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, args in
      guard let self else { return .null }
      return try self.invoke(name, args: args)
    }
    synchronizeFromControl()
  }

  func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  func synchronizeFromControl() {
    let next = control.string("value", default: "") ?? ""
    if value != next { value = next }

    let focusValue = control.string("focus")
    if let focusValue, focusValue != lastFocusValue {
      lastFocusValue = focusValue
      focusRequest &+= 1
    }
    let blurValue = control.string("blur")
    if let blurValue, blurValue != lastBlurValue {
      lastBlurValue = blurValue
      blurRequest &+= 1
    }
  }

  func textChanged(_ next: String) {
    let normalized = applySearchBarCapitalization(next, capitalization)
    guard value != normalized else { return }
    value = normalized
    control.updateProperties(["value": .string(normalized)])
    if control.boolean("on_change", default: false) {
      control.triggerEvent("change", data: .string(normalized))
    }
  }

  func submitted(_ next: String) {
    textChanged(next)
    if control.boolean("on_submit", default: false) {
      control.triggerEvent("submit", data: .string(value))
    }
  }

  func tapped() {
    isOpen = true
    if control.boolean("on_tap", default: false) { control.triggerEvent("tap") }
  }

  func tappedOutside() {
    guard control.boolean("on_tap_outside_bar", default: false) else { return }
    control.triggerEvent("tap_outside_bar")
  }

  func focusChanged(_ next: Bool) {
    guard focused != next else { return }
    focused = next
    if next { isOpen = true }
    control.triggerEvent(next ? "focus" : "blur")
  }

  func closeView(text: String? = nil) {
    if let text {
      let normalized = applySearchBarCapitalization(text, capitalization)
      if value != normalized {
        value = normalized
        control.updateProperties(["value": .string(normalized)])
      }
    }
    isOpen = false
  }

  func invoke(_ name: String, args: RufletValue) throws -> RufletValue {
    switch name {
    case "close_view":
      if isOpen { closeView(text: args.map?["text"]?.text) }
    case "open_view":
      if !isOpen { isOpen = true }
    case "focus":
      focusRequest &+= 1
    default:
      throw RufletSearchBarError.unknownMethod(name)
    }
    return .null
  }
}

enum RufletSearchBarError: Error, Equatable {
  case unknownMethod(String)
}

/// The pinned SearchBar has its own capitalization implementation: words and
/// sentences lowercase their remaining characters, unlike the shared text
/// input formatter which preserves the remainder's casing.
func applySearchBarCapitalization(
  _ value: String,
  _ capitalization: RufletTextCapitalization
) -> String {
  switch capitalization {
  case .words:
    return value.split(whereSeparator: \.isWhitespace).map { word in
      guard let first = word.first else { return "" }
      return String(first).uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
  case .sentences:
    return value.components(separatedBy: ". ").map { sentence in
      guard let first = sentence.firstIndex(where: { !$0.isWhitespace }) else { return sentence }
      return String(sentence[first]).uppercased()
        + sentence[sentence.index(after: first)...].lowercased()
    }.joined(separator: ". ")
  case .characters:
    return value.uppercased()
  case .none:
    return value
  }
}

private struct RufletSearchConstraints {
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

private struct RufletSearchConstraintsModifier: ViewModifier {
  let constraints: RufletSearchConstraints

  func body(content: Content) -> some View {
    content.frame(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight)
  }
}

extension Color {
  fileprivate static var rufletSearchFieldBackground: Color {
    #if os(iOS)
      Color(uiColor: .secondarySystemFill)
    #else
      Color(nsColor: .controlBackgroundColor)
    #endif
  }

  fileprivate static var rufletSearchViewBackground: Color {
    #if os(iOS)
      Color(uiColor: .systemBackground)
    #else
      Color(nsColor: .windowBackgroundColor)
    #endif
  }
}
