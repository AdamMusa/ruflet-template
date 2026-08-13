import SwiftUI

/// Apple-native port of Flet's `cupertino_activity_indicator.dart`.
@MainActor
public struct CupertinoActivityIndicatorControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let progress = control.number("progress") {
        RufletPartiallyRevealedActivityIndicator(
          progress: min(max(progress, 0), 1),
          color: resolvedColor,
          radius: radius)
      } else if control.boolean("animating", default: true) {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(resolvedColor)
          .frame(width: radius * 2, height: radius * 2)
          .scaleEffect(max(radius / 10, 0.1))
      } else {
        RufletPartiallyRevealedActivityIndicator(
          progress: 1,
          color: resolvedColor,
          radius: radius)
      }
    }
  }

  private var radius: CGFloat {
    max(CGFloat(control.number("radius") ?? 10), 0)
  }

  private var resolvedColor: Color {
    parseColor(control.string("color")) ?? .secondary
  }
}

private struct RufletPartiallyRevealedActivityIndicator: View {
  let progress: Double
  let color: Color
  let radius: CGFloat

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let outerRadius = min(size.width, size.height) / 2
      let dotRadius = max(outerRadius * 0.11, 0.75)
      let visibleTicks = Int((progress * 8).rounded(.up))
      for index in 0..<visibleTicks {
        let angle = Double(index) * .pi / 4 - .pi / 2
        let point = CGPoint(
          x: center.x + CGFloat(cos(angle)) * (outerRadius - dotRadius),
          y: center.y + CGFloat(sin(angle)) * (outerRadius - dotRadius))
        let rect = CGRect(
          x: point.x - dotRadius,
          y: point.y - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.25 + 0.75 * Double(index + 1) / 8)))
      }
    }
    .frame(width: radius * 2, height: radius * 2)
    .accessibilityLabel("Progress")
    .accessibilityValue("\(Int(progress * 100)) percent")
  }
}
