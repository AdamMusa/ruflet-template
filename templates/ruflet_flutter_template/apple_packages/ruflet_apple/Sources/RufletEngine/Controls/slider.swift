import RufletProtocol
import SwiftUI

@MainActor
public struct SliderControl: View {
  @ObservedObject public var control: RufletControl
  @State private var focused = false
  @State private var focusRequest = 0

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletSliderPresentation(control: control)
    LayoutControl(control: control) {
      Group {
        #if os(iOS)
          RufletNativeSlider(
            presentation: presentation,
            onChange: updateValue,
            onChangeStart: { value in
              focusRequest += 1
              control.triggerEvent("change_start", data: .double(value))
            },
            onChangeEnd: { value in
              control.triggerEvent("change_end", data: .double(value))
            })
          .frame(minHeight: 44)
        #else
          RufletSliderPrimitive(
            presentation: presentation,
            focused: focused,
            onFocusRequest: { focusRequest += 1 },
            onChange: updateValue,
            onChangeStart: { value in
              control.triggerEvent("change_start", data: .double(value))
            },
            onChangeEnd: { value in
              control.triggerEvent("change_end", data: .double(value))
            })
        #endif
      }
      .padding(presentation.padding)
      .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
      .overlay {
        RufletNativeFocusTarget(
          enabled: !presentation.disabled,
          autofocus: presentation.autofocus,
          request: focusRequest,
          onFocusChange: setFocused
        )
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
      }
    }
  }

  private func updateValue(_ value: Double) {
    control.updateProperties(["value": .double(value)], notify: true)
    control.triggerEvent("change", data: .double(value))
  }

  private func setFocused(_ value: Bool) {
    guard focused != value else { return }
    focused = value
    control.triggerEvent(value ? "focus" : "blur")
  }
}

enum RufletSliderInteraction: String, Equatable {
  case tapAndSlide
  case tapOnly
  case slideOnly
  case slideThumb

  init(_ value: String?) {
    let normalized = value?
      .lowercased()
      .filter { $0.isLetter || $0.isNumber }
    switch normalized {
    case "taponly": self = .tapOnly
    case "slideonly": self = .slideOnly
    case "slidethumb": self = .slideThumb
    default: self = .tapAndSlide
    }
  }
}

@MainActor
struct RufletSliderPresentation {
  let minimum: Double
  let maximum: Double
  let value: Double
  let divisions: Int?
  let label: String?
  let activeColor: Color
  let inactiveColor: Color
  let secondaryActiveColor: Color
  let secondaryTrackValue: Double?
  let thumbColor: Color
  let overlayColor: RufletWidgetStateProperty<Color>
  let interaction: RufletSliderInteraction
  let padding: EdgeInsets
  let mouseCursor: String?
  let autofocus: Bool
  let usesLegacy2023Appearance: Bool
  let disabled: Bool
  let hasExplicitActiveColor: Bool
  let hasExplicitInactiveColor: Bool
  let hasExplicitThumbColor: Bool

