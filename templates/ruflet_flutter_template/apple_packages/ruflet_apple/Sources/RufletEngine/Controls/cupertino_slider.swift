import RufletProtocol
import SwiftUI

@MainActor
struct RufletCupertinoSliderPresentation {
  let minimum: Double
  let maximum: Double
  let value: Double
  let divisions: Int?
  let step: Double
  let activeColor: Color
  let thumbColor: Color
  let disabled: Bool

  init(control: RufletControl) {
    let rawMinimum = control.number("min") ?? 0
    let rawMaximum = control.number("max") ?? 1
    minimum = min(rawMinimum, rawMaximum)
    maximum = max(rawMinimum, rawMaximum)
    value = rufletSliderClamp(
      control.number("value") ?? minimum,
      minimum: minimum,
      maximum: maximum)
    if let rawDivisions = control.integer("divisions"), rawDivisions > 0, maximum > minimum {
      divisions = rawDivisions
      step = (maximum - minimum) / Double(rawDivisions)
    } else {
      divisions = nil
      step = max((maximum - minimum) / 10, Double.leastNonzeroMagnitude)
    }
    activeColor = parseColor(control.string("active_color")) ?? .accentColor
    thumbColor = parseColor(control.string("thumb_color")) ?? .white
    disabled = control.disabled || maximum <= minimum
  }

  func snap(_ proposed: Double) -> Double {
    guard maximum > minimum else { return minimum }
    return rufletSliderSnap(
      proposed,
      minimum: minimum,
      maximum: maximum,
      divisions: divisions)
  }

  func fraction(for value: Double) -> CGFloat {
    guard maximum > minimum else { return 0 }
    return CGFloat(
      (rufletSliderClamp(value, minimum: minimum, maximum: maximum) - minimum)
        / (maximum - minimum))
  }
}

@MainActor
public struct CupertinoSliderControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletCupertinoSliderPresentation(control: control)
    LayoutControl(control: control) {
      RufletCupertinoSliderPrimitive(
        presentation: presentation,
        onChange: updateValue,
        onChangeStart: { value in
          control.triggerEvent("change_start", data: .double(value))
        },
        onChangeEnd: { value in
          control.triggerEvent("change_end", data: .double(value))
        }
      )
    }
  }

  private func updateValue(_ value: Double) {
    control.updateProperties(["value": .double(value)], notify: true)
    control.triggerEvent("change")
  }
}

private struct RufletCupertinoSliderPrimitive: View {
  let presentation: RufletCupertinoSliderPresentation
  let onChange: (Double) -> Void
  let onChangeStart: (Double) -> Void
  let onChangeEnd: (Double) -> Void

  @Environment(\.layoutDirection) private var layoutDirection
  @State private var editing = false
  @State private var editingValue = 0.0

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width - thumbDiameter, 1)
      let currentValue = editing ? editingValue : presentation.value
      let x = thumbDiameter / 2 + visualFraction(for: currentValue) * width

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.secondary.opacity(0.24))
          .frame(height: 4)
          .padding(.horizontal, thumbDiameter / 2)

        Capsule()
          .fill(presentation.activeColor)
          .frame(width: activeTrackWidth(value: currentValue, usableWidth: width), height: 4)
          .offset(
            x: activeTrackOffset(
              activeWidth: activeTrackWidth(value: currentValue, usableWidth: width),
              usableWidth: width))

        Circle()
          .fill(presentation.thumbColor)
          .frame(width: thumbDiameter, height: thumbDiameter)
          .shadow(color: .black.opacity(editing ? 0.2 : 0.12), radius: 1.5, y: 1)
          .position(x: x, y: proxy.size.height / 2)
      }
      .contentShape(Rectangle())
      .gesture(drag(width: width))
    }
    .frame(minHeight: 44)
    .opacity(presentation.disabled ? 0.46 : 1)
    .allowsHitTesting(!presentation.disabled)
    .accessibilityElement(children: .ignore)
    .accessibilityValue(String(presentation.value))
    .accessibilityAdjustableAction { direction in
      guard !presentation.disabled else { return }
      let proposed =
        direction == .increment
        ? presentation.value + presentation.step
        : presentation.value - presentation.step
      onChange(presentation.snap(proposed))
    }
  }

  private var thumbDiameter: CGFloat { 20 }

  private func visualFraction(for value: Double) -> CGFloat {
    let fraction = presentation.fraction(for: value)
    return layoutDirection == .rightToLeft ? 1 - fraction : fraction
  }

  private func activeTrackWidth(value: Double, usableWidth: CGFloat) -> CGFloat {
    presentation.fraction(for: value) * usableWidth
  }

  private func activeTrackOffset(activeWidth: CGFloat, usableWidth: CGFloat) -> CGFloat {
    layoutDirection == .rightToLeft
      ? thumbDiameter / 2 + usableWidth - activeWidth
      : thumbDiameter / 2
  }

  private func value(at x: CGFloat, width: CGFloat) -> Double {
    var fraction = min(max((x - thumbDiameter / 2) / width, 0), 1)
    if layoutDirection == .rightToLeft { fraction = 1 - fraction }
    return presentation.snap(
      presentation.minimum + Double(fraction) * (presentation.maximum - presentation.minimum))
  }

  private func drag(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        guard !presentation.disabled else { return }
        let proposed = value(at: gesture.location.x, width: width)
        if !editing {
          editing = true
          editingValue = presentation.value
          onChangeStart(presentation.value)
        }
        editingValue = proposed
        onChange(proposed)
      }
      .onEnded { gesture in
        guard editing else { return }
        let finalValue = value(at: gesture.location.x, width: width)
        editingValue = finalValue
        onChangeEnd(finalValue)
        editing = false
      }
  }
}
