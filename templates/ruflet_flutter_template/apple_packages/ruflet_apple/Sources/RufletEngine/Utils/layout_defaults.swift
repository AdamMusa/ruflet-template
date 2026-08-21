import SwiftUI

/// Layout defaults inherited by the pinned Flet renderers from Flutter 3.x.
///
/// Flet deliberately passes `nil` for many padding and margin properties so
/// the Flutter widget supplies its native default. The Apple renderer does not
/// instantiate those Flutter widgets, so their defaults must be explicit here.
/// Keeping them together makes the otherwise implicit part of the Flet wire
/// contract executable and testable.
enum RufletLayoutDefaults {
  static func alertDialogIcon(hasTitle: Bool, hasContent: Bool) -> EdgeInsets {
    EdgeInsets(
      top: 24,
      leading: 24,
      bottom: hasTitle ? 16 : (hasContent ? 0 : 24),
      trailing: 24)
  }

  static func alertDialogTitle(hasIcon: Bool, hasContent: Bool) -> EdgeInsets {
    EdgeInsets(
      top: hasIcon ? 0 : 24,
      leading: 24,
      bottom: hasContent ? 0 : 20,
      trailing: 24)
  }

  static let alertDialogActions = EdgeInsets(
    top: 0, leading: 24, bottom: 24, trailing: 24)
  static let alertDialogActionButton = EdgeInsets(
    top: 0, leading: 8, bottom: 0, trailing: 8)
  static let appBarLeadingWidth = 56.0
  static let appBarBackIconSize = 24.0
  static let appBarTitleSpacing = 16.0
  static let appBarActions = EdgeInsets()
  static let badge = EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
  static let bottomAppBar = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
  static let cardMargin = EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
  static let chip = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
  static let chipLabel = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
  static let cupertinoNavigationBar = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
  static let cupertinoSegmentedButton = EdgeInsets(
    top: 0, leading: 16, bottom: 0, trailing: 16)
  static let listTile = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 24)
  static let navigationBarLabel = EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0)
  static let navigationRailDestination = EdgeInsets()
  static let popupMenuButton = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
  static let popupMenu = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
  static let popupMenuItem = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
  static let searchBar = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
  static let searchViewBar = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
  static let materialSwitch = EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
  static let primaryTabIcon = EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
  static let tabLabel = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

  static func bannerContent(singleRow: Bool) -> EdgeInsets {
    singleRow
      ? EdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 0)
      : EdgeInsets(top: 24, leading: 16, bottom: 4, trailing: 16)
  }

  static let bannerLeading = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)

  static func bannerMargin(elevation: Double) -> EdgeInsets {
    EdgeInsets(top: 0, leading: 0, bottom: elevation > 0 ? 10 : 0, trailing: 0)
  }

  static func cupertinoListTile(notched: Bool, hasLeading: Bool) -> EdgeInsets {
    if !notched {
      return EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 14)
    }
    if hasLeading {
      return EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
    }
    return EdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 14)
  }

  /// Material 3 InputDecoration defaults used by Flet's form-field helper.
  static func formField(
    outline: Bool,
    filled: Bool,
    dense: Bool,
    collapsed: Bool
  ) -> EdgeInsets {
    if collapsed { return EdgeInsets() }
    if outline {
      return dense
        ? EdgeInsets(top: 16, leading: 12, bottom: 8, trailing: 12)
        : EdgeInsets(top: 20, leading: 12, bottom: 12, trailing: 12)
    }
    if filled {
      return dense
        ? EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        : EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    }
    return dense
      ? EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
      : EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
  }

  static func snackBarContent(
    floating: Bool,
    hasActionOrClose: Bool
  ) -> EdgeInsets {
    let horizontal = floating ? 16.0 : 24.0
    return EdgeInsets(
      top: 14,
      leading: horizontal,
      bottom: 14,
      trailing: hasActionOrClose ? 0 : horizontal)
  }

  static let floatingSnackBarMargin = EdgeInsets(
    top: 5, leading: 15, bottom: 10, trailing: 15)
}
