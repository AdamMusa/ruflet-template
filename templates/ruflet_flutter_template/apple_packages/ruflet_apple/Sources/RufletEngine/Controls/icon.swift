import SwiftUI

@MainActor
public struct IconControl: View {
  @ObservedObject public var control: RufletControl
  @EnvironmentObject private var registry: RufletExtensionRegistry

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    let presentation = RufletIconPresentation(control: control)
    LayoutControl(control: control) {
      RufletScaledIcon(
        icon: icon,
        presentation: presentation,
        color: parseColor(control.string("color")) ?? .primary,
        semanticsLabel: control.string("semantics_label"))
    }
  }

  private var icon: RufletAppleIcon {
    guard let code = control.integer("icon"), let icon = registry.appleIcon(for: code) else {
      preconditionFailure("Unknown Ruflet icon: \(control.string("icon") ?? "nil")")
    }
    return icon
  }
}

@MainActor
struct RufletIconPresentation {
  let size: CGFloat
  let applyTextScaling: Bool
  let fill: Double?
  let weight: Font.Weight
  let opticalSize: CGFloat?
  let blendMode: BlendMode
  let shadows: [RufletIconShadow]

  init(control: RufletControl) {
    size = CGFloat(max(control.number("size") ?? 24, 0))
    applyTextScaling = control.boolean("apply_text_scaling", default: false)
    fill = control.number("fill").map { min(max($0, 0), 1) }
    weight = Self.fontWeight(
      weight: control.number("weight"),
      grade: control.number("grade"))
    opticalSize = control.number("optical_size").map { CGFloat(max($0, 0.001)) }
    blendMode = Self.blendMode(control.string("blend_mode"))
    shadows =
      rufletArray(control.dynamicValue("shadows"))?.compactMap(RufletIconShadow.init)
      ?? []
  }

  static func fontWeight(weight: Double?, grade: Double?) -> Font.Weight {
    let value = min(max((weight ?? 400) + (grade ?? 0), 1), 1_000)
    switch value {
    case ..<150: return .ultraLight
    case ..<250: return .thin
    case ..<350: return .light
    case ..<550: return .regular
    case ..<650: return .semibold
    case ..<750: return .bold
    case ..<850: return .heavy
    default: return .black
    }
  }

  static func blendMode(_ value: String?) -> BlendMode {
    switch value?.replacingOccurrences(of: "_", with: "").lowercased() {
    case "clear", "dstout", "destinationout": return .destinationOut
    case "srcin", "sourcein", "srcatop", "sourceatop": return .sourceAtop
    case "dstover", "destinationover", "dstatop", "destinationatop": return .destinationOver
    case "xor", "difference": return .difference
    case "plus": return .plusLighter
    case "modulate", "multiply": return .multiply
    case "screen": return .screen
    case "overlay": return .overlay
    case "darken": return .darken
    case "lighten": return .lighten
    case "colordodge": return .colorDodge
    case "colorburn": return .colorBurn
    case "hardlight": return .hardLight
    case "softlight": return .softLight
    case "exclusion": return .exclusion
    case "hue": return .hue
    case "saturation": return .saturation
    case "color": return .color
    case "luminosity": return .luminosity
    default: return .normal
    }
  }
}

struct RufletIconShadow {
  let color: Color
  let radius: CGFloat
  let x: CGFloat
  let y: CGFloat

  init?(_ value: Any?) {
    guard let values = rufletDictionary(value) else { return nil }
    let offset = parseOffset(values["offset"], .zero)!
    color = parseColor(values["color"] as? String, .black)!
    radius = CGFloat(max(parseDouble(values["blur_radius"], 0)!, 0))
    x = offset.width
    y = offset.height
  }
}

private struct RufletScaledIcon: View {
  let icon: RufletAppleIcon
  let presentation: RufletIconPresentation
  let color: Color
  let semanticsLabel: String?

  @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

  var body: some View {
    let resolvedSize = presentation.size * (presentation.applyTextScaling ? textScale : 1)
    let renderingSize = presentation.opticalSize ?? resolvedSize
    RufletAppleIconView.registered(
      icon: icon,
      size: renderingSize,
      weight: presentation.weight
    )
    .symbolVariant((presentation.fill ?? 0) > 0 ? .fill : .none)
    .scaleEffect(renderingSize == 0 ? 1 : resolvedSize / renderingSize)
    .frame(width: resolvedSize, height: resolvedSize)
    .foregroundStyle(color)
    .blendMode(presentation.blendMode)
    .modifier(RufletIconShadowModifier(shadows: presentation.shadows))
    .accessibilityLabel(semanticsLabel ?? "")
  }
}

private struct RufletIconShadowModifier: ViewModifier {
  let shadows: [RufletIconShadow]

  func body(content: Content) -> some View {
    var result = AnyView(content)
    for shadow in shadows {
      result = AnyView(
        result.shadow(
          color: shadow.color,
          radius: shadow.radius,
          x: shadow.x,
          y: shadow.y))
    }
    return result
  }
}
