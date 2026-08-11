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

    // Flutter's `_FABDefaultsM3`. Flet passes no colours to
    // FloatingActionButton at all, so these are the theme's, not Flet's.
    case ("FloatingActionButton", "bgcolor"):
      return "primarycontainer"
    case ("FloatingActionButton", "foreground_color"):
      return "onprimarycontainer"

    // Flutter receives nil for omitted selection colours and resolves them
    // through the Material theme. These are the corresponding Material 3
    // roles used by the native marks/tracks, not control-local constants.
    case ("Checkbox", "active_color"), ("Radio", "active_color"),
         ("Slider", "active_color"), ("RangeSlider", "active_color"):
      return "primary"
    case ("Checkbox", "inactive_color"), ("Radio", "inactive_color"):
      return "onsurfacevariant"

    // Flutter's `_SwitchDefaultsM3`. The switch is the one selection control
    // whose thumb and track are coloured independently, so `active_color` is
    // its *thumb* — naming it `primary` alongside the others would have
    // painted the thumb the colour of the track it sits on.
    case ("Switch", "active_color"):
      return "onprimary"
    case ("Switch", "inactive_thumb_color"):
      return "outline"
    case ("Switch", "active_track_color"):
      return "primary"
    case ("Switch", "inactive_track_color"):
      return "surfacecontainerhighest"
    case ("Switch", "track_outline_color"):
      return "outline"
    case ("Slider", "inactive_color"), ("RangeSlider", "inactive_color"):
      return "surfacecontainerhighest"
    case ("Slider", "thumb_color"), ("RangeSlider", "thumb_color"):
      return "primary"
    case ("Slider", "secondary_active_color"):
      return "primary,0.54"
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

  // Flutter's `_IconButtonDefaultsM3` geometry: a 40×40 target holding a 24pt
  // glyph inside 8pt of padding.
  static let materialIconButtonTargetSize: CGFloat = 40
  static let materialIconButtonPadding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

  /// The container, glyph and outline an icon button resolves to when Ruby
  /// named no colour.
  ///
  /// Flutter keeps one set of these per variant (`_IconButtonDefaultsM3`,
  /// `_FilledIconButtonDefaultsM3`, and the tonal and outlined pairs) and
  /// resolves them against the button's material state. Two of those states
  /// are visible here: `selected`, and Flutter's *toggleable* case, which is
  /// the button having been given an `is_selected` at all. A filled icon
  /// button that can be toggled is a tinted surface while it is off, and the
  /// primary container once it is on; one that cannot be toggled is always
  /// the primary container. Distinguishing them needs `selected` to stay
  /// optional, hence the triple state rather than a Bool.
  struct IconButtonPalette: Equatable {
    var background: String?
    var foreground: String?
    var outline: String?
  }

  static func iconButtonPalette(
    control: String,
    selected: Bool?,
    disabled: Bool
  ) -> IconButtonPalette {
    // Flutter's disabled states are the same two opacities on onSurface for
    // every variant: 0.12 behind, 0.38 in front.
    let disabledBackground = "onsurface,0.12"
    let disabledForeground = "onsurface,0.38"
    let toggleable = selected != nil
    let isOn = selected == true

    switch control {
    case "FilledIconButton":
      if disabled {
        return IconButtonPalette(background: disabledBackground, foreground: disabledForeground)
      }
      if isOn || !toggleable {
        return IconButtonPalette(background: "primary", foreground: "onprimary")
      }
      return IconButtonPalette(background: "surfacecontainerhighest", foreground: "primary")

    case "FilledTonalIconButton":
      if disabled {
        return IconButtonPalette(background: disabledBackground, foreground: disabledForeground)
      }
      if isOn || !toggleable {
        return IconButtonPalette(
          background: "secondarycontainer", foreground: "onsecondarycontainer")
      }
      return IconButtonPalette(
        background: "surfacecontainerhighest", foreground: "onsurfacevariant")

    case "OutlinedIconButton":
      if disabled {
        return IconButtonPalette(
          background: isOn ? disabledBackground : nil,
          foreground: disabledForeground,
          outline: isOn ? nil : disabledBackground)
      }
      if isOn {
        return IconButtonPalette(background: "inversesurface", foreground: "oninversesurface")
      }
      return IconButtonPalette(foreground: "onsurfacevariant", outline: "outline")

    default:
      // The standard IconButton has no container at all; only the glyph moves,
      // to primary once the button is on.
      if disabled { return IconButtonPalette(foreground: disabledForeground) }
      return IconButtonPalette(foreground: isOn ? "primary" : "onsurfacevariant")
    }
  }

  // Flutter's `_FABDefaultsM3`: a 56pt container on a 16pt rounded rectangle,
  // 40pt and 12pt when mini, and a 56pt pill when extended. The four
  // elevations are the FAB's resting, hovered, focused and pressed states.
  static let floatingActionButtonSize: CGFloat = 56
  static let floatingActionButtonMiniSize: CGFloat = 40
  static let floatingActionButtonRadius: CGFloat = 16
  static let floatingActionButtonMiniRadius: CGFloat = 12
  static let floatingActionButtonElevation = 6.0
  static let floatingActionButtonHoverElevation = 8.0
  static let floatingActionButtonFocusElevation = 6.0
  static let floatingActionButtonHighlightElevation = 6.0
  static let floatingActionButtonDisabledElevation = 0.0
  /// The extended FAB's asymmetric inset — 16pt before the icon, 20pt after
  /// the label — and the gap Flutter leaves between them.
  static let floatingActionButtonExtendedPadding =
    EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 20)
  static let floatingActionButtonExtendedIconSpacing: CGFloat = 12

  // Flutter's `_SwitchConfigM3`: a 52×32 track whose thumb grows from 16pt to
  // 24pt as it travels, with a 2pt outline while the switch is off.
  static let switchTrackWidth: CGFloat = 52
  static let switchTrackHeight: CGFloat = 32
  static let switchThumbSize: CGFloat = 16
  static let switchSelectedThumbSize: CGFloat = 24
  static let switchThumbIconSize: CGFloat = 16
  static let switchThumbInset: CGFloat = 4
  static let switchTrackOutlineWidth: CGFloat = 2

  /// The slider's two shapes.
  ///
  /// Flutter's `year2023` flag chooses between the original Material 3 slider
  /// — a 4pt track under a round 20pt thumb — and the 2024 revision, which
  /// thickens the track to 16pt and narrows the thumb to a 4pt bar. Flet
  /// passes the flag through unset, so Flutter's own default (the 2023 shape)
  /// is what an unconfigured slider gets.
  struct SliderMetrics: Equatable {
    var trackHeight: CGFloat
    var thumbWidth: CGFloat
    var thumbHeight: CGFloat
    var overlayRadius: CGFloat
    var height: CGFloat

    /// The width a thumb occupies horizontally, which is what the track's
    /// travel is measured against.
    var thumbFootprint: CGFloat { thumbWidth }
  }

  static func sliderMetrics(year2023: Bool?) -> SliderMetrics {
    guard year2023 == false else {
      return SliderMetrics(
        trackHeight: 4, thumbWidth: 20, thumbHeight: 20, overlayRadius: 20, height: 48)
    }
    return SliderMetrics(
      trackHeight: 16, thumbWidth: 4, thumbHeight: 44, overlayRadius: 20, height: 48)
  }

  /// Flet's `Slider(label:)` substitutes the thumb's value into this token.
  static let sliderLabelValueToken = "{value}"

  // Flutter's `_CheckboxDefaultsM3`: an 18pt box on a 2pt radius, with a 2pt
  // outline, inside the 40pt target the ripple uses.
  static let checkboxSize: CGFloat = 18
  static let checkboxCornerRadius: CGFloat = 2
  static let checkboxBorderWidth: CGFloat = 2
  static let checkboxTargetSize: CGFloat = 40
  static let checkboxMarkSize: CGFloat = 12

  // Flutter's `_RadioDefaultsM3`: a 20pt ring on a 2pt stroke, with a 10pt dot,
  // inside the same 40pt target the checkbox uses.
  static let radioSize: CGFloat = 20
  static let radioBorderWidth: CGFloat = 2
  static let radioDotSize: CGFloat = 10
  static let radioTargetSize: CGFloat = 40

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
