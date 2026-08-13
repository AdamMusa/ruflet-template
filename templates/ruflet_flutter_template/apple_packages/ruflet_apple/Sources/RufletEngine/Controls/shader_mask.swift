import SwiftUI

/// Apple-native port of Flet's `shader_mask.dart`.
@MainActor
public struct ShaderMaskControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let gradient = parseGradient(control.dynamicValue("shader")) {
        let radius = parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
        RufletGradientShapeStyle(gradient: gradient)
          .mask { control.buildWidget("content") }
          .blendMode(parseShaderBlendMode(control.string("blend_mode")))
          .clipShape(RufletCornerShape(radius: radius))
      } else {
        ErrorControl("ShaderMask.shader must be provided")
      }
    }
  }
}

private func parseShaderBlendMode(_ value: String?) -> BlendMode {
  switch value?.lowercased() {
  case "multiply": .multiply
  case "screen": .screen
  case "overlay": .overlay
  case "darken": .darken
  case "lighten": .lighten
  case "colordodge": .colorDodge
  case "colorburn": .colorBurn
  case "softlight": .softLight
  case "hardlight": .hardLight
  case "difference": .difference
  case "exclusion": .exclusion
  case "hue": .hue
  case "saturation": .saturation
  case "color": .color
  case "luminosity": .luminosity
  default: .multiply
  }
}
