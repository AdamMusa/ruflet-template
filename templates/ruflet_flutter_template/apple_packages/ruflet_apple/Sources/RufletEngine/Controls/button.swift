import SwiftUI

@MainActor
public struct ButtonControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletPageTheme) private var pageTheme
  @FocusState private var focused: Bool
  @StateObject private var focusCoordinator = RufletButtonFocusCoordinator()

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      Button(action: pressed) {
        HStack(spacing: 8) {
          control.buildIconOrWidget("icon", color: parseColor(control.string("icon_color")))
          control.buildTextOrWidget("content")
        }
        .environment(\.rufletInheritedIconSize, buttonIconSize)
        .modifier(RufletTextStyleModifier(style: buttonTextStyle))
        .environment(\.rufletInheritedTextStyle, buttonTextStyle)
        .environment(\.rufletInheritsTextColor, true)
        // Flutter hands an expanded or explicitly sized button tight
        // constraints, so its material fills the allocation and only the label
        // centers inside. The label must claim that space here for the styled
        // background to follow.
        .frame(
          maxWidth: fillsAllocation(.horizontal) ? .infinity : nil,
          maxHeight: fillsAllocation(.vertical) ? .infinity : nil)
      }
      .buttonStyle(buttonStyle)
      .disabled(control.disabled)
      .focused($focused)
      .onHover {
        if !control.disabled { control.triggerEvent("hover", data: .bool($0)) }
      }
      .simultaneousGesture(
        LongPressGesture().onEnded { _ in
          if !control.disabled { control.triggerEvent("long_press") }
        }
      )
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      .onChange(of: focusCoordinator.focusRequest) { _ in focused = true }
      .onAppear { focusCoordinator.attach(to: control) }
      .onDisappear { focusCoordinator.detach(from: control) }
    }
  }

  private func fillsAllocation(_ axis: RufletExpansionAxis) -> Bool {
    if rufletExpansionContract(for: control)?.axis == axis { return true }
    return axis == .horizontal
      ? control.number("width") != nil : control.number("height") != nil
  }

  private var variant: RufletButtonVariant {
    switch control.type.lowercased() {
    case "filledbutton": .filled
    case "filledtonalbutton": .tonal
    case "textbutton": .text
    case "outlinedbutton": .outlined
    default: .elevated
    }
  }

  var buttonStyle: RufletAppleButtonStyle {
    let details = rufletDictionary(
      control.internals?["style"].map(rufletAny) ?? control.dynamicValue("style"))
    let explicitForeground =
      parseColor(details?["color"] as? String)
      ?? parseColor(control.string("color"))
    let foreground = explicitForeground ?? defaultForegroundColor
    let background: Color
    switch variant {
    case .filled:
      background =
        parseColor(details?["bgcolor"] as? String) ?? parseColor(control.string("bgcolor"))
        ?? pageTheme?.colorScheme?["primary"] ?? .accentColor
    case .tonal:
      background =
        parseColor(details?["bgcolor"] as? String)
        ?? pageTheme?.colorScheme?["secondary_container"] ?? .accentColor.opacity(0.18)
    case .outlined, .text: background = parseColor(details?["bgcolor"] as? String) ?? .clear
    case .elevated:
      background =
        parseColor(details?["bgcolor"] as? String)
        ?? pageTheme?.colorScheme?["surface_container_low"] ?? .rufletSystemBackground
    }
    let border =
      variant == .outlined
      ? (parseBorderSide(details?["side"], defaultColor: defaultBorderColor)
        ?? RufletBorderSide(width: 1, color: defaultBorderColor))
      : parseBorderSide(details?["side"], defaultColor: foreground)
    let radius =
      parseBorderRadius(details?["shape"] ?? control.dynamicValue("shape"))?.uniform
      ?? ((pageTheme?.useMaterial3WireValue ?? true) ? 1_000 : 4)
    return RufletAppleButtonStyle(
      variant: variant,
      foreground: foreground,
      background: background,
      radius: radius,
      border: border,
      elevation: control.number("elevation") ?? 1,
      clipBehavior: control.string("clip_behavior", default: "none")!.lowercased(),
      disabledColor: pageTheme?.colorScheme?["on_surface"] ?? .secondary
    )
  }

  private var defaultForegroundColor: Color {
    let role: String
    switch variant {
    case .filled: role = "on_primary"
    case .tonal: role = "on_secondary_container"
    case .elevated, .outlined, .text: role = "primary"
    }
    return pageTheme?.colorScheme?[role] ?? (variant == .filled ? .white : .accentColor)
  }

  private var defaultBorderColor: Color {
    pageTheme?.colorScheme?["outline"] ?? defaultForegroundColor
  }

  private var buttonIconSize: CGFloat {
    let details = rufletDictionary(
      control.internals?["style"].map(rufletAny) ?? control.dynamicValue("style"))
    return CGFloat(parseDouble(details?["icon_size"], 18) ?? 18)
  }

  private var buttonTextStyle: RufletTextStyle? {
    let details = rufletDictionary(
      control.internals?["style"].map(rufletAny) ?? control.dynamicValue("style"))
    return mergeTextStyles(
      pageTheme?.textTheme?["label_large"], parseTextStyle(details?["text_style"]))
  }

  private func pressed() {
    guard !control.disabled else { return }
    if let url = parseURL(control.dynamicValue("url")) {
      Task { await openURL(url) }
    }
    control.triggerEvent("click")
  }
}

@MainActor
private final class RufletButtonFocusCoordinator: ObservableObject {
  @Published var focusRequest = 0
  private var token: UUID?

  func attach(to control: RufletControl) {
    guard token == nil else { return }
    token = control.addInvokeMethodListener { [weak self] name, _ in
      guard name == "focus" else { throw RufletControlError.noMethodListener }
      self?.focusRequest += 1
      return .null
    }
  }

  func detach(from control: RufletControl) {
    guard let token else { return }
    control.removeInvokeMethodListener(token)
    self.token = nil
  }
}
