import RufletEngine
import SwiftUI

/// The presentation defaults that Flet obtains from Flutter's ThemeData and
/// widget constructors rather than from the wire protocol.
///
/// Keep this separate from `FletControlDefaults`: semantic defaults are
/// generated from the pinned Flet Dart source, while these values deliberately
/// choose the native Apple metric or the equivalent Material colour role.
/// Controls should never invent their own fallback colour or platform size.
enum FletThemeDefaults {
  static func colorToken(control: String, property: String) -> String? {
    switch (control, property) {
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

  /// A Material TextField is transparent unless `filled` is true. Flet's
  /// default is `filled: false`; treating omission as a gray fill was the main
  /// source of the renderer's extra background bands.
  static func backgroundToken(for node: ControlNode) -> String? {
    guard node.type == "TextField", node.bool("filled") == true else { return nil }
    return "surfacecontainerhighest"
  }

  static func appBarHeight(_ node: ControlNode) -> CGFloat {
    // Use props directly: the generated semantic layer intentionally excludes
    // Flutter constants such as kToolbarHeight (56), which are not Apple UI
    // metrics.
    if let explicit = node.props["toolbar_height"]?.doubleValue {
      return CGFloat(explicit)
    }
    #if os(iOS)
      return 44
    #else
      return 52
    #endif
  }

  static var minimumInteractiveDimension: CGFloat {
    #if os(iOS)
      return 44
    #else
      return 28
    #endif
  }

  static let dataTableColumnSpacing: CGFloat = 24
  static let dataTableHeadingHeight: CGFloat = 56
  static let dataTableRowMinHeight: CGFloat = 48
  static let progressRingDiameter: CGFloat = 40
  static let progressStrokeWidth: CGFloat = 4
}
