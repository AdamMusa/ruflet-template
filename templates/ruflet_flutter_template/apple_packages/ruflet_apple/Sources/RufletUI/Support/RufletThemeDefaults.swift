import RufletEngine
import SwiftUI

/// The presentation defaults that Flet obtains from Flutter's ThemeData and
/// widget constructors rather than from the wire protocol.
///
/// Keep this separate from `RufletControlDefaults`: semantic defaults are
/// generated from the pinned Flet Dart source, while these values deliberately
/// choose the native Apple metric or the equivalent Material colour role.
/// Controls should never invent their own fallback colour or platform size.
enum RufletThemeDefaults {
  /// View's Container uses `EdgeInsets.all(10)` when padding is omitted in
  /// Flet's pinned renderer. This is a widget-constructor default, not a Ruby
  /// DSL value, so it intentionally lives outside generated wire defaults.
  static let viewPadding = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

  static func colorToken(control: String, property: String) -> String? {
    switch (control, property) {
    // Flet 0.80.5 passes these values to parseButtonStyle even when the Ruby
    // control omitted `style`, `color`, and `bgcolor`. Keep the Material roles
    // here rather than teaching each native button a local blue/gray fallback.
    case ("Button", "color"), ("FilledButton", "color"),
         ("FilledTonalButton", "color"), ("OutlinedButton", "color"),
         ("TextButton", "color"), ("SegmentedButton", "color"):
      return "primary"
    case ("Button", "bgcolor"), ("FilledButton", "bgcolor"),
         ("FilledTonalButton", "bgcolor"), ("OutlinedButton", "bgcolor"),
         ("TextButton", "bgcolor"), ("SegmentedButton", "bgcolor"):
      return "surface"
    case ("Button", "overlay_color"), ("FilledButton", "overlay_color"),
         ("FilledTonalButton", "overlay_color"), ("OutlinedButton", "overlay_color"),
         ("TextButton", "overlay_color"), ("SegmentedButton", "overlay_color"):
      return "primary,0.08"
    case ("Button", "shadow_color"), ("FilledButton", "shadow_color"),
         ("FilledTonalButton", "shadow_color"), ("OutlinedButton", "shadow_color"),
         ("TextButton", "shadow_color"), ("SegmentedButton", "shadow_color"):
      return "shadow"
    case ("IconButton", "color"), ("FilledIconButton", "color"),
         ("FilledTonalIconButton", "color"), ("OutlinedIconButton", "color"):
      return "primary"

    // Flutter receives nil for omitted selection colours and resolves them
    // through the Material theme. These are the corresponding Material 3
    // roles used by the native marks/tracks, not control-local constants.
    case ("Checkbox", "active_color"), ("Radio", "active_color"),
         ("Switch", "active_color"), ("Slider", "active_color"),
         ("RangeSlider", "active_color"):
      return "primary"
    case ("Checkbox", "inactive_color"), ("Radio", "inactive_color"):
      return "onsurfacevariant"
    case ("Chip", "selected_color"):
      return "secondarycontainer"
    case ("Chip", "border_color"), ("SegmentedButton", "border_color"):
      return "outlinevariant"
    case ("SegmentedButton", "selected_color"):
      return "secondarycontainer"
    case ("AppBar", "bgcolor"):
      return "surface"
    case ("BottomAppBar", "bgcolor"):
      return "surfacecontainer"
    case ("Card", "color"):
      return "surfacecontainerlow"
    case ("DataTable", "divider_color"), ("Divider", "color"):
      return "outlinevariant"
    case ("ProgressBar", "color"), ("ProgressRing", "color"),
         ("SpinKit", "color"):
      return "primary"
    case ("ProgressBar", "bgcolor"), ("ProgressRing", "bgcolor"):
      return "secondarycontainer"
    case ("TextField", "border_color"):
      return "outline"
    case ("TextField", "focused_border_color"):
      return "primary"
    case ("TextField", "error_border_color"):
      return "error"
    default:
      return nil
    }
  }

