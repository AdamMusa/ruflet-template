import RufletEngine
import RufletProtocol
import SwiftUI

/// Turns Flet's `TextStyle` vocabulary into SwiftUI font and colour modifiers.
///
/// The same shape appears inline on a `Text` (`size`, `weight`, `italic`, …)
/// and nested under a `style` map, and controls such as `ListTile` and `Chip`
/// carry their own `*_text_style` slots, so it is resolved once here.
public struct RufletTextStyle {
  public var size: CGFloat?
  public var weight: Font.Weight?
  public var italic = false
  public var color: Color?
  public var backgroundColor: Color?
  public var fontFamily: String?
  public var letterSpacing: CGFloat?
  public var lineHeight: CGFloat?
  public var decoration: TextDecoration = []
  public var themeStyle: Font.TextStyle?
  var materialThemeMetric: MaterialTextThemeMetric?

  struct MaterialTextThemeMetric: Equatable {
    let size: CGFloat
    let lineHeight: CGFloat
    let weight: Font.Weight
    let nativeAnchor: Font.TextStyle
  }

  public struct TextDecoration: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let underline = TextDecoration(rawValue: 1)
    public static let overline = TextDecoration(rawValue: 2)
    public static let lineThrough = TextDecoration(rawValue: 4)
  }

  /// Reads a style map, then lets the control's own inline props override it —
  /// the precedence Flet applies.
  /// An unstyled starting point, for a slot Ruby gave a bare value rather
  /// than a style map.
  public init() {}

  /// `Text` carries its own typography beside the `style` map, and Flet layers
  /// the two: the theme style is the base, `style` refines it, and the
  /// top-level `size`, `weight`, `italic`, `font_family`, `color` and
  /// `bgcolor` override whatever the map set.
  static func forText(node: ControlNode) -> RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "style")
    if let theme = node.string("theme_style") { style.applyThemeStyle(theme) }
    if let size = node.double("size") { style.size = CGFloat(size) }
    if let weight = node.string("weight") { style.weight = fontWeight(weight) }
    if node.bool("italic") == true { style.italic = true }
    if let family = node.string("font_family")
      ?? node.array("font_family_fallback")?.first?.stringValue
    {
      style.fontFamily = family
    }
    if let color = MaterialPalette.color(node.string("color")) { style.color = color }
    if let background = MaterialPalette.color(node.string("bgcolor")) {
      style.backgroundColor = background
    }
    return style
  }

  /// Flutter's `TextTheme` slots, which Flet passes through by name.
  static func themeTextStyle(_ name: String) -> Font.TextStyle? {
    materialMetric(name)?.nativeAnchor
  }

  /// Flutter 3's generated Material 3 type scale. These are semantic values
  /// resolved by `ThemeData.textTheme`; using a native SwiftUI font does not
  /// permit collapsing distinct Flet roles onto one Apple point size.
  static func materialMetric(_ name: String) -> MaterialTextThemeMetric? {
    let regular = Font.Weight.regular
    let medium = Font.Weight.medium
    switch name.lowercased().replacingOccurrences(of: "_", with: "") {
    case "displaylarge": return .init(size: 57, lineHeight: 64, weight: regular, nativeAnchor: .largeTitle)
    case "displaymedium": return .init(size: 45, lineHeight: 52, weight: regular, nativeAnchor: .largeTitle)
    case "displaysmall": return .init(size: 36, lineHeight: 44, weight: regular, nativeAnchor: .largeTitle)
    case "headlinelarge": return .init(size: 32, lineHeight: 40, weight: regular, nativeAnchor: .title)
    case "headlinemedium": return .init(size: 28, lineHeight: 36, weight: regular, nativeAnchor: .title2)
    case "headlinesmall": return .init(size: 24, lineHeight: 32, weight: regular, nativeAnchor: .title3)
    case "titlelarge": return .init(size: 22, lineHeight: 28, weight: regular, nativeAnchor: .title3)
    case "titlemedium": return .init(size: 16, lineHeight: 24, weight: medium, nativeAnchor: .headline)
    case "titlesmall": return .init(size: 14, lineHeight: 20, weight: medium, nativeAnchor: .subheadline)
    case "bodylarge": return .init(size: 16, lineHeight: 24, weight: regular, nativeAnchor: .body)
    case "bodymedium": return .init(size: 14, lineHeight: 20, weight: regular, nativeAnchor: .callout)
    case "bodysmall": return .init(size: 12, lineHeight: 16, weight: regular, nativeAnchor: .footnote)
    case "labellarge": return .init(size: 14, lineHeight: 20, weight: medium, nativeAnchor: .caption)
    case "labelmedium": return .init(size: 12, lineHeight: 16, weight: medium, nativeAnchor: .caption)
    case "labelsmall": return .init(size: 11, lineHeight: 16, weight: medium, nativeAnchor: .caption2)
    default: return nil
    }
  }

  private mutating func applyThemeStyle(_ name: String) {
    materialThemeMetric = Self.materialMetric(name)
    themeStyle = materialThemeMetric?.nativeAnchor
  }

  static func fontWeight(_ name: String) -> Font.Weight? {
    switch name.lowercased().replacingOccurrences(of: "w", with: "") {
    case "100", "thin": return .thin
    case "200", "extralight": return .ultraLight
    case "300", "light": return .light
    case "400", "normal", "regular": return .regular
    case "500", "medium": return .medium
    case "600", "semibold": return .semibold
    case "700", "bold": return .bold
    case "800", "extrabold": return .heavy
    case "900", "black": return .black
    default: return nil
    }
  }

  init(node: ControlNode, styleKey: String = "style") {
    if let style = node.map(styleKey) {
      apply(map: style)
    }
    apply(map: node.props)
  }

  public init(map: [String: RufletValue]) {
    apply(map: map)
  }

  private mutating func apply(map: [String: RufletValue]) {
    if let value = map["size"]?.doubleValue { size = CGFloat(value) }
    if let value = map["weight"]?.stringValue { weight = Self.weight(value) }
    if let value = map["italic"]?.boolValue { italic = value }
    if let value = map["color"]?.stringValue, let color = MaterialPalette.color(value) {
      self.color = color
    }
    if let value = map["bgcolor"]?.stringValue, let color = MaterialPalette.color(value) {
      backgroundColor = color
    }
    if let value = map["font_family"]?.stringValue { fontFamily = value }
    if let value = map["letter_spacing"]?.doubleValue { letterSpacing = CGFloat(value) }
    if let value = map["height"]?.doubleValue { lineHeight = CGFloat(value) }
    if let value = map["decoration"]?.intValue {
      decoration = TextDecoration(rawValue: value)
    }
    if let value = map["theme_style"]?.stringValue { applyThemeStyle(value) }
  }

  /// Flet weights are Flutter's `w100`…`w900` plus `bold`/`normal`.
  static func weight(_ raw: String) -> Font.Weight? {
    switch raw.lowercased() {
    case "w100", "thin": return .thin
    case "w200", "extralight", "ultralight": return .ultraLight
    case "w300", "light": return .light
    case "w400", "normal", "regular": return .regular
    case "w500", "medium": return .medium
    case "w600", "semibold": return .semibold
    case "w700", "bold": return .bold
    case "w800", "extrabold": return .heavy
    case "w900", "black": return .black
    default: return nil
    }
  }

  /// Flet's `TextThemeStyle`, mapped onto the platform's type ramp so text
  /// scales with the user's Dynamic Type setting.
  static func themeStyle(_ raw: String) -> Font.TextStyle? {
    materialMetric(raw)?.nativeAnchor
  }

  /// The resolved font: an explicit size wins, otherwise the theme ramp, and
  /// a custom family replaces the system face while keeping the size.
  public var font: Font {
    var base: Font
    if let size {
      base = fontFamily.map { Font.custom($0, size: size) } ?? Font.system(size: size)
    } else if let metric = materialThemeMetric {
      base = fontFamily.map {
        Font.custom($0, size: metric.size, relativeTo: metric.nativeAnchor)
      } ?? Font.system(size: metric.size, weight: metric.weight)
    } else if let themeStyle {
      base = fontFamily.map { Font.custom($0, size: Self.pointSize(themeStyle), relativeTo: themeStyle) }
        ?? Font.system(themeStyle)
    } else {
      base = fontFamily.map { Font.custom($0, size: 17, relativeTo: .body) } ?? Font.body
    }
    if let weight { base = base.weight(weight) }
    if italic { base = base.italic() }
    return base
  }

  /// SwiftUI's `lineSpacing` is the extra leading between nominal font boxes;
  /// Flutter's `height` is a multiplier and Material TextTheme supplies an
  /// absolute line height. Convert both forms without confusing either value
  /// for raw extra spacing.
  var swiftUILineSpacing: CGFloat {
    let baseSize = size ?? materialThemeMetric?.size
    if let multiplier = lineHeight, let baseSize {
      return max(0, baseSize * multiplier - baseSize)
    }
    if let metric = materialThemeMetric {
      return max(0, metric.lineHeight - metric.size)
    }
    return 0
  }

  /// Nominal point sizes for the type ramp, needed when a custom family has to
  /// be anchored to a text style.
  private static func pointSize(_ style: Font.TextStyle) -> CGFloat {
    switch style {
    case .largeTitle: return 34
    case .title: return 28
    case .title2: return 22
    case .title3: return 20
    case .headline, .body: return 17
    case .callout: return 16
    case .subheadline: return 15
    case .footnote: return 13
    case .caption: return 12
    case .caption2: return 11
    @unknown default: return 17
    }
  }
}

extension Text {
  /// Applies a resolved style, including the decorations that only `Text`
  /// carries on the platform versions this package supports.
  func rufletStyled(_ style: RufletTextStyle) -> Text {
    var styled = self.font(style.font)
    if let color = style.color { styled = styled.foregroundColor(color) }
    if style.decoration.contains(.underline) { styled = styled.underline() }
    if style.decoration.contains(.lineThrough) { styled = styled.strikethrough() }
    if let spacing = style.letterSpacing { styled = styled.kerning(spacing) }
    return styled
  }
}

public extension View {
  /// Applies the parts of a style that any view can carry, for controls whose
  /// label is not a bare `Text`.
  func rufletTextStyle(_ style: RufletTextStyle) -> some View {
    self
      .font(style.font)
      .modifier(ExplicitTextStyleColor(color: style.color))
      .background(style.backgroundColor)
  }
}

private struct ExplicitTextStyleColor: ViewModifier {
  let color: Color?
  func body(content: Content) -> some View {
    if let color { content.foregroundColor(color) } else { content }
  }
}
