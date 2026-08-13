import SwiftUI

@MainActor
public struct ProgressBarControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      RufletLinearProgress(presentation: RufletProgressBarPresentation(control: control))
    }
  }
}

@MainActor
struct RufletProgressBarPresentation {
  let value: Double?
  let color: Color
  let height: CGFloat
  let background: Color
  let radius: CGFloat
  let label: String
  let semanticsValue: String
  let stopIndicatorColor: Color?
  let stopIndicatorRadius: CGFloat?
  let trackGap: CGFloat
  let usesLegacy2023Appearance: Bool

  init(control: RufletControl) {
    value = control.number("value")
    color = parseColor(control.string("color")) ?? .accentColor
    height = CGFloat(control.number("bar_height") ?? 4)
    background = parseColor(control.string("bgcolor")) ?? .secondary.opacity(0.2)
    radius = CGFloat(
      parseBorderRadius(control.dynamicValue("border_radius"))?.uniform
        ?? (control.boolean("year_2023") == true ? 0 : 2))
    label = control.string("semantics_label") ?? ""
    semanticsValue = control.number("semantics_value").map { String($0) } ?? ""
    stopIndicatorColor = parseColor(control.string("stop_indicator_color"))
    stopIndicatorRadius = control.number("stop_indicator_radius").map { CGFloat($0) }
    trackGap = CGFloat(max(control.number("track_gap") ?? 0, 0))
    usesLegacy2023Appearance = control.boolean("year_2023") == true
  }
}

private struct RufletLinearProgress: View {
  let presentation: RufletProgressBarPresentation
  @State private var indeterminateOffset: CGFloat = -0.45

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 0)
      let progress = min(max(presentation.value ?? 0, 0), 1)
      let fillWidth = presentation.value == nil ? width * 0.35 : width * progress
      let offset =
        presentation.value == nil
        ? indeterminateOffset * width
        : min(max(fillWidth / 2, 0), width / 2)

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: presentation.radius)
          .fill(presentation.background)
        RoundedRectangle(cornerRadius: presentation.radius)
          .fill(presentation.color)
          .frame(width: max(fillWidth - presentation.trackGap, 0))
          .offset(x: presentation.value == nil ? offset : 0)

        if let stopRadius = presentation.stopIndicatorRadius, stopRadius > 0 {
          Circle()
            .fill(presentation.stopIndicatorColor ?? presentation.color)
            .frame(width: stopRadius * 2, height: stopRadius * 2)
            .offset(x: max(width - stopRadius * 2, 0))
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: presentation.radius))
      .onAppear {
        guard presentation.value == nil else { return }
        indeterminateOffset = 1.1
      }
      .animation(
        presentation.value == nil
          ? .linear(duration: presentation.usesLegacy2023Appearance ? 1.2 : 0.9)
            .repeatForever(autoreverses: false)
          : nil,
        value: indeterminateOffset)
    }
    .frame(height: presentation.height)
    .accessibilityLabel(presentation.label)
    .accessibilityValue(presentation.semanticsValue)
  }
}
