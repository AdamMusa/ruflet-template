import RufletProtocol
import SwiftUI

@MainActor
public struct RangeSliderControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletRangeSliderPresentation(control: control)
    LayoutControl(control: control) {
      RufletRangeSliderPrimitive(
        presentation: presentation,
        onChangeStart: { control.triggerEvent("change_start") },
        onChange: updateValues,
        onChangeEnd: { control.triggerEvent("change_end") }
      )
    }
  }

  func updateValues(_ values: RufletRangeValues) {
    control.updateProperties(
      ["start_value": .double(values.start), "end_value": .double(values.end)],
      notify: true)
    control.triggerEvent("change")
  }
}

struct RufletRangeValues: Equatable, Sendable {
  let start: Double
  let end: Double
}

@MainActor
struct RufletRangeSliderPresentation {
  let minimum: Double
  let maximum: Double
  let values: RufletRangeValues
  let divisions: Int?
  let precision: Int
  let label: String
  let activeColor: Color
  let inactiveColor: Color
  let mouseCursor: RufletWidgetStateProperty<String>
  let overlayColor: RufletWidgetStateProperty<Color>
  let disabled: Bool

  init(control: RufletControl) {
    let rawMinimum = control.number("min") ?? 0
    let rawMaximum = control.number("max") ?? 1
    minimum = min(rawMinimum, rawMaximum)
    maximum = max(rawMinimum, rawMaximum)
    let rawStart = rufletSliderClamp(
      control.number("start_value") ?? 0,
      minimum: minimum,
      maximum: maximum)
    let rawEnd = rufletSliderClamp(
      control.number("end_value") ?? 0,
      minimum: minimum,
      maximum: maximum)
    values = RufletRangeValues(start: min(rawStart, rawEnd), end: max(rawStart, rawEnd))
    if let rawDivisions = control.integer("divisions"), rawDivisions > 0 {
      divisions = rawDivisions
    } else {
      divisions = nil
    }
    precision = max(control.integer("round", default: 0) ?? 0, 0)
    label = control.string("label", default: "") ?? ""
    activeColor = parseColor(control.string("active_color")) ?? .accentColor
    inactiveColor = parseColor(control.string("inactive_color")) ?? .secondary.opacity(0.25)
    mouseCursor = RufletWidgetStateProperty(
      control.dynamicValue("mouse_cursor"),
      converter: { raw in
        if let string = raw as? String { return string }
        if let value = raw as? RufletValue { return value.text }
        return nil
      })
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color"),
      converter: { raw in
        if let string = raw as? String { return parseColor(string) }
        if let value = raw as? RufletValue { return parseColor(value.text) }
        return nil
      })
    disabled = control.disabled || maximum <= minimum
  }

  func snap(_ value: Double) -> Double {
    rufletSliderSnap(value, minimum: minimum, maximum: maximum, divisions: divisions)
  }

  func fraction(for value: Double) -> CGFloat {
    guard maximum > minimum else { return 0 }
    return CGFloat(
      (rufletSliderClamp(value, minimum: minimum, maximum: maximum) - minimum)
        / (maximum - minimum))
  }

  func formattedLabel(for value: Double) -> String {
    label.replacingOccurrences(
      of: "{value}",
      with: String(format: "%.*f", precision, value))
  }

  func resolvedOverlay(hovered: Bool, pressed: Bool) -> Color {
    let states = widgetStates(hovered: hovered, pressed: pressed)
    if let explicit = overlayColor.resolve(states) { return explicit }
    if pressed { return activeColor.opacity(0.14) }
    if hovered { return activeColor.opacity(0.08) }
    return .clear
  }

  func resolvedMouseCursor(hovered: Bool, pressed: Bool) -> String? {
    mouseCursor.resolve(widgetStates(hovered: hovered, pressed: pressed))
  }

  private func widgetStates(hovered: Bool, pressed: Bool) -> Set<RufletWidgetState> {
    var states = Set<RufletWidgetState>()
    if hovered { states.insert(.hovered) }
    if pressed {
      states.insert(.pressed)
      states.insert(.dragged)
    }
    if disabled { states.insert(.disabled) }
    return states
  }
}

private enum RufletRangeThumb {
  case start, end
}

private struct RufletRangeSliderPrimitive: View {
  let presentation: RufletRangeSliderPresentation
  let onChangeStart: () -> Void
  let onChange: (RufletRangeValues) -> Void
  let onChangeEnd: () -> Void

