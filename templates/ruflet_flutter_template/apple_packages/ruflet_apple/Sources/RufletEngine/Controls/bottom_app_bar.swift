import SwiftUI

/// Apple-native port of pinned `bottom_app_bar.dart`.
@MainActor
public struct BottomAppBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      ZStack {
        shape
          .fill(parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground)
          .shadow(
            color: (parseColor(control.string("shadow_color")) ?? .black)
              .opacity(elevation > 0 ? 0.25 : 0),
            radius: elevation,
            y: -elevation / 3)
        control.buildWidget("content")
          .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
      }
      .frame(height: control.number("height").map { CGFloat($0) })
      .clipShape(RufletCornerShape(radius: radius))
    }
  }

  private var shape: RufletBottomAppBarShape {
    let details = rufletDictionary(control.dynamicValue("shape"))
    return RufletBottomAppBarShape(
      kind: details?["_type"] as? String,
      inverted: parseBool(details?["inverted"], false)!,
      notchMargin: control.number("notch_margin", default: 4) ?? 4,
      radius: radius)
  }
  private var radius: RufletBorderRadius {
    parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
  }
  private var elevation: Double { max(control.number("elevation", default: 0) ?? 0, 0) }
}

private struct RufletBottomAppBarShape: Shape {
  let kind: String?
  let inverted: Bool
  let notchMargin: Double
  let radius: RufletBorderRadius

  func path(in rect: CGRect) -> Path {
    guard kind?.lowercased() == "circular" else {
      return RufletCornerShape(radius: radius).path(in: rect)
    }
    let notchRadius = max(28 + notchMargin, 1)
    let centerX = rect.midX
    let top = rect.minY
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: top))
    path.addLine(to: CGPoint(x: centerX - notchRadius, y: top))
    path.addCurve(
      to: CGPoint(x: centerX + notchRadius, y: top),
      control1: CGPoint(x: centerX - notchRadius * 0.55, y: inverted ? top - notchRadius : top + notchRadius),
      control2: CGPoint(x: centerX + notchRadius * 0.55, y: inverted ? top - notchRadius : top + notchRadius))
    path.addLine(to: CGPoint(x: rect.maxX, y: top))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
