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
  let backgroundColor: Color
  let shadowColor: Color
  let borderSide: RufletBorderSide?
  let margin: EdgeInsets

  init(control: RufletControl, theme: RufletTheme? = nil) {
    let componentTheme = theme?.componentTheme("card_theme")
    let shapeValue = control.dynamicValue("shape") ?? componentTheme?["shape"]
    let shape = rufletDictionary(shapeValue)
    let useMaterial3 = theme?.useMaterial3WireValue ?? true
    radius =
      parseBorderRadius(
        shape?["border_radius"],
        RufletBorderRadius(
          topLeft: useMaterial3 ? 12 : 4,
          topRight: useMaterial3 ? 12 : 4,
          bottomLeft: useMaterial3 ? 12 : 4,
          bottomRight: useMaterial3 ? 12 : 4))!
    variant = parseEnum(RufletCardVariant.self, control.string("variant"), .elevated)!
    elevation =
      control.number("elevation")
      ?? parseDouble(componentTheme?["elevation"])
      ?? (!useMaterial3 || variant == .elevated ? 1 : 0)
    clipBehavior =
      (control.string("clip_behavior")
      ?? componentTheme?["clip_behavior"] as? String
      ?? "none").lowercased()
    showBorderOnForeground = control.boolean("show_border_on_foreground", default: true)
    semanticContainer = control.boolean("semantic_container", default: true)

    backgroundColor =
      parseColor(control.string("bgcolor"))
      ?? parseColor(componentTheme?["color"] as? String)
      ?? Self.defaultBackground(variant: variant, theme: theme, useMaterial3: useMaterial3)
    shadowColor =
      parseColor(control.string("shadow_color"))
      ?? parseColor(componentTheme?["shadow_color"] as? String)
      ?? theme?.colorScheme?["shadow"]
      ?? .black
    margin =
      parseMargin(control.dynamicValue("margin"))
      ?? parseMargin(componentTheme?["margin"])
      ?? RufletLayoutDefaults.cardMargin

    let explicitSide = parseBorderSide(
      shape?["side"],
      defaultColor: theme?.colorScheme?["outline_variant"] ?? .secondary)
    if let explicitSide {
      borderSide = explicitSide
    } else if useMaterial3 && variant == .outlined && shapeValue == nil {
      borderSide = RufletBorderSide(
        width: 1,
        color: theme?.colorScheme?["outline_variant"] ?? .secondary.opacity(0.5))
    } else {
      borderSide = nil
    }
  }

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }

  var borderLayer: RufletCardBorderLayer {
    guard borderSide != nil else { return .none }
    return showBorderOnForeground ? .foreground : .background
  }

  private static func defaultBackground(
    variant: RufletCardVariant,
    theme: RufletTheme?,
    useMaterial3: Bool
  ) -> Color {
    guard useMaterial3 else {
      return theme?.colorScheme?["surface"] ?? .rufletSystemBackground
    }
    let role =
      switch variant {
      case .elevated: "surface_container_low"
      case .filled: "surface_container_highest"
      case .outlined: "surface"
      }
    return theme?.colorScheme?[role] ?? .rufletSystemBackground
  }
}

@MainActor
public struct CardControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletPageTheme) private var pageTheme

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletCardPresentation(control: control, theme: pageTheme)
    let shape = RufletCornerShape(radius: presentation.radius)

    LayoutControl(control: control) {
      ZStack {
        if presentation.borderLayer == .background {
          outline(shape, side: presentation.borderSide)
        }
        control.buildWidget("content")
      }
      .modifier(RufletCardClipModifier(shape: shape, presentation: presentation))
      .background {
        // Material elevation belongs to the card surface, not to its child
        // subtree. Shadowing the composed view makes every glyph and icon
        // cast a second blurred copy.
        shape
          .fill(presentation.backgroundColor)
          .shadow(
            color: presentation.elevation > 0 ? presentation.shadowColor : .clear,
            radius: presentation.elevation)
      }
      .overlay {
        if presentation.borderLayer == .foreground {
          outline(shape, side: presentation.borderSide)
        }
      }
      .padding(presentation.margin)
      .accessibilityElement(children: presentation.semanticContainer ? .contain : .ignore)
    }
  }

  private func outline(_ shape: RufletCornerShape, side: RufletBorderSide?) -> some View {
    return shape.stroke(
      side?.color ?? .clear,
      lineWidth: side?.width ?? 0)
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