  init(control: RufletControl) {
    let rawMinimum = control.number("min") ?? 0
    let rawMaximum = control.number("max") ?? 1
    let effectiveMinimum = min(rawMinimum, rawMaximum)
    let effectiveMaximum = max(rawMinimum, rawMaximum)
    let effectiveValue = rufletSliderClamp(
      control.number("value") ?? effectiveMinimum,
      minimum: effectiveMinimum,
      maximum: effectiveMaximum)
    minimum = effectiveMinimum
    maximum = effectiveMaximum
    value = effectiveValue
    if let rawDivisions = control.integer("divisions"), rawDivisions > 0 {
      divisions = rawDivisions
    } else {
      divisions = nil
    }

    let precision = max(control.integer("round", default: 0) ?? 0, 0)
    label = control.string("label")?.replacingOccurrences(
      of: "{value}",
      with: String(format: "%.*f", precision, value))
    hasExplicitActiveColor = control.string("active_color") != nil
    hasExplicitInactiveColor = control.string("inactive_color") != nil
    hasExplicitThumbColor = control.string("thumb_color") != nil
    activeColor = parseColor(control.string("active_color")) ?? .accentColor
    inactiveColor = parseColor(control.string("inactive_color")) ?? .secondary.opacity(0.22)
    secondaryActiveColor =
      parseColor(control.string("secondary_active_color")) ?? activeColor.opacity(0.48)
    secondaryTrackValue = control.number("secondary_track_value").map {
      rufletSliderClamp(
        $0,
        minimum: effectiveMinimum,
        maximum: effectiveMaximum)
    }
    thumbColor = parseColor(control.string("thumb_color")) ?? activeColor
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color"),
      converter: { parseColor($0 as? String) })
    interaction = RufletSliderInteraction(control.string("interaction"))
    padding = parsePadding(control.dynamicValue("padding")) ?? EdgeInsets()
    mouseCursor = control.string("mouse_cursor")
    autofocus = control.boolean("autofocus", default: false)
    usesLegacy2023Appearance = control.boolean("year_2023") ?? true
    disabled = control.disabled || maximum <= minimum
  }

  var trackHeight: CGFloat { usesLegacy2023Appearance ? 4 : 16 }
  func thumbSize(_ states: Set<RufletWidgetState>) -> CGSize {
    if usesLegacy2023Appearance { return CGSize(width: 20, height: 20) }
    return CGSize(
      width: states.contains(.focused) || states.contains(.pressed) ? 2 : 4,
      height: 44)
  }
  var overlayDiameter: CGFloat { usesLegacy2023Appearance ? 40 : 44 }

  func states(focused: Bool, hovered: Bool, pressed: Bool) -> Set<RufletWidgetState> {
    var states = Set<RufletWidgetState>()
    if focused { states.insert(.focused) }
    if hovered { states.insert(.hovered) }
    if pressed {
      states.insert(.pressed)
      states.insert(.dragged)
    }
    if disabled { states.insert(.disabled) }
    return states
  }

  func resolvedOverlay(focused: Bool, hovered: Bool, pressed: Bool) -> Color {
    let states = states(focused: focused, hovered: hovered, pressed: pressed)
    if let explicit = overlayColor.resolve(states) { return explicit }
    if pressed { return activeColor.opacity(0.14) }
    if focused { return activeColor.opacity(0.11) }
    if hovered { return activeColor.opacity(0.08) }
    return .clear
  }

  func snap(_ proposed: Double) -> Double {
    rufletSliderSnap(
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

private struct RufletSliderPrimitive: View {
  let presentation: RufletSliderPresentation
  let focused: Bool
  let onFocusRequest: () -> Void
  let onChange: (Double) -> Void
  let onChangeStart: (Double) -> Void
  let onChangeEnd: (Double) -> Void

  @Environment(\.layoutDirection) private var layoutDirection
  @State private var hovered = false
  @State private var interactionActive = false
  @State private var interactionStartValue = 0.0
  @State private var interactionValue = 0.0
  @State private var interactionStartedOnThumb = false

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      let thumbX = visualX(for: presentation.value, width: width)
      let secondaryX = visualX(
        for: presentation.secondaryTrackValue ?? presentation.value,
        width: width)
      let states = presentation.states(
        focused: focused,
        hovered: hovered,
        pressed: interactionActive)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(presentation.inactiveColor)
          .frame(height: presentation.trackHeight)

        secondaryTrack(width: width, thumbX: thumbX, secondaryX: secondaryX)
        activeTrack(width: width, thumbX: thumbX)

        if let divisions = presentation.divisions, divisions > 0 {
          tickMarks(divisions: divisions, width: width)
        }

        Circle()
          .fill(
            presentation.resolvedOverlay(
              focused: focused,
              hovered: hovered,
              pressed: interactionActive)
          )
          .frame(width: presentation.overlayDiameter, height: presentation.overlayDiameter)
          .position(x: thumbX, y: proxy.size.height / 2)
          .allowsHitTesting(false)

        thumb(states: states)
          .position(x: thumbX, y: proxy.size.height / 2)

        if interactionActive, presentation.divisions != nil,
          let label = presentation.label, !label.isEmpty
        {
          Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Color.white)
            .background(presentation.activeColor, in: Capsule())
            .position(x: thumbX, y: max(proxy.size.height / 2 - 30, 0))
            .allowsHitTesting(false)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(dragGesture(width: width))
    }
    .frame(minHeight: 44)
    .opacity(presentation.disabled ? 0.48 : 1)
    .allowsHitTesting(!presentation.disabled)
    .onHover { hovered = $0 }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(presentation.label ?? "")
    .accessibilityValue(accessibilityValue)
    .accessibilityAdjustableAction { direction in
      guard !presentation.disabled else { return }
      let increment =
        presentation.divisions.map {
          (presentation.maximum - presentation.minimum) / Double($0)
        } ?? (presentation.maximum - presentation.minimum) / 10
      let proposed =
        direction == .increment
        ? presentation.value + increment
        : presentation.value - increment
      onChange(presentation.snap(proposed))
    }
  }

  @ViewBuilder
  private func thumb(states: Set<RufletWidgetState>) -> some View {
    let size = presentation.thumbSize(states)
    if presentation.usesLegacy2023Appearance {
      Circle()
        .fill(presentation.thumbColor)
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(states.contains(.pressed) ? 0.22 : 0.12), radius: 1.5, y: 1)
    } else {
      Capsule()
        .fill(presentation.thumbColor)
        .frame(width: size.width, height: size.height)
    }
  }

  @ViewBuilder
  private func activeTrack(width: CGFloat, thumbX: CGFloat) -> some View {
    let gap = presentation.usesLegacy2023Appearance ? 0 : 6 as CGFloat
    if layoutDirection == .rightToLeft {
      Capsule()
        .fill(presentation.activeColor)
        .frame(width: max(width - thumbX - gap, 0), height: presentation.trackHeight)
        .offset(x: min(thumbX + gap, width))
    } else {
      Capsule()
        .fill(presentation.activeColor)
        .frame(width: max(thumbX - gap, 0), height: presentation.trackHeight)
    }
  }

  @ViewBuilder
  private func secondaryTrack(width: CGFloat, thumbX: CGFloat, secondaryX: CGFloat) -> some View {
    let showsSecondary =
      layoutDirection == .rightToLeft
      ? secondaryX < thumbX
      : secondaryX > thumbX
    let lower = min(thumbX, secondaryX)
    let upper = max(thumbX, secondaryX)
    let gap = presentation.usesLegacy2023Appearance ? 0 : 6 as CGFloat
    if showsSecondary, upper > lower {
      Capsule()
        .fill(presentation.secondaryActiveColor)
        .frame(width: max(upper - lower - gap * 2, 0), height: presentation.trackHeight)
        .offset(x: lower + gap)
    }
  }

  private func tickMarks(divisions: Int, width: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(0...divisions, id: \.self) { index in
        Circle()
          .fill(
            index
              <= Int(
                (presentation.fraction(for: presentation.value) * CGFloat(divisions)).rounded())
              ? Color.white.opacity(0.72)
              : presentation.activeColor.opacity(0.46)
          )
          .frame(width: 2, height: 2)
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
        let translation = gesture.translation.width
        if !interactionActive {
          interactionStartValue = presentation.value
          interactionValue = presentation.value
          interactionStartedOnThumb =
            abs(
              gesture.startLocation.x - visualX(for: presentation.value, width: width)
            ) <= presentation.overlayDiameter / 2

          switch presentation.interaction {
          case .tapAndSlide, .tapOnly:
            beginInteraction(at: value(at: gesture.location.x, width: width))
          case .slideOnly:
            guard abs(translation) >= 3 else { return }
            beginInteraction(at: presentation.value)
          case .slideThumb:
            guard interactionStartedOnThumb, abs(translation) >= 3 else { return }
            beginInteraction(at: presentation.value)
          }
          return
        }

        switch presentation.interaction {
        case .tapAndSlide:
          changeInteraction(to: value(at: gesture.location.x, width: width))
        case .slideOnly, .slideThumb:
          changeInteraction(to: draggedValue(translation: translation, width: width))
        case .tapOnly:
          break
        }
      }
      .onEnded { _ in
        guard interactionActive else { return }
        onChangeEnd(interactionValue)
        interactionActive = false
      }
  }

  private func beginInteraction(at proposed: Double) {
    onFocusRequest()
    interactionActive = true
    onChangeStart(presentation.value)
    changeInteraction(to: proposed)
  }

  private func changeInteraction(to proposed: Double) {
    let snapped = presentation.snap(proposed)
    interactionValue = snapped
    onChange(snapped)
  }

  private func draggedValue(translation: CGFloat, width: CGFloat) -> Double {
    guard width > 0 else { return presentation.value }
    let direction = layoutDirection == .rightToLeft ? -1.0 : 1.0
    let delta =
      Double(translation / width) * (presentation.maximum - presentation.minimum) * direction
    return interactionStartValue + delta
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

  private var accessibilityValue: String {
    if let label = presentation.label, !label.isEmpty { return label }
    return String(presentation.value)
  }
}

func rufletSliderClamp(_ value: Double, minimum: Double, maximum: Double) -> Double {
  min(max(value, minimum), maximum)
}

func rufletSliderSnap(
  _ value: Double,
  minimum: Double,
  maximum: Double,
  divisions: Int?
) -> Double {
  let clamped = rufletSliderClamp(value, minimum: minimum, maximum: maximum)
  guard let divisions, divisions > 0, maximum > minimum else { return clamped }
  let fraction = (clamped - minimum) / (maximum - minimum)
  return minimum + (fraction * Double(divisions)).rounded() / Double(divisions)
    * (maximum - minimum)
}
