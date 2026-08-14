import SwiftUI

private struct RufletListTileClickNotifierKey: EnvironmentKey {
  static let defaultValue: RufletListTileClickNotifier? = nil
}

extension EnvironmentValues {
  var rufletListTileClickNotifier: RufletListTileClickNotifier? {
    get { self[RufletListTileClickNotifierKey.self] }
    set { self[RufletListTileClickNotifierKey.self] = newValue }
  }
}

@MainActor
final class RufletListTileClickNotifier: ObservableObject {
  private struct Listener {
    let id: UUID
    let callback: () -> Void
  }

  private var listeners: [Listener] = []

  @discardableResult
  func addListener(_ callback: @escaping () -> Void) -> UUID {
    let id = UUID()
    listeners.append(Listener(id: id, callback: callback))
    return id
  }

  func removeListener(_ id: UUID) {
    listeners.removeAll { $0.id == id }
  }

  func onClick() {
    let current = listeners
    for listener in current { listener.callback() }
  }
}

@MainActor
struct RufletListTileActivation {
  let control: RufletControl
  let clickNotifier: RufletListTileClickNotifier

  var isEnabled: Bool {
    !control.disabled
      && (control.boolean("on_click", default: false)
        || control.boolean("toggle_inputs", default: false)
        || parseURL(control.dynamicValue("url")) != nil)
  }

  var enableFeedback: Bool { control.boolean("enable_feedback") ?? true }

  func callAsFunction() {
    guard isEnabled else { return }
    if enableFeedback { performRufletSelectionFeedback() }
    if control.boolean("toggle_inputs", default: false) { clickNotifier.onClick() }
    if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
    if control.boolean("on_click", default: false) { control.triggerEvent("click") }
  }
}

private struct RufletListTileButtonStyle: ButtonStyle {
  let pressedColor: Color
  let radius: RufletBorderRadius

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .overlay {
        if configuration.isPressed {
          RufletCornerShape(radius: radius)
            .fill(pressedColor)
            .allowsHitTesting(false)
        }
      }
      .clipShape(RufletCornerShape(radius: radius))
  }
}

private struct RufletListTileLongPressModifier: ViewModifier {
  let enabled: Bool
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.highPriorityGesture(
        LongPressGesture(minimumDuration: 0.5).onEnded { _ in action() })
    } else {
      content
    }
  }
}

@MainActor
struct RufletListTileInputToggleModifier: ViewModifier {
  @Environment(\.rufletListTileClickNotifier) private var notifier
  @State private var listenerID: UUID?
  @State private var attachedNotifier: RufletListTileClickNotifier?
  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .onAppear(perform: attach)
      .onDisappear(perform: detach)
      .onChange(of: notifier.map(ObjectIdentifier.init)) { _ in
        detach()
        attach()
      }
  }

  private func attach() {
    guard listenerID == nil, let notifier else { return }
    listenerID = notifier.addListener(action)
    attachedNotifier = notifier
  }

  private func detach() {
    if let listenerID { attachedNotifier?.removeListener(listenerID) }
    listenerID = nil
    attachedNotifier = nil
  }
}

