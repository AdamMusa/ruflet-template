import SwiftUI

@MainActor
public struct CupertinoButtonControl: View {
  @ObservedObject public var control: RufletControl
  @FocusState private var focused: Bool
  @StateObject private var focusCoordinator = RufletCupertinoButtonFocusCoordinator()

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletCupertinoButtonPresentation(control: control)
    LayoutControl(control: control) {
      Button(action: pressed) {
        HStack(spacing: 8) {
          control.buildIconOrWidget("icon", color: presentation.iconColor)
          control.buildTextOrWidget("content")
        }
        .font(presentation.size.font)
        .foregroundStyle(presentation.foregroundColor)
        .padding(presentation.padding)
        .frame(
          minWidth: presentation.minimumSize.width,
          minHeight: presentation.minimumSize.height,
          alignment: presentation.alignment.swiftUI)
        .background(presentation.backgroundColor(disabled: control.disabled))
        .clipShape(RufletCornerShape(radius: presentation.borderRadius))
        .overlay {
          if focused {
            RufletCornerShape(radius: presentation.borderRadius)
              .stroke(presentation.focusColor, lineWidth: 3.5)
          }
        }
      }
      .buttonStyle(RufletPressedOpacityStyle(opacity: presentation.pressedOpacity))
      .disabled(control.disabled)
      .focused($focused)
      .simultaneousGesture(LongPressGesture().onEnded { _ in
        if !control.disabled { control.triggerEvent("long_press") }
      })
      .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      .onChange(of: focusCoordinator.focusRequest) { _ in focused = true }
      .onAppear {
        focusCoordinator.attach(to: control)
        if presentation.autofocus { focused = true }
      }
      .onDisappear { focusCoordinator.detach(from: control) }
      .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
    }
  }

  func pressed() {
    guard !control.disabled else { return }
    if let url = parseURL(control.dynamicValue("url")) { Task { await openURL(url) } }
    control.triggerEvent("click")
  }
}

enum RufletCupertinoButtonSize: String, CaseIterable, RufletStringEnum {
  case small, medium, large

  var minimumDimension: CGFloat {
    switch self {
    case .small: return 28
    case .medium: return 32
    case .large: return 44
    }
  }

  var padding: EdgeInsets {
    switch self {
    case .small: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    case .medium: return EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
    case .large: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
    }
  }

  var radius: CGFloat {
    switch self {
    case .small, .medium: return 40
    case .large: return 12
    }
  }

  var font: Font {
    switch self {
    case .small: return .subheadline
    case .medium, .large: return .body
    }
  }
}

enum RufletCupertinoButtonVariant: Equatable {
  case plain, filled, tinted
}

@MainActor
struct RufletCupertinoButtonPresentation {
  let variant: RufletCupertinoButtonVariant
  let size: RufletCupertinoButtonSize
  let autofocus: Bool
  let disabledBackgroundColor: Color
  let focusColor: Color
  let mouseCursor: String?
  let iconColor: Color?
  let foregroundColor: Color
  let enabledBackgroundColor: Color
  let minimumSize: CGSize
  let padding: EdgeInsets
  let alignment: RufletAlignment
  let borderRadius: RufletBorderRadius
  let pressedOpacity: Double

  init(control: RufletControl) {
    switch control.type.lowercased() {
    case "cupertinofilledbutton", "filledbutton": variant = .filled
    case "cupertinotintedbutton", "filledtonalbutton": variant = .tinted
    default: variant = .plain
    }
    size = parseEnum(
      RufletCupertinoButtonSize.self, control.string("size"), .large) ?? .large
    autofocus = control.boolean("autofocus", default: false)
    disabledBackgroundColor = parseColor(control.string("disabled_bgcolor"))
      ?? Color.secondary.opacity(0.18)
    focusColor = parseColor(control.string("focus_color")) ?? .accentColor
    mouseCursor = control.string("mouse_cursor")
    iconColor = parseColor(control.string("icon_color"))
    let explicitBackground = parseColor(control.string("bgcolor"))
    let explicitForeground = parseColor(control.string("color"))
    switch variant {
    case .filled:
      enabledBackgroundColor = explicitBackground ?? .accentColor
      foregroundColor = explicitForeground ?? .white
    case .tinted:
      enabledBackgroundColor = explicitBackground ?? .accentColor.opacity(0.16)
      foregroundColor = explicitForeground ?? .accentColor
    case .plain:
      enabledBackgroundColor = explicitBackground ?? .clear
      foregroundColor = explicitForeground ?? .accentColor
    }
    let explicitMinimumSize = parseSize(control.dynamicValue("min_size"))
    minimumSize = CGSize(
      width: explicitMinimumSize?.width ?? size.minimumDimension,
      height: explicitMinimumSize?.height ?? size.minimumDimension)
    padding = parsePadding(control.dynamicValue("padding")) ?? size.padding
    alignment = parseAlignment(control.dynamicValue("alignment"), .center) ?? .center
    borderRadius = parseBorderRadius(control.dynamicValue("border_radius"))
      ?? RufletBorderRadius(
        topLeft: size.radius,
        topRight: size.radius,
        bottomLeft: size.radius,
        bottomRight: size.radius)
    pressedOpacity = control.number("opacity_on_click") ?? 0.4
  }

  func backgroundColor(disabled: Bool) -> Color {
    disabled ? disabledBackgroundColor : enabledBackgroundColor
  }
}

private struct RufletPressedOpacityStyle: ButtonStyle {
  let opacity: Double
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? opacity : 1)
  }
}

@MainActor
private final class RufletCupertinoButtonFocusCoordinator: ObservableObject {
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
