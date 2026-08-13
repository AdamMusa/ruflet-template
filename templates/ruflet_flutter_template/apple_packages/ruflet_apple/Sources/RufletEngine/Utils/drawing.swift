import CoreGraphics
import SwiftUI

enum RufletPaintingStyle: String, CaseIterable, RufletStringEnum {
  case fill
  case stroke
}

enum RufletStrokeCap: String, CaseIterable, RufletStringEnum {
  case butt
  case round
  case square
}

enum RufletStrokeJoin: String, CaseIterable, RufletStringEnum {
  case miter
  case round
  case bevel
}

struct RufletPaint {
  let color: Color
  let blendMode: BlendMode
  let antiAlias: Bool
  let blurSigmaX: Double?
  let blurSigmaY: Double?
  let gradient: RufletGradientSpec?
  let strokeMiterLimit: Double
  let strokeWidth: Double
  let strokeCap: RufletStrokeCap
  let strokeJoin: RufletStrokeJoin
  let style: RufletPaintingStyle
}

func parsePaint(_ value: Any?, _ defaultValue: RufletPaint? = nil) -> RufletPaint? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  let blur = rufletDictionary(value["blur_image"])
  return RufletPaint(
    color: parseColor(value["color"] as? String, .black)!,
    blendMode: parseDrawingBlendMode(value["blend_mode"] as? String),
    antiAlias: parseBool(value["anti_alias"], true)!,
    blurSigmaX: parseDouble(blur?["sigma_x"]),
    blurSigmaY: parseDouble(blur?["sigma_y"]),
    gradient: parseGradient(value["gradient"]),
    strokeMiterLimit: parseDouble(value["stroke_miter_limit"], 4)!,
    strokeWidth: parseDouble(value["stroke_width"], 0)!,
    strokeCap: parseEnum(RufletStrokeCap.self, value["stroke_cap"] as? String, .butt)!,
    strokeJoin: parseEnum(RufletStrokeJoin.self, value["stroke_join"] as? String, .miter)!,
    style: parsePaintingStyle(value["style"] as? String, .fill)!)
}

func parsePaintingStyle(
  _ value: String?, _ defaultValue: RufletPaintingStyle? = nil
) -> RufletPaintingStyle? {
  parseEnum(RufletPaintingStyle.self, value, defaultValue)
}

func parsePaintStrokeDashPattern(
  _ value: Any?, _ defaultValue: [Double]? = nil
) -> [Double]? {
  guard let value = rufletDictionary(value),
        let pattern = rufletArray(value["stroke_dash_pattern"])
  else { return defaultValue }
  return pattern.compactMap { parseDouble($0) }
}

@MainActor
extension RufletControl {
  func paint(_ propertyName: String, default defaultValue: RufletPaint? = nil) -> RufletPaint? {
    parsePaint(dynamicValue(propertyName), defaultValue)
  }

  func paintingStyle(
    _ propertyName: String, default defaultValue: RufletPaintingStyle? = nil
  ) -> RufletPaintingStyle? {
    parsePaintingStyle(string(propertyName), defaultValue)
  }

  func paintStrokeDashPattern(
    _ propertyName: String, default defaultValue: [Double]? = nil
  ) -> [Double]? {
    parsePaintStrokeDashPattern(dynamicValue(propertyName), defaultValue)
  }
}

private func parseDrawingBlendMode(_ value: String?) -> BlendMode {
  switch value?.lowercased() {
  case "multiply": return .multiply
  case "screen": return .screen
  case "overlay": return .overlay
  case "darken": return .darken
  case "lighten": return .lighten
  case "colordodge": return .colorDodge
  case "colorburn": return .colorBurn
  case "softlight": return .softLight
  case "hardlight": return .hardLight
  case "difference": return .difference
  case "exclusion": return .exclusion
  case "hue": return .hue
  case "saturation": return .saturation
  case "color": return .color
  case "luminosity": return .luminosity
  default: return .normal
  }
}