/// Apple-native port of pinned `list_tile.dart`.
@MainActor
public struct ListTileControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var clickNotifier = RufletListTileClickNotifier()
  @State private var focused = false
  @State private var hovered = false

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      interactiveTile
        .environment(
          \.rufletListTileClickNotifier,
          control.boolean("toggle_inputs", default: false) ? clickNotifier : nil
        )
    }
  }

  @ViewBuilder
  private var interactiveTile: some View {
    if activation.isEnabled {
      Button(action: activation.callAsFunction) { tileSurface }
        .buttonStyle(RufletListTileButtonStyle(
          pressedColor: splashColor,
          radius: radius))
        .modifier(RufletListTileLongPressModifier(
          enabled: canLongPress,
          action: longPress))
    } else if canLongPress {
      tileSurface.onLongPressGesture(minimumDuration: 0.5, perform: longPress)
    } else {
      tileSurface
    }
  }

  private var tileSurface: some View {
    tileContent
      .padding(.vertical, minimumVerticalPadding)
      .padding(contentPadding)
      .frame(minHeight: minimumHeight)
      .background(backgroundColor)
      .clipShape(RufletCornerShape(radius: radius))
      .overlay { shapeBorder }
      .contentShape(RufletCornerShape(radius: radius))
      .opacity(control.disabled ? 0.5 : 1)
      .overlay {
        RufletNativeFocusTarget(
          enabled: !control.disabled,
          autofocus: control.boolean("autofocus", default: false),
          request: 0,
          onFocusChange: focusChanged
        )
        .frame(width: 0, height: 0)
      }
      .modifier(RufletMouseCursorModifier(cursor: control.string("mouse_cursor")))
      .onHover { hovered = $0 }
  }

  private var tileContent: some View {
    HStack(alignment: rowAlignment, spacing: horizontalSpacing) {
      if let leading = control.buildIconOrWidget("leading", color: iconColor) {
        leading
          .modifier(RufletTextStyleModifier(style: leadingTrailingStyle))
          .frame(minWidth: minimumLeadingWidth, alignment: .center)
      }

      VStack(alignment: .leading, spacing: control.boolean("dense") == true ? 1 : 3) {
        if let title = control.buildTextOrWidget("title") {
          title
            .modifier(RufletTextStyleModifier(style: titleStyle))
            .foregroundStyle(foregroundColor)
        }
        if let subtitle = control.buildTextOrWidget("subtitle") {
          subtitle
            .modifier(RufletTextStyleModifier(style: subtitleStyle))
            .foregroundStyle(subtitleStyle?.color ?? foregroundColor.opacity(0.68))
            .lineLimit(isThreeLine ? 2 : 1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let trailing = control.buildIconOrWidget("trailing", color: iconColor) {
        trailing.modifier(RufletTextStyleModifier(style: leadingTrailingStyle))
      }
    }
  }

  @ViewBuilder
  private var shapeBorder: some View {
    if let side {
      RufletCornerShape(radius: radius).stroke(side.color, lineWidth: side.width)
    }
  }

  private var contentPadding: EdgeInsets {
    parsePadding(control.dynamicValue("content_padding"))
      ?? RufletLayoutDefaults.listTile
  }

  private var isThreeLine: Bool {
    control.boolean("is_three_line", default: false)
  }

  private var minimumVerticalPadding: CGFloat {
    CGFloat(control.number("min_vertical_padding") ?? (control.boolean("dense") == true ? 4 : 8))
  }

  private var minimumHeight: CGFloat {
    if let value = control.number("min_height") { return CGFloat(value) }
    let base: CGFloat = isThreeLine ? 88 : (control.value("subtitle") != nil ? 64 : 48)
    switch parseVisualDensity(control.string("visual_density")) {
    case .compact: return max(base - 8, 40)
    case .comfortable: return max(base - 4, 40)
    default: return base
    }
  }

  private var minimumLeadingWidth: CGFloat {
    CGFloat(control.number("min_leading_width") ?? 24)
  }

  private var horizontalSpacing: CGFloat {
    CGFloat(control.number("horizontal_spacing") ?? 16)
  }

  private var rowAlignment: VerticalAlignment {
    switch control.string("title_alignment")?.lowercased() {
    case "top", "threeline": return .top
    case "bottom": return .bottom
    default: return .center
    }
  }

  private var shape: [String: Any]? {
    rufletDictionary(control.dynamicValue("shape"))
  }

  private var radius: RufletBorderRadius {
    parseBorderRadius(shape?["radius"] ?? shape?["border_radius"], .zero)!
  }

  private var side: RufletBorderSide? {
    parseBorderSide(shape?["side"])
  }

  private var foregroundColor: Color {
    if control.boolean("selected", default: false) {
      return parseColor(control.string("selected_color"))
        ?? parseColor(control.string("text_color")) ?? .primary
    }
    return parseColor(control.string("text_color")) ?? .primary
  }

  private var iconColor: Color {
    parseColor(control.string("icon_color")) ?? foregroundColor
  }

  private var backgroundColor: Color {
    if focused, let color = parseColor(control.string("focus_color")) { return color }
    if hovered, let color = parseColor(control.string("hover_color")) { return color }
    if control.boolean("selected", default: false),
      let color = parseColor(control.string("selected_tile_color"))
    {
      return color
    }
    return parseColor(control.string("bgcolor")) ?? .clear
  }

  private var splashColor: Color {
    parseColor(control.string("splash_color")) ?? .accentColor.opacity(0.12)
  }

  private var titleStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("title_text_style"))
  }

  private var subtitleStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("subtitle_text_style"))
  }

  private var leadingTrailingStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("leading_and_trailing_text_style"))
  }

  private var activation: RufletListTileActivation {
    RufletListTileActivation(control: control, clickNotifier: clickNotifier)
  }

  private var canLongPress: Bool {
    !control.disabled && control.boolean("on_long_press", default: false)
  }

  private func longPress() {
    guard canLongPress else { return }
    control.triggerEvent("long_press")
  }

  private func focusChanged(_ hasFocus: Bool) {
    focused = hasFocus
    control.triggerEvent(hasFocus ? "focus" : "blur")
  }
}
