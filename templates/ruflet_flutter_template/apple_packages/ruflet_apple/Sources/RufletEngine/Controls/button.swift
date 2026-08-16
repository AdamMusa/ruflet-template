import SwiftUI

@MainActor
public struct ButtonControl: View {
  @ObservedObject public var control: RufletControl
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
      .onHover { control.triggerEvent("hover", data: .bool($0)) }
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
    let foreground =
      parseColor(details?["color"] as? String)
      ?? parseColor(control.string("color"))
      ?? .accentColor
    let background: Color
    switch variant {
    case .filled:
      background =
        parseColor(details?["bgcolor"] as? String) ?? parseColor(control.string("bgcolor"))
        ?? .accentColor
    case .tonal:
      background = parseColor(details?["bgcolor"] as? String) ?? .accentColor.opacity(0.18)
    case .outlined, .text: background = parseColor(details?["bgcolor"] as? String) ?? .clear
    case .elevated:
      background = parseColor(details?["bgcolor"] as? String) ?? .rufletSystemBackground
    }
    let border =
      variant == .outlined
      ? (parseBorderSide(details?["side"], defaultColor: foreground)
        ?? RufletBorderSide(width: 1, color: foreground))
      : parseBorderSide(details?["side"], defaultColor: foreground)
    let radius =
      parseBorderRadius(details?["shape"] ?? control.dynamicValue("shape"))?.uniform ?? 20
    return RufletAppleButtonStyle(
      variant: variant,
      foreground: variant == .filled ? .white : foreground,
      background: background,
      radius: radius,
      border: border,
      elevation: control.number("elevation") ?? 1,
      clipBehavior: control.string("clip_behavior", default: "none")!.lowercased()
    )
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
