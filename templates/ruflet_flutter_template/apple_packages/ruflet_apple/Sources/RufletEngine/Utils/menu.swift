import SwiftUI

struct RufletMenuStyle {
  let alignment: RufletAlignment?
  let backgroundColor: RufletWidgetStateProperty<Color>
  let shadowColor: RufletWidgetStateProperty<Color>
  let elevation: RufletWidgetStateProperty<Double>
  let padding: RufletWidgetStateProperty<EdgeInsets>
  let side: RufletWidgetStateProperty<RufletBorderSide>
  let minimumSize: RufletWidgetStateProperty<CGSize>
  let maximumSize: RufletWidgetStateProperty<CGSize>
  let fixedSize: RufletWidgetStateProperty<CGSize>
  let mouseCursor: String?
  let visualDensity: RufletVisualDensity?
}

func parseMenuStyle(
  _ value: Any?, defaultBackgroundColor: Color? = nil,
  defaultShadowColor: Color? = nil, defaultElevation: Double? = nil,
  defaultAlignment: RufletAlignment? = nil, defaultPadding: EdgeInsets? = nil,
  defaultBorderSide: RufletBorderSide? = nil, defaultMinimumSize: CGSize? = nil,
  defaultMaximumSize: CGSize? = nil, defaultFixedSize: CGSize? = nil,
  defaultValue: RufletMenuStyle? = nil
) -> RufletMenuStyle? {
  guard let value = rufletDictionary(value) else { return defaultValue }
  return RufletMenuStyle(
    alignment: parseAlignment(value["alignment"], defaultAlignment),
    backgroundColor: .init(value["bgcolor"], converter: { raw in
      parseColor(raw as? String)
    }, defaultValue: defaultBackgroundColor),
    shadowColor: .init(value["shadow_color"], converter: { raw in
      parseColor(raw as? String)
    }, defaultValue: defaultShadowColor),
    elevation: .init(value["elevation"], converter: { parseDouble($0) }, defaultValue: defaultElevation),
    padding: .init(value["padding"], converter: { parsePadding($0) }, defaultValue: defaultPadding),
    side: .init(value["side"], converter: { parseBorderSide($0) }, defaultValue: defaultBorderSide),
    minimumSize: .init(value["min_size"], converter: { parseSize($0) }, defaultValue: defaultMinimumSize),
    maximumSize: .init(value["max_size"], converter: { parseSize($0) }, defaultValue: defaultMaximumSize),
    fixedSize: .init(value["fixed_size"], converter: { parseSize($0) }, defaultValue: defaultFixedSize),
    mouseCursor: value["mouse_cursor"] as? String,
    visualDensity: parseVisualDensity(value["visual_density"] as? String))
}

@MainActor
extension RufletControl {
  func menuStyle(_ propertyName: String, default defaultValue: RufletMenuStyle? = nil) -> RufletMenuStyle? {
    parseMenuStyle(dynamicValue(propertyName), defaultValue: defaultValue)
  }
}
