import SwiftUI

@MainActor
public struct ProgressRingControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      RufletCircularProgress(presentation: RufletProgressRingPresentation(control: control))
    }
  }
}

enum RufletProgressStrokeCap: String, Equatable {
  case butt, round, square

  var swiftUI: CGLineCap {
    switch self {
    case .butt: .butt
    case .round: .round
    case .square: .square
    }
  }
}

@MainActor
struct RufletProgressRingPresentation {
  let value: Double?
  let color: Color
  let background: Color
  let label: String
  let semanticsValue: String
  let padding: EdgeInsets
  let strokeWidth: CGFloat
  let strokeAlign: CGFloat
  let strokeCap: RufletProgressStrokeCap
  let trackGap: CGFloat
  let minWidth: CGFloat?
  let maxWidth: CGFloat?
  let minHeight: CGFloat?
  let maxHeight: CGFloat?
  let usesLegacy2023Appearance: Bool

  init(control: RufletControl) {
    value = control.number("value")
    color = parseColor(control.string("color")) ?? .accentColor
    background = parseColor(control.string("bgcolor")) ?? .secondary.opacity(0.2)
    label = control.string("semantics_label") ?? ""
    semanticsValue = control.number("semantics_value").map { String($0) } ?? ""
    padding = parsePadding(control.dynamicValue("padding")) ?? EdgeInsets()
    strokeWidth = CGFloat(max(control.number("stroke_width") ?? 4, 0))
    strokeAlign = CGFloat(min(max(control.number("stroke_align") ?? 0, -1), 1))
    strokeCap =
      RufletProgressStrokeCap(
        rawValue: control.string("stroke_cap")?.lowercased() ?? "butt") ?? .butt
    trackGap = CGFloat(max(control.number("track_gap") ?? 0, 0))
    let constraints = rufletDictionary(control.dynamicValue("size_constraints"))
    minWidth = parseDouble(constraints?["min_width"]).map { CGFloat($0) }
    maxWidth = parseDouble(constraints?["max_width"]).map { CGFloat($0) }
    minHeight = parseDouble(constraints?["min_height"]).map { CGFloat($0) }
    maxHeight = parseDouble(constraints?["max_height"]).map { CGFloat($0) }
    usesLegacy2023Appearance =
      control.boolean("year_2023")
      ?? control.boolean("year2023")
      ?? false
  }
}

private struct RufletCircularProgress: View {
  let presentation: RufletProgressRingPresentation
  @State private var rotation: Double = 0

  var body: some View {
    let progress = min(max(presentation.value ?? 0.28, 0), 1)
    let trimStart = min(presentation.trackGap / 360, max(progress - 0.001, 0))
    let inset = -presentation.strokeAlign * presentation.strokeWidth / 2

    ZStack {
      Circle()
        .inset(by: inset)
        .stroke(presentation.background, lineWidth: presentation.strokeWidth)
      Circle()
        .inset(by: inset)
        .trim(from: trimStart, to: progress)
        .stroke(
          presentation.color,
          style: StrokeStyle(
            lineWidth: presentation.strokeWidth,
            lineCap: presentation.strokeCap.swiftUI)
        )
        .rotationEffect(.degrees(-90 + (presentation.value == nil ? rotation : 0)))
    }
    .padding(presentation.padding)
    .padding(max(inset, 0))
    .frame(
      minWidth: presentation.minWidth,
      maxWidth: presentation.maxWidth,
      minHeight: presentation.minHeight,
      maxHeight: presentation.maxHeight
    )
    .aspectRatio(1, contentMode: .fit)
    .onAppear {
      guard presentation.value == nil else { return }
      rotation = 360
    }
    .animation(
      presentation.value == nil
        ? .linear(duration: presentation.usesLegacy2023Appearance ? 1.35 : 0.9)
          .repeatForever(autoreverses: false)
        : nil,
      value: rotation
    )
    .accessibilityLabel(presentation.label)
    .accessibilityValue(presentation.semanticsValue)
  }
}