  @Environment(\.layoutDirection) private var layoutDirection
  @State private var hovered = false
  @State private var interactionActive = false
  @State private var activeThumb: RufletRangeThumb?
  @State private var interactionValues = RufletRangeValues(start: 0, end: 0)

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      let values = interactionActive ? interactionValues : presentation.values
      let startX = visualX(for: values.start, width: width)
      let endX = visualX(for: values.end, width: width)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(presentation.inactiveColor)
          .frame(height: 4)

        Capsule()
          .fill(presentation.activeColor)
          .frame(width: abs(endX - startX), height: 4)
          .offset(x: min(startX, endX))

        if let divisions = presentation.divisions, divisions > 0 {
          tickMarks(divisions: divisions, width: width)
        }

        overlay(at: startX, thumb: .start, values: values)
        overlay(at: endX, thumb: .end, values: values)
        thumb(at: startX, thumb: .start, values: values)
        thumb(at: endX, thumb: .end, values: values)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(dragGesture(width: width))
    }
    .frame(minHeight: 44)
    .opacity(presentation.disabled ? 0.48 : 1)
    .allowsHitTesting(!presentation.disabled)
    .onHover { hovered = $0 }
    .modifier(
      RufletMouseCursorModifier(
        cursor: presentation.resolvedMouseCursor(
          hovered: hovered,
          pressed: interactionActive)))
    .accessibilityElement(children: .ignore)
    .accessibilityValue(
      "\(presentation.formattedLabel(for: presentation.values.start)) – \(presentation.formattedLabel(for: presentation.values.end))")
  }

  private func overlay(
    at x: CGFloat,
    thumb: RufletRangeThumb,
    values: RufletRangeValues
  ) -> some View {
    Circle()
      .fill(
        presentation.resolvedOverlay(
          hovered: hovered,
          pressed: interactionActive && activeThumb == thumb))
      .frame(width: 40, height: 40)
      .position(x: x, y: 22)
      .allowsHitTesting(false)
  }

  private func thumb(
    at x: CGFloat,
    thumb: RufletRangeThumb,
    values: RufletRangeValues
  ) -> some View {
    ZStack {
      Circle()
        .fill(presentation.activeColor)
        .frame(width: 20, height: 20)
        .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
      if interactionActive, activeThumb == thumb, presentation.divisions != nil,
        !presentation.label.isEmpty
      {
        let value = thumb == .start ? values.start : values.end
        Text(presentation.formattedLabel(for: value))
          .font(.caption.weight(.medium))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(presentation.activeColor, in: Capsule())
          .offset(y: -30)
      }
    }
    .position(x: x, y: 22)
    .allowsHitTesting(false)
  }

  private func tickMarks(divisions: Int, width: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(0...divisions, id: \.self) { index in
        Circle().fill(Color.white.opacity(0.7)).frame(width: 2, height: 2)
        if index < divisions { Spacer(minLength: 0) }
      }
    }
    .frame(width: width)
    .allowsHitTesting(false)
  }

  private func dragGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        guard !presentation.disabled else { return }
        let proposed = presentation.snap(value(at: gesture.location.x, width: width))
        if !interactionActive {
          interactionValues = presentation.values
          activeThumb = nearestThumb(to: proposed, values: interactionValues)
          interactionActive = true
          onChangeStart()
        }
        switch activeThumb {
        case .start:
          interactionValues = RufletRangeValues(
            start: min(proposed, interactionValues.end),
            end: interactionValues.end)
        case .end:
          interactionValues = RufletRangeValues(
            start: interactionValues.start,
            end: max(proposed, interactionValues.start))
        case nil:
          return
        }
        onChange(interactionValues)
      }
      .onEnded { _ in
        guard interactionActive else { return }
        onChangeEnd()
        interactionActive = false
        activeThumb = nil
      }
  }

  private func nearestThumb(
    to proposed: Double,
    values: RufletRangeValues
  ) -> RufletRangeThumb {
    let startDistance = abs(proposed - values.start)
    let endDistance = abs(proposed - values.end)
    return startDistance <= endDistance ? .start : .end
  }

  private func value(at location: CGFloat, width: CGFloat) -> Double {
    guard width > 0 else { return presentation.minimum }
    var fraction = min(max(Double(location / width), 0), 1)
    if layoutDirection == .rightToLeft { fraction = 1 - fraction }
    return presentation.minimum + fraction * (presentation.maximum - presentation.minimum)
  }

  private func visualX(for value: Double, width: CGFloat) -> CGFloat {
    let fraction = presentation.fraction(for: value)
    return layoutDirection == .rightToLeft ? width * (1 - fraction) : width * fraction
  }
}
