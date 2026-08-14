import SwiftUI

enum RufletCardVariant: String, CaseIterable, RufletStringEnum {
  case elevated, filled, outlined
}

enum RufletCardBorderLayer: Equatable {
  case none
  case background
  case foreground
}

@MainActor
struct RufletCardPresentation {
  let variant: RufletCardVariant
  let radius: RufletBorderRadius
  let elevation: Double
  let clipBehavior: String
  let showBorderOnForeground: Bool
  let semanticContainer: Bool

  init(control: RufletControl) {
    let shape = rufletDictionary(control.dynamicValue("shape"))
    radius =
      parseBorderRadius(
        shape?["border_radius"],
        RufletBorderRadius(topLeft: 12, topRight: 12, bottomLeft: 12, bottomRight: 12))!
    variant = parseEnum(RufletCardVariant.self, control.string("variant"), .elevated)!
    elevation = control.number("elevation") ?? (variant == .elevated ? 1 : 0)
    clipBehavior = control.string("clip_behavior", default: "none")!.lowercased()
    showBorderOnForeground = control.boolean("show_border_on_foreground", default: true)
    semanticContainer = control.boolean("semantic_container", default: true)
  }

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }

  var borderLayer: RufletCardBorderLayer {
    guard variant == .outlined else { return .none }
    return showBorderOnForeground ? .foreground : .background
  }
}

@MainActor
public struct CardControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletCardPresentation(control: control)
    let shape = RufletCornerShape(radius: presentation.radius)

    LayoutControl(control: control) {
      ZStack {
        if presentation.borderLayer == .background {
          outline(shape)
        }
        control.buildWidget("content")
      }
      .background(background(presentation.variant), in: shape)
      .modifier(RufletCardClipModifier(shape: shape, presentation: presentation))
      .overlay {
        if presentation.borderLayer == .foreground {
          outline(shape)
        }
      }
      .shadow(
        color: presentation.variant == .elevated ? shadowColor : .clear,
        radius: presentation.elevation
      )
      .padding(
        parseMargin(control.dynamicValue("margin"))
          ?? RufletLayoutDefaults.cardMargin)
      .accessibilityElement(children: presentation.semanticContainer ? .contain : .ignore)
    }
  }

  private var shadowColor: Color {
    parseColor(control.string("shadow_color")) ?? .black.opacity(0.2)
  }

  private func background(_ variant: RufletCardVariant) -> Color {
    parseColor(control.string("bgcolor"))
      ?? (variant == .filled ? .secondary.opacity(0.12) : .rufletSystemBackground)
  }

  private func outline(_ shape: RufletCornerShape) -> some View {
    let details = rufletDictionary(control.dynamicValue("shape"))
    let side = parseBorderSide(details?["side"])
    return shape.stroke(
      side?.color ?? .secondary.opacity(0.5),
      lineWidth: side?.width ?? 1)
  }
}

private struct RufletCardClipModifier: ViewModifier {
  let shape: RufletCornerShape
  let presentation: RufletCardPresentation

  @ViewBuilder
  func body(content: Content) -> some View {
    if presentation.clipsContent {
      content.clipShape(shape, style: FillStyle(antialiased: presentation.antialiasedClip))
    } else {
      content
    }
  }
}
