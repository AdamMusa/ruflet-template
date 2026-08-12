import RufletEngine
import SwiftUI

extension ControlRegistry {
  /// Lists, grids, tables and tabbed content.
  static func collections(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "ListView":
      return AnyView(ListViewControlView(node: node))
    case "GridView":
      return AnyView(GridViewControlView(node: node))
    case "ReorderableListView":
      return AnyView(ReorderableListControlView(node: node))
    case "PageView":
      return AnyView(PageViewControlView(node: node))
    case "ListTile", "CupertinoListTile":
      return AnyView(ListTileControlView(node: node))
    case "ExpansionTile":
      return AnyView(ExpansionTileControlView(node: node))
    case "ExpansionPanelList":
      return AnyView(ExpansionPanelListControlView(node: node))
    case "Tabs":
      return AnyView(TabsControlView(node: node))
    case "TabBar":
      return AnyView(TabBarControlView(node: node))
    case "TabBarView":
      return AnyView(TabBarViewControlView(node: node))
    case "DataTable":
      return AnyView(DataTableControlView(node: node))
    case "DataTable2":
      return AnyView(MissingBundleControlView(node: node, bundle: "RufletDataTable2"))
    case "ExpansionPanel", "Tab", "DataColumn", "DataRow", "DataCell",
      "NavigationBarDestination", "NavigationRailDestination",
      "NavigationDrawerDestination", "ReorderableDragHandle":
      // Structural children their parent lays out; rendering one standalone
      // would duplicate it.
      return AnyView(EmptyView())
    default:
      return nil
    }
  }

  /// Screen chrome: bars and navigation surfaces.
  static func chrome(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "AppBar":
      return AnyView(AppBarControlView(node: node))
    case "BottomAppBar":
      return AnyView(BottomAppBarControlView(node: node))
    case "NavigationBar":
      return AnyView(NavigationBarControlView(node: node))
    case "NavigationRail":
      return AnyView(NavigationRailControlView(node: node))
    case "NavigationDrawer":
      return AnyView(NavigationDrawerControlView(node: node))
    default:
      return nil
    }
  }

  /// Dialogs, sheets and menus.
  ///
  /// The modal controls render only when the presenter shows them, so reaching
  /// one through the layout tree means it was placed inline — which Ruflet does
  /// not do — and it renders nothing.
  static func overlays(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "AlertDialog", "CupertinoAlertDialog", "BottomSheet", "CupertinoBottomSheet",
      "SnackBar", "Banner":
      return AnyView(EmptyView())
    case "PopupMenuButton":
      return AnyView(PopupMenuControlView(node: node))
    case "MenuBar":
      return AnyView(MenuBarControlView(node: node))
    case "SubmenuButton":
      return AnyView(SubmenuButtonControlView(node: node))
    case "MenuItemButton":
      return AnyView(MenuItemButtonControlView(node: node))
    case "PopupMenuItem":
      // PopupMenuItem is converted into a native entry by PopupMenuButton or
      // ContextMenu. Rendering it independently would fabricate a different
      // button control and duplicate parent-owned state.
      return AnyView(EmptyView())
    case "ContextMenu", "CupertinoContextMenu":
      return AnyView(ContextMenuControlView(node: node))
    case "SnackBarAction", "CupertinoContextMenuAction", "CupertinoActionSheetAction",
      "CupertinoDialogAction":
      return AnyView(DialogActionControlView(node: node))
    default:
      return nil
    }
  }
}
