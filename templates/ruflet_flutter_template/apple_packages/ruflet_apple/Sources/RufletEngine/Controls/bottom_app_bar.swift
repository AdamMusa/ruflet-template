import SwiftUI

/// Apple-native port of pinned `bottom_app_bar.dart`.
@MainActor
public struct BottomAppBarControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletSafeAreaInsets) private var safeAreaInsets

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    let presentation = RufletBottomAppBarPresentation(control: control)
    LayoutControl(control: control) {
      VStack(spacing: 0) {
        ZStack {
          shape
            .fill(backgroundColor)
            .shadow(
              color: (parseColor(control.string("shadow_color")) ?? .black)
                .opacity(elevation > 0 ? 0.25 : 0),
              radius: elevation,
              y: -elevation / 3)
          control.buildWidget("content")
            .padding(
              parsePadding(control.dynamicValue("padding"))
                ?? RufletLayoutDefaults.bottomAppBar)
        }
        .frame(height: control.number("height").map { CGFloat($0) })
        Color.clear.frame(height: safeAreaInsets.bottom)
      }
      .background(backgroundColor)
      .modifier(
        RufletBottomAppBarClipModifier(
          shape: RufletCornerShape(radius: radius),
          presentation: presentation))
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
  private var backgroundColor: Color {
    parseColor(control.string("bgcolor")) ?? Color.rufletSystemBackground
  }
}

@MainActor
struct RufletBottomAppBarPresentation {
  let clipBehavior: String
  let hasBorderRadius: Bool

  init(control: RufletControl) {
    let radius = parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
    hasBorderRadius = radius != .zero
    let requested = control.string("clip_behavior")?.lowercased()
    if hasBorderRadius, requested == nil || requested == "none" {
      clipBehavior = "antialias"
    } else {
      clipBehavior = requested ?? "none"
    }
  }

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }
}

private struct RufletBottomAppBarClipModifier: ViewModifier {
  let shape: RufletCornerShape
  let presentation: RufletBottomAppBarPresentation

  @ViewBuilder
  func body(content: Content) -> some View {
    if presentation.clipsContent {
      content.clipShape(shape, style: FillStyle(antialiased: presentation.antialiasedClip))
    } else {
      content
    }
  }
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
      control1: CGPoint(
        x: centerX - notchRadius * 0.55, y: inverted ? top - notchRadius : top + notchRadius),
      control2: CGPoint(
        x: centerX + notchRadius * 0.55, y: inverted ? top - notchRadius : top + notchRadius))
    path.addLine(to: CGPoint(x: rect.maxX, y: top))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
