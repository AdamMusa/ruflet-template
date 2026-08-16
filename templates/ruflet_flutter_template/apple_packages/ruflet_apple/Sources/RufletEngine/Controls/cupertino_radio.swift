import SwiftUI

/// Apple-native port of pinned Flet `cupertino_radio.dart`.
@MainActor
public struct CupertinoRadioControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletRadioGroupBinding) private var groupSelection
  @FocusState private var focused: Bool

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    guard groupSelection != nil else {
      return AnyView(ErrorControl("CupertinoRadio must be enclosed within RadioGroup"))
    }
    let presentation = RufletCupertinoRadioPresentation(control: control)
    return AnyView(
      LayoutControl(control: control) {
        Button(action: select) {
          HStack(spacing: 0) {
            if presentation.labelPosition == .left { label }
            RufletCupertinoRadioArtwork(
              control: control,
              presentation: presentation,
              selected: selected,
              focused: focused)
            if presentation.labelPosition == .right { label }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(RufletCupertinoRadioButtonStyle())
        .disabled(control.disabled)
        .focused($focused)
        .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
        .accessibilityElement(children: .combine)
        .accessibilityValue(selected ? "selected" : "not selected")
        .onAppear {
          if presentation.autofocus { focused = true }
        }
        .onChange(of: focused) { control.triggerEvent($0 ? "focus" : "blur") }
      })
  }

  private var selected: Bool {
    groupSelection?.wrappedValue == control.string("value", default: "")!
  }

  @ViewBuilder
  private var label: some View {
    if let value = control.string("label"), !value.isEmpty {
      Text(value).opacity(control.disabled ? 0.55 : 1)
    }
  }

  private func select() {
    guard !control.disabled, let groupSelection else { return }
    rufletActivateRadio(
      selection: groupSelection,
      selected: selected,
      toggleable: control.boolean("toggleable", default: false),
      value: control.string("value", default: "")!)
  }
}

@MainActor
private struct RufletCupertinoRadioArtwork: View {
  @ObservedObject var control: RufletControl
  let presentation: RufletCupertinoRadioPresentation
  let selected: Bool
  let focused: Bool
  @Environment(\.rufletCupertinoRadioPressed) private var pressed

  var body: some View {
    ZStack {
      if presentation.useCheckmarkStyle {
        if selected {
          Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(presentation.activeColor)
        }
      } else if selected {
        Circle().fill(presentation.activeColor)
        Circle().fill(presentation.fillColor).frame(width: 6, height: 6)
      } else {
        Circle().fill(presentation.inactiveColor)
        Circle().stroke(.secondary.opacity(control.disabled ? 0.35 : 0.55), lineWidth: 0.5)
      }

      if focused {
        Circle()
          .stroke(presentation.effectiveFocusColor, lineWidth: 3)
          .padding(-2)
      }
      if pressed {
        Circle().fill(Color.primary.opacity(0.15))
      }
    }
    .frame(width: 18, height: 18)
    .opacity(control.disabled ? 0.55 : 1)
  }
}

struct RufletCupertinoRadioPresentation {
  let autofocus: Bool
  let useCheckmarkStyle: Bool
  let fillColor: Color
  let focusColor: Color?
  let mouseCursor: String?
  let activeColor: Color
  let inactiveColor: Color
  let labelPosition: RufletLabelPosition

  @MainActor
  init(control: RufletControl) {
    autofocus = control.boolean("autofocus", default: false)
    useCheckmarkStyle = control.boolean("use_checkmark_style", default: false)
    fillColor = parseColor(control.string("fill_color")) ?? .white
    focusColor = parseColor(control.string("focus_color"))
    mouseCursor = control.string("mouse_cursor")
    activeColor = parseColor(control.string("active_color")) ?? .accentColor
    inactiveColor = parseColor(control.string("inactive_color")) ?? .white
    labelPosition = parseEnum(
      RufletLabelPosition.self,
      control.string("label_position"),
      .right)!
  }

  var effectiveFocusColor: Color {
    focusColor ?? activeColor.opacity(0.25)
  }
}

private struct RufletCupertinoRadioPressedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var rufletCupertinoRadioPressed: Bool {
    get { self[RufletCupertinoRadioPressedKey.self] }
    set { self[RufletCupertinoRadioPressedKey.self] = newValue }
  }
}

private struct RufletCupertinoRadioButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.environment(
      \.rufletCupertinoRadioPressed,
      configuration.isPressed)
  }
}
