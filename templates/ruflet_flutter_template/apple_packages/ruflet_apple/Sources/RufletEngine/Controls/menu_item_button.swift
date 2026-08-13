import SwiftUI

struct RufletMenuDismissAction {
  let perform: @MainActor () -> Void

  @MainActor
  func callAsFunction() {
    perform()
  }
}

private struct RufletMenuDismissActionKey: EnvironmentKey {
  static let defaultValue = RufletMenuDismissAction(perform: {})
}

extension EnvironmentValues {
  var rufletDismissMenu: RufletMenuDismissAction {
    get { self[RufletMenuDismissActionKey.self] }
    set { self[RufletMenuDismissActionKey.self] = newValue }
  }
}

@MainActor
func rufletActivateMenuItem(
  _ control: RufletControl,
  dismiss: () -> Void = {}
) {
  guard !control.disabled, control.boolean("on_click", default: false) else { return }
  control.triggerEvent("click")
  if control.boolean("close_on_click", default: true) { dismiss() }
}

/// Apple-native port of pinned Flet `menu_item_button.dart`.
@MainActor
public struct MenuItemButtonControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletDismissMenu) private var dismissMenu
  @FocusState private var focused: Bool
  @State private var hovered = false
  @State private var lastFocusValue: String?

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      Button(action: activate) {
        menuItemLabel
      }
      .buttonStyle(
        RufletAppleMenuButtonStyle(
          appearance: RufletMenuButtonAppearance(control: control),
          focused: focused,
          hovered: hovered,
          disabled: control.disabled || !handlesClick)
      )
      .disabled(control.disabled || !handlesClick)
      .focused($focused)
      .onHover(perform: hoverChanged)
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      .onAppear(perform: synchronizeFocus)
      .onChange(of: control.properties) { _ in synchronizeFocus() }
      .accessibilityLabel(control.string("semantics_label") ?? contentText)
    }
  }

  @ViewBuilder
  private var menuItemLabel: some View {
    if overflowAxis == .vertical {
      VStack(spacing: 6) {
        if let leading = control.buildWidget("leading") { leading }
        if let content = control.buildTextOrWidget("content") { content }
        if let trailing = control.buildWidget("trailing_icon") { trailing }
      }
    } else {
      HStack(spacing: 8) {
        if let leading = control.buildWidget("leading") { leading }
        if let content = control.buildTextOrWidget("content") { content }
        Spacer(minLength: 8)
        if let trailing = control.buildWidget("trailing_icon") { trailing }
      }
    }
  }

  private func activate() {
    rufletActivateMenuItem(control) { dismissMenu() }
  }

  private func hoverChanged(_ value: Bool) {
    hovered = value
    guard !control.disabled else { return }
    if control.boolean("focus_on_hover", default: true), value { focused = true }
    if control.boolean("on_hover", default: false) {
      control.triggerEvent("hover", data: .bool(value))
    }
  }

  private func synchronizeFocus() {
    if control.boolean("autofocus", default: false), lastFocusValue == nil {
      focused = true
    }
    guard let value = control.string("focus"), value != lastFocusValue else { return }
    lastFocusValue = value
    focused = true
  }

  private var handlesClick: Bool { control.boolean("on_click", default: false) }
  private var contentText: String { control.string("content", default: "")! }
  private var overflowAxis: Axis {
    control.string("overflow_axis")?.lowercased() == "vertical" ? .vertical : .horizontal
  }
}

struct RufletMenuButtonAppearance {
  let foreground: RufletWidgetStateProperty<Color>
  let background: RufletWidgetStateProperty<Color>
  let overlay: RufletWidgetStateProperty<Color>
  let shadow: RufletWidgetStateProperty<Color>
  let elevation: RufletWidgetStateProperty<Double>
  let padding: RufletWidgetStateProperty<EdgeInsets>
  let side: RufletWidgetStateProperty<RufletBorderSide>
  let minimumSize: RufletWidgetStateProperty<CGSize>
  let maximumSize: RufletWidgetStateProperty<CGSize>
  let fixedSize: RufletWidgetStateProperty<CGSize>
  let textStyle: RufletWidgetStateProperty<RufletTextStyle>
  let radius: Double
  let alignment: Alignment
  let clipBehavior: String