  /// Returns the explicit wire value when present, otherwise the pinned Flet
  /// theme role. Tests use this string-level resolver so omitted and explicit
  /// behavior can be verified without comparing platform `Color` objects.
  static func resolvedColorToken(for node: ControlNode, property: String) -> String? {
    if let explicit = node.props[property]?.stringValue,
      !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return explicit
    }
    return colorToken(control: node.type, property: property)
  }

  static let materialButtonPadding = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
  static let materialButtonElevation = 1.0
  static let materialButtonIconSpacing: CGFloat = 8
  static let materialIconButtonSize: CGFloat = 24

  // Defaults passed by Flet to Flutter's CupertinoButton constructor. Padding
  // and colours deliberately remain nil so CupertinoButton/SwiftUI owns the
  // native size and theme appearance.
  static let cupertinoButtonPressedOpacity = 0.4
  static let cupertinoButtonCornerRadius: CGFloat = 8

  static func cupertinoButtonPadding(_ node: ControlNode) -> EdgeInsets? {
    ControlProps.edgeInsets(node.props["padding"])
  }

  static func cupertinoButtonRadius(_ node: ControlNode) -> CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? cupertinoButtonCornerRadius
  }

  static func rangeSliderValues(_ node: ControlNode) -> (start: Double, end: Double) {
    // These are the explicit defaults in Flet's RangeSliderControl. They are
    // independent of min/max and therefore intentionally both zero.
    (node.double("start_value") ?? 0, node.double("end_value") ?? 0)
  }

  /// A Material TextField is transparent unless `filled` is true. Flet's
  /// default is `filled: false`; treating omission as a gray fill was the main
  /// source of the renderer's extra background bands.
  static func backgroundToken(for node: ControlNode) -> String? {
    guard node.type == "TextField", node.bool("filled") == true else { return nil }
    return "surfacecontainerhighest"
  }

  static func appBarHeight(_ node: ControlNode) -> CGFloat {
    // Material AppBar's preferred size is kToolbarHeight on every platform.
    // Explicit CupertinoAppBar/CupertinoNavigationBar controls are rendered by
    // the Cupertino family and retain native Apple metrics there.
    if let explicit = node.props["toolbar_height"]?.doubleValue {
      return CGFloat(explicit)
    }
    return 56
  }

  /// Mirrors Flutter AppBar._getEffectiveCenterTitle(). Flet leaves
  /// `center_title` nullable, so omission must reach the platform rule rather
  /// than being coerced to false by the renderer.
  static func appBarCentersTitle(_ node: ControlNode) -> Bool {
    if let explicit = node.props["center_title"]?.boolValue { return explicit }
    #if os(iOS) || os(macOS)
      return node.controlIDs(forKey: "actions").count < 2
    #else
      return false
    #endif
  }

  static var minimumInteractiveDimension: CGFloat {
    #if os(iOS)
      return 44
    #else
      return 28
    #endif
  }

  // Flutter DataTable constructor/theme fallbacks (Material 3).
  static let dataTableColumnSpacing: CGFloat = 56
  static let dataTableHorizontalMargin: CGFloat = 24
  static let dataTableHeadingHeight: CGFloat = 56
  static let dataTableRowMinHeight: CGFloat = 48
  static let dataTableRowMaxHeight: CGFloat = 48

  // `_LisTileDefaultsM3` values used when ListTileTheme leaves a field null.
  static let listTileContentPadding = EdgeInsets(
    top: 0, leading: 16, bottom: 0, trailing: 24)
  static let listTileHorizontalTitleGap: CGFloat = 16
  static let listTileMinLeadingWidth: CGFloat = 24
  static let listTileMinVerticalPadding: CGFloat = 8
  static let listTileMinHeight: CGFloat = 56

  static let tabBarLabelPadding = EdgeInsets(
    top: 0, leading: 16, bottom: 0, trailing: 16)
  static let tabBarDividerHeight: CGFloat = 1
  static let tabHeight: CGFloat = 46
  static let tabHeightWithIconAndLabel: CGFloat = 72
  static let progressRingDiameter: CGFloat = 40
  static let progressStrokeWidth: CGFloat = 4
}
