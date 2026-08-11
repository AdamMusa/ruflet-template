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
  /// View's Container uses `EdgeInsets.all(10)` when padding is omitted in
  /// Flet's pinned renderer. This is a widget-constructor default, not a Ruby
  /// DSL value, so it intentionally lives outside generated wire defaults.
  static let viewPadding = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

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

  static let dataTableColumnSpacing: CGFloat = 24
  static let dataTableHeadingHeight: CGFloat = 56
  static let dataTableRowMinHeight: CGFloat = 48
  static let progressRingDiameter: CGFloat = 40
  static let progressStrokeWidth: CGFloat = 4
}
