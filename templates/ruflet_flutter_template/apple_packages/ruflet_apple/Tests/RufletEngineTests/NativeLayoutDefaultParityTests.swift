import SwiftUI
import Testing

@testable import RufletEngine

@MainActor
@Suite("Pinned Flet/Flutter native layout defaults")
struct NativeLayoutDefaultParityTests {
  @Test("shared Material and Cupertino insets retain their source defaults")
  func sharedInsets() {
    #expect(RufletLayoutDefaults.appBarLeadingWidth == 56)
    #expect(RufletLayoutDefaults.appBarTitleSpacing == 16)
    expect(RufletLayoutDefaults.alertDialogActions, 0, 24, 24, 24)
    expect(RufletLayoutDefaults.alertDialogActionButton, 0, 8, 0, 8)
    expect(RufletLayoutDefaults.appBarActions, 0, 0, 0, 0)
    expect(RufletLayoutDefaults.badge, 0, 4, 0, 4)
    expect(RufletLayoutDefaults.bottomAppBar, 12, 16, 12, 16)
    expect(RufletLayoutDefaults.cardMargin, 4, 4, 4, 4)
    expect(RufletLayoutDefaults.chip, 8, 8, 8, 8)
    expect(RufletLayoutDefaults.chipLabel, 0, 8, 0, 8)
    expect(RufletLayoutDefaults.cupertinoNavigationBar, 0, 16, 0, 16)
    expect(RufletLayoutDefaults.cupertinoSegmentedButton, 0, 16, 0, 16)
    expect(RufletLayoutDefaults.listTile, 0, 16, 0, 24)
    expect(RufletLayoutDefaults.navigationBarLabel, 4, 0, 0, 0)
    expect(RufletLayoutDefaults.navigationRailDestination, 0, 0, 0, 0)
    expect(RufletLayoutDefaults.popupMenuButton, 8, 8, 8, 8)
    expect(RufletLayoutDefaults.popupMenu, 8, 0, 8, 0)
    expect(RufletLayoutDefaults.popupMenuItem, 0, 12, 0, 12)
    expect(RufletLayoutDefaults.searchBar, 0, 8, 0, 8)
    expect(RufletLayoutDefaults.searchViewBar, 0, 8, 0, 8)
    expect(RufletLayoutDefaults.materialSwitch, 0, 4, 0, 4)
    expect(RufletLayoutDefaults.primaryTabIcon, 0, 0, 10, 0)
    expect(RufletLayoutDefaults.tabLabel, 0, 16, 0, 16)
  }

  @Test("conditional banner and Cupertino list-tile defaults match Flutter")
  func conditionalInsets() {
    expect(
      RufletLayoutDefaults.alertDialogIcon(hasTitle: true, hasContent: true),
      24, 24, 16, 24)
    expect(
      RufletLayoutDefaults.alertDialogIcon(hasTitle: false, hasContent: true),
      24, 24, 0, 24)
    expect(
      RufletLayoutDefaults.alertDialogTitle(hasIcon: false, hasContent: true),
      24, 24, 0, 24)
    expect(
      RufletLayoutDefaults.alertDialogTitle(hasIcon: true, hasContent: false),
      0, 24, 20, 24)

    expect(RufletLayoutDefaults.bannerContent(singleRow: true), 2, 16, 0, 0)
    expect(RufletLayoutDefaults.bannerContent(singleRow: false), 24, 16, 4, 16)
    expect(RufletLayoutDefaults.bannerLeading, 0, 0, 0, 16)
    expect(RufletLayoutDefaults.bannerMargin(elevation: 0), 0, 0, 0, 0)
    expect(RufletLayoutDefaults.bannerMargin(elevation: 1), 0, 0, 10, 0)

    expect(
      RufletLayoutDefaults.cupertinoListTile(notched: false, hasLeading: false),
      0, 20, 0, 14)
    expect(
      RufletLayoutDefaults.cupertinoListTile(notched: true, hasLeading: true),
      0, 14, 0, 14)
    expect(
      RufletLayoutDefaults.cupertinoListTile(notched: true, hasLeading: false),
      10, 28, 10, 14)
  }

  @Test("Material 3 form-field padding covers every inherited branch")
  func formFieldInsets() {
    expect(
      RufletLayoutDefaults.formField(
        outline: true, filled: false, dense: false, collapsed: false),
      20, 12, 12, 12)
    expect(
      RufletLayoutDefaults.formField(
        outline: true, filled: false, dense: true, collapsed: false),
      16, 12, 8, 12)
    expect(
      RufletLayoutDefaults.formField(
        outline: false, filled: true, dense: false, collapsed: false),
      8, 12, 8, 12)
    expect(
      RufletLayoutDefaults.formField(
        outline: false, filled: true, dense: true, collapsed: false),
      4, 12, 4, 12)
    expect(
      RufletLayoutDefaults.formField(
        outline: false, filled: false, dense: false, collapsed: false),
      8, 0, 8, 0)
    expect(
      RufletLayoutDefaults.formField(
        outline: false, filled: false, dense: true, collapsed: false),
      4, 0, 4, 0)
    expect(
      RufletLayoutDefaults.formField(
        outline: true, filled: true, dense: false, collapsed: true),
      0, 0, 0, 0)
  }

  @Test("SnackBar defaults vary with behavior and trailing controls")
  func snackBarInsets() {
    expect(
      RufletLayoutDefaults.snackBarContent(floating: false, hasActionOrClose: false),
      14, 24, 14, 24)
    expect(
      RufletLayoutDefaults.snackBarContent(floating: false, hasActionOrClose: true),
      14, 24, 14, 0)
    expect(
      RufletLayoutDefaults.snackBarContent(floating: true, hasActionOrClose: false),
      14, 16, 14, 16)
    expect(RufletLayoutDefaults.floatingSnackBarMargin, 5, 15, 10, 15)
  }

  private func expect(
    _ value: EdgeInsets,
    _ top: CGFloat,
    _ leading: CGFloat,
    _ bottom: CGFloat,
    _ trailing: CGFloat
  ) {
    #expect(value.top == top)
    #expect(value.leading == leading)
    #expect(value.bottom == bottom)
    #expect(value.trailing == trailing)
  }
}
