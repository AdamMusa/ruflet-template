import RufletEngine
import SwiftUI

/// The Material and Flutter constants the display family resolves from
/// `ThemeData` rather than from the wire.
///
/// These sit beside `RufletThemeDefaults` instead of inside it so Icon, Image,
/// CircleAvatar, the two progress indicators and Markdown can be ported
/// without touching the table every other control family shares.
extension RufletThemeDefaults {

  // MARK: - Colour roles

  /// Roles Flet never puts on the wire because the Flutter widget resolves
  /// them from the theme itself.
  static func displayColorToken(control: String, property: String) -> String? {
    switch (control, property) {
    // Flutter's CircleAvatar under Material 3 fills with the primary container
    // and writes its initials in the matching `on` role.
    case ("CircleAvatar", "bgcolor"):
      return "primarycontainer"
    case ("CircleAvatar", "color"):
      return "onprimarycontainer"

    // `_LinearProgressIndicatorDefaultsM3.stopIndicatorColor`.
    case ("ProgressBar", "stop_indicator_color"):
      return "primary"

    // `MarkdownStyleSheet.fromTheme` paints links Material blue, quotes on a
    // blue-100 card, and takes the rule and table borders from the theme's
    // divider colour. `theme.cardColor` is `surfaceContainerLow` under M3.
    case ("Markdown", "link_color"):
      return "blue"
    case ("Markdown", "blockquote_color"):
      return "blue100"
    case ("Markdown", "codeblock_color"):
      return "surfacecontainerlow"
    case ("Markdown", "divider_color"):
      return "outlinevariant"

    default:
      return nil
    }
  }

  /// The explicit wire colour when Ruby supplied one, otherwise the pinned
  /// Flutter role above. Tests compare tokens rather than platform `Color`s,
  /// which is why resolution stops at the string.
  static func resolvedDisplayColorToken(for node: ControlNode, property: String) -> String? {
    if let explicit = node.props[property]?.stringValue,
      !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return explicit
    }
    return displayColorToken(control: node.type, property: property)
  }

  // MARK: - Progress indicators

  // Flutter's `_LinearProgressIndicatorDefaultsM3` and its `Year2023`
  // counterpart. `year2023` still defaults to true upstream, so an
  // unconfigured bar keeps square ends, a full-width track and no stop dot;
  // only `year_2023: false` turns the 2024 radius, gap and dot on.
  static let linearProgressHeight: CGFloat = 4
  static let linearProgressCornerRadius: CGFloat = 2
  static let linearProgressStopIndicatorRadius: CGFloat = 2
  static let linearProgressTrackGap: CGFloat = 4
  /// `_kIndeterminateLinearDuration`, in seconds.
  static let linearProgressIndeterminateDuration = 1.8

  // Flutter's `_CircularProgressIndicatorDefaultsM3`. The 2024 shape draws its
  // stroke fully inside a 40pt box with 4pt of padding; the 2023 shape centres
  // the stroke on the edge of a 36pt box and has no padding.
  static let circularProgressStrokeWidth: CGFloat = 4
  static let circularProgressDiameter: CGFloat = 40
  static let circularProgressLegacyDiameter: CGFloat = 36
  static let circularProgressTrackGap: CGFloat = 4
  static let circularProgressPadding = EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
  /// One full turn of the indeterminate arc, in seconds.
  static let circularProgressIndeterminateDuration = 1.333

  // MARK: - CircleAvatar

  /// `CircleAvatar._defaultRadius`, used only when radius, min and max are all
  /// absent — a lone `min_radius` leaves the avatar unbounded instead.
  static let circleAvatarRadius: CGFloat = 20

  // MARK: - Markdown

  // `MarkdownStyleSheet.fromTheme`, which is what MarkdownBody falls back to
  // when Ruby sent no `md_style_sheet`.
  static let markdownBlockSpacing: CGFloat = 8
  static let markdownListIndent: CGFloat = 24
  static let markdownListBulletGap: CGFloat = 4
  static let markdownBlockquotePadding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
  static let markdownBlockquoteRadius: CGFloat = 2
  static let markdownCodeblockPadding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
  static let markdownCodeblockRadius: CGFloat = 2
  static let markdownRuleThickness: CGFloat = 5
  static let markdownTablePadding = EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)
  static let markdownTableCellPadding = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

  /// Material's `bodyMedium` is 14pt, and `fromTheme` renders code at 85% of
  /// it. Both numbers are needed because the code block is drawn with an
  /// explicit monospaced face rather than a font family name.
  static let markdownBodyFontSize: CGFloat = 14
  static let markdownCodeFontScale: CGFloat = 0.85

  /// `LatexElementBuilder` leaves its scale factor at 1 when Flet sends none.
  static let markdownLatexScaleFactor: CGFloat = 1

  /// The `root` entry of a flutter_highlight theme: the only part of a code
  /// theme this renderer can honour, since tokenising the source would need
  /// highlight.dart's language grammars.
  struct MarkdownCodeThemeRoot: Equatable {
    var foreground: String
    var background: String
  }

  /// flutter_highlight's `themeMap` is a ninety-entry data table Ruflet does
  /// not vendor. The themes below are pinned from it verbatim; any other name
  /// resolves to no theme at all, which is what Flutter's `parseMarkdownCodeTheme`
  /// does for a name it cannot find.
  static func markdownCodeThemeRoot(named name: String) -> MarkdownCodeThemeRoot? {
    switch name.lowercased().replacingOccurrences(of: "_", with: "-") {
    case "github":
      return MarkdownCodeThemeRoot(foreground: "#24292e", background: "#ffffff")
    case "atom-one-dark":
      return MarkdownCodeThemeRoot(foreground: "#abb2bf", background: "#282c34")
    case "monokai-sublime":
      return MarkdownCodeThemeRoot(foreground: "#f8f8f2", background: "#23241f")
    case "vs2015":
      return MarkdownCodeThemeRoot(foreground: "#dcdcdc", background: "#1e1e1e")
    default:
      return nil
    }
  }
}