  @MainActor
  init(control: RufletControl) {
    let details =
      rufletDictionary(
        control.internals?["style"].map(rufletAny) ?? control.dynamicValue("style")) ?? [:]
    foreground = .init(
      details["color"], converter: { parseColor($0 as? String) }, defaultValue: .accentColor)
    background = .init(
      details["bgcolor"], converter: { parseColor($0 as? String) }, defaultValue: .clear)
    overlay = .init(
      details["overlay_color"], converter: { parseColor($0 as? String) }, defaultValue: .clear)
    shadow = .init(
      details["shadow_color"], converter: { parseColor($0 as? String) }, defaultValue: .clear)
    elevation = .init(details["elevation"], converter: { parseDouble($0) }, defaultValue: 0)
    padding = .init(
      details["padding"], converter: { parsePadding($0) },
      defaultValue: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    side = .init(details["side"], converter: { parseBorderSide($0) })
    minimumSize = .init(details["minimum_size"], converter: { parseSize($0) })
    maximumSize = .init(details["maximum_size"], converter: { parseSize($0) })
    fixedSize = .init(details["fixed_size"], converter: { parseSize($0) })
    textStyle = .init(details["text_style"], converter: { parseTextStyle($0) })
    radius = Self.radius(details["shape"])
    alignment = parseAlignment(details["alignment"], .center)!.swiftUI
    clipBehavior = control.string("clip_behavior", default: "none")!.lowercased()
  }

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }

  private static func radius(_ value: Any?) -> Double {
    guard let details = rufletDictionary(value) else {
      return parseDouble(value, 8) ?? 8
    }
    return parseBorderRadius(
      details["border_radius"] ?? details["radius"] ?? details,
      RufletBorderRadius(topLeft: 8, topRight: 8, bottomLeft: 8, bottomRight: 8))?.uniform ?? 8
  }
}

struct RufletAppleMenuButtonStyle: ButtonStyle {
  let appearance: RufletMenuButtonAppearance
  let focused: Bool
  let hovered: Bool
  let disabled: Bool
  var splashRadius: CGFloat? = nil

  func makeBody(configuration: Configuration) -> some View {
    let states = states(configuration: configuration)
    let foreground = appearance.foreground.resolve(states) ?? .accentColor
    let background = appearance.background.resolve(states) ?? .clear
    let overlay = appearance.overlay.resolve(states) ?? .clear
    let elevation = appearance.elevation.resolve(states) ?? 0
    let shadow = appearance.shadow.resolve(states) ?? .clear
    let padding = appearance.padding.resolve(states) ?? EdgeInsets()
    let side = appearance.side.resolve(states)
    let fixed = appearance.fixedSize.resolve(states)
    let minimum = appearance.minimumSize.resolve(states)
    let maximum = appearance.maximumSize.resolve(states)

    let shape = RoundedRectangle(cornerRadius: appearance.radius, style: .continuous)
    return configuration.label
      .modifier(RufletTextStyleModifier(style: appearance.textStyle.resolve(states)))
      .foregroundStyle(foreground)
      .padding(padding)
      .frame(width: fixed?.width, height: fixed?.height)
      .frame(
        minWidth: minimum?.width,
        maxWidth: maximum?.width,
        minHeight: minimum?.height,
        maxHeight: maximum?.height,
        alignment: appearance.alignment
      )
      .background(background, in: shape)
      .background(overlay.opacity(configuration.isPressed || hovered ? 1 : 0), in: shape)
      .modifier(RufletMenuItemClipModifier(shape: shape, appearance: appearance))
      .overlay {
        if let side {
          shape.stroke(side.color, lineWidth: side.width)
        }
        if configuration.isPressed, let splashRadius {
          Circle()
            .fill(Color.accentColor.opacity(0.12))
            .frame(width: splashRadius * 2, height: splashRadius * 2)
            .allowsHitTesting(false)
        }
      }
      .shadow(color: shadow, radius: max(elevation, 0), y: max(elevation, 0) / 2)
      .opacity(disabled ? 0.45 : 1)
      .contentShape(shape)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }

  private func states(configuration: Configuration) -> Set<RufletWidgetState> {
    var result = Set<RufletWidgetState>()
    if configuration.isPressed { result.insert(.pressed) }
    if focused { result.insert(.focused) }
    if hovered { result.insert(.hovered) }
    if disabled { result.insert(.disabled) }
    return result
  }
}

private struct RufletMenuItemClipModifier: ViewModifier {
  let shape: RoundedRectangle
  let appearance: RufletMenuButtonAppearance

  @ViewBuilder
  func body(content: Content) -> some View {
    if appearance.clipsContent {
      content.clipShape(shape, style: FillStyle(antialiased: appearance.antialiasedClip))
    } else {
      content
    }
  }
}
