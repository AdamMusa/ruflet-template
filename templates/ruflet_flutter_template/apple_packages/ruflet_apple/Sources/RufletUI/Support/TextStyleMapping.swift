import RufletEngine
import RufletProtocol
import SwiftUI

/// Turns Flet's `TextStyle` vocabulary into SwiftUI font and colour modifiers.
///
/// The same shape appears inline on a `Text` (`size`, `weight`, `italic`, …)
/// and nested under a `style` map, and controls such as `ListTile` and `Chip`
/// carry their own `*_text_style` slots, so it is resolved once here.
struct RufletTextStyle {
  var size: CGFloat?
  var weight: Font.Weight?
  var italic = false
  var color: Color?
  var backgroundColor: Color?
  var fontFamily: String?
  var letterSpacing: CGFloat?
  var lineHeight: CGFloat?
  var decoration: TextDecoration = []
  var themeStyle: Font.TextStyle?

  struct TextDecoration: OptionSet {
    let rawValue: Int
    static let underline = TextDecoration(rawValue: 1)
    static let overline = TextDecoration(rawValue: 2)
    static let lineThrough = TextDecoration(rawValue: 4)
  }

  /// Reads a style map, then lets the control's own inline props override it —
  /// the precedence Flet applies.
  init(node: ControlNode, styleKey: String = "style") {
    if let style = node.map(styleKey) {
      apply(map: style)
    }
    apply(map: node.props)
  }

  init(map: [String: RufletValue]) {
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
    if let value = map["height"]?.doubleValue, map["size"] != nil { lineHeight = CGFloat(value) }
    if let value = map["decoration"]?.intValue {
      decoration = TextDecoration(rawValue: value)
    }
    if let value = map["theme_style"]?.stringValue { themeStyle = Self.themeStyle(value) }
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
    switch raw.lowercased().replacingOccurrences(of: "_", with: "") {
    case "displaylarge", "displaymedium": return .largeTitle
    case "displaysmall", "headlinelarge": return .title
    case "headlinemedium": return .title2
    case "headlinesmall", "titlelarge": return .title3
    case "titlemedium": return .headline
    case "titlesmall": return .subheadline
    case "bodylarge": return .body
    case "bodymedium": return .callout
    case "bodysmall": return .footnote
    case "labellarge", "labelmedium": return .caption
    case "labelsmall": return .caption2
    default: return nil
    }
  }

  /// The resolved font: an explicit size wins, otherwise the theme ramp, and
  /// a custom family replaces the system face while keeping the size.
  var font: Font {
    var base: Font
    if let size {
      base = fontFamily.map { Font.custom($0, size: size) } ?? Font.system(size: size)
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

extension View {
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
