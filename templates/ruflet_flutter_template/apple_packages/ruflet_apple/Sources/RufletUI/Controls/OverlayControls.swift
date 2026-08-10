import RufletEngine
import RufletProtocol
import SwiftUI

/// Presents everything hanging off `page._dialogs`.
///
/// Ruflet keeps dialogs, sheets and snack bars in one container control and
/// drives them by flipping each one's `open` prop (`Page#show_dialog` /
/// `#close_dialog`). The renderer therefore watches that container rather than
/// the layout tree, and reports `dismiss` when the user closes something
/// themselves — which is what lets `Page#dispatch_event` drop it from its own
/// list.
struct DialogPresenter: ViewModifier {
  let host: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .center) { modalLayer }
      .overlay(alignment: .top) { bannerLayer }
      .overlay(alignment: .bottom) { snackBarLayer }
      .animation(.easeOut(duration: 0.2), value: store.revision)
  }

  private var openDialogs: [ControlNode] {
    guard let dialogsID = store.page?.controlID(forKey: "_dialogs"),
      let container = store.node(dialogsID)
    else { return [] }
    return container.childIDs
      .compactMap { store.node($0) }
      .filter { $0.bool("open") == true }
  }

  /// Alerts and bottom sheets take over the screen; the last one
  /// opened is on top, matching a navigator stack.
  @ViewBuilder
  private var modalLayer: some View {
    let modals = openDialogs.filter { $0.type != "SnackBar" && $0.type != "Banner" }
    if let dialog = modals.last {
      ZStack {
        Color.black.opacity(0.3)
          .ignoresSafeArea()
          .onTapGesture { dismiss(dialog, barrierDismiss: true) }
        modalBody(dialog)
      }
      .transition(.opacity)
    }
  }

  @ViewBuilder
  private func modalBody(_ dialog: ControlNode) -> some View {
    switch dialog.type {
    case "BottomSheet", "CupertinoBottomSheet":
      VStack {
        Spacer(minLength: 0)
        BottomSheetControlView(node: dialog)
      }
      .transition(.move(edge: .bottom))
    case "DatePicker":
      DateTimePickerControlView(node: dialog, kind: .date)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    case "DateRangePicker":
      DateTimePickerControlView(node: dialog, kind: .dateRange)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    case "TimePicker":
      DateTimePickerControlView(node: dialog, kind: .time)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    default:
      AlertDialogControlView(node: dialog)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
  }

  /// Material banners are persistent page chrome, not dialogs: they sit below
  /// the app bar and never dim or disable the page behind them.
  @ViewBuilder
  private var bannerLayer: some View {
    if let banner = openDialogs.last(where: { $0.type == "Banner" }) {
      BannerControlView(node: banner)
        .padding(.top, appBarHeight)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private var appBarHeight: CGFloat {
    guard let appBarID = host.controlID(forKey: "appbar"), let appBar = store.node(appBarID) else {
      return 0
    }
    return FletThemeDefaults.appBarHeight(appBar)
  }

  @ViewBuilder
  private var snackBarLayer: some View {
    if let snackBar = openDialogs.last(where: { $0.type == "SnackBar" }) {
      SnackBarControlView(node: snackBar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  /// Tapping the scrim closes a dialog unless Ruby set `modal`.
  private func dismiss(_ dialog: ControlNode, barrierDismiss: Bool) {
    guard !(barrierDismiss && dialog.bool("modal") == true) else { return }
    events.setLocal(dialog.id, "open", .bool(false))
    events.update(dialog.id, ["open": .bool(false)])
    events.fire(dialog, "dismiss")
  }
}

/// `AlertDialog` — title, content and actions.
struct AlertDialogControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  @ViewBuilder
  var body: some View {
    #if os(iOS)
      appleAlert
    #else
      materialDialog
    #endif
  }

  private var materialDialog: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let titleID = node.controlID(forKey: "title") {
        ControlView(id: titleID, axis: .none).font(.headline)
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      }
      if !node.controlIDs(forKey: "actions").isEmpty {
        HStack(spacing: 8) {
          Spacer(minLength: 0)
          ControlList(ids: node.controlIDs(forKey: "actions"), axis: .horizontal)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: 420)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(MaterialPalette.color(node.string("bgcolor"), default: dialogSurface)))
    .shadow(radius: 20)
    .padding(24)
  }

  private var appleAlert: some View {
    VStack(spacing: 0) {
      VStack(spacing: 8) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none)
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .vertical)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)

      let actionIDs = node.controlIDs(forKey: "actions")
      if !actionIDs.isEmpty {
        Divider()
        if actionIDs.count <= 2 {
          HStack(spacing: 0) {
            ForEach(Array(actionIDs.enumerated()), id: \.element) { index, actionID in
              if index > 0 { Divider() }
              appleAction(actionID)
            }
          }
          .frame(height: 44)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(actionIDs.enumerated()), id: \.element) { index, actionID in
              if index > 0 { Divider() }
              appleAction(actionID).frame(height: 44)
            }
          }
        }
      }
    }
    .frame(width: 270)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
  }

  @ViewBuilder
  private func appleAction(_ actionID: Int) -> some View {
    if let action = store.node(actionID) {
      Button(actionLabel(action)) {
        events.fire(action, "click")
      }
      .buttonStyle(.plain)
      .font(.body.weight(action.bool("is_default_action") == true ? .semibold : .regular))
      .foregroundColor(
        action.bool("is_destructive_action") == true
          ? MaterialPalette.color("error", default: .red)
          : MaterialPalette.color("primary", default: .primary))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .disabled(action.bool("disabled") ?? false)
    }
  }

  private func actionLabel(_ action: ControlNode) -> String {
    if let text = action.string("content") ?? action.string("text") ?? action.string("label") {
      return text
    }
    if let contentID = action.controlID(forKey: "content"), let content = store.node(contentID) {
      return content.string("value") ?? content.string("text") ?? "OK"
    }
    return "OK"
  }

  private var dialogSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.windowBackgroundColor)
    #else
      return .white
    #endif
  }
}

/// `BottomSheet` — content anchored to the bottom edge.
struct BottomSheetControlView: View {
  let node: ControlNode

  var body: some View {
    VStack(spacing: 0) {
      if node.bool("show_drag_handle") == true {
        Capsule()
          .fill(Color.secondary.opacity(0.4))
          .frame(width: 36, height: 5)
          .padding(.vertical, 8)
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 24)
    .background(
      MaterialPalette.color(node.string("bgcolor"), default: sheetSurface),
      in: RoundedRectangle(cornerRadius: 16))
    .ignoresSafeArea(edges: .bottom)
  }

  private var sheetSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.windowBackgroundColor)
    #else
      return .white
    #endif
  }
}

/// `SnackBar` — a transient message with an optional action.
struct SnackBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    HStack(spacing: 12) {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
      Spacer(minLength: 0)
      if let actionID = node.controlID(forKey: "action") {
        ControlView(id: actionID, axis: .none)
      } else if let action = node.string("action") {
        Button(action) { events.fire(node, "action") }
      }
    }
    .padding(14)
    .background(
      MaterialPalette.color(node.string("bgcolor"), default: Color.black.opacity(0.85)),
      in: RoundedRectangle(cornerRadius: 8))
    .foregroundColor(.white)
    .padding(16)
    .task(id: node.id) { await autoDismiss() }
  }

  /// Flet's SnackBar hides itself after `duration` milliseconds; the Ruby side
  /// only learns about it through the `dismiss` event, so send one.
  private func autoDismiss() async {
    let milliseconds = node.double("duration") ?? 4000
    guard milliseconds > 0 else { return }
    try? await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
    guard !Task.isCancelled else { return }
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, ["open": .bool(false)])
    events.fire(node, "dismiss")
  }
}

/// `Banner` — a persistent message strip below the app bar.
struct BannerControlView: View {
  let node: ControlNode

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      }
      VStack(alignment: .leading, spacing: 8) {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        }
        HStack(spacing: 8) {
          Spacer(minLength: 0)
          ControlList(ids: node.controlIDs(forKey: "actions"), axis: .horizontal)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(MaterialPalette.color(node.string("bgcolor"), default: .yellow.opacity(0.2)))
  }
}

/// Presents `page.drawer` and `page.end_drawer`.
///
/// The Ruby side opens these by invoking `show_drawer` on the page rather than
/// by patching a prop, so the engine's page service writes an `_open` flag onto
/// the drawer control and this watches for it.
struct DrawerPresenter: ViewModifier {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .leading) { drawer(key: "drawer", edge: .leading) }
      .overlay(alignment: .trailing) { drawer(key: "end_drawer", edge: .trailing) }
      .animation(.easeOut(duration: 0.25), value: store.revision)
  }

  @ViewBuilder
  private func drawer(key: String, edge: Edge) -> some View {
    if let drawerID = node.controlID(forKey: key),
      let drawer = store.node(drawerID),
      drawer.bool("_open") == true
    {
      ZStack(alignment: edge == .leading ? .leading : .trailing) {
        Color.black.opacity(0.3)
          .ignoresSafeArea()
          .onTapGesture { close(drawer) }
        ControlView(id: drawerID, axis: .vertical)
          .frame(width: 300)
          .transition(.move(edge: edge))
      }
    }
  }

  private func close(_ drawer: ControlNode) {
    events.setLocal(drawer.id, "_open", .bool(false))
    events.fire(drawer, "dismiss")
  }
}

/// `PopupMenuButton` — an anchor that opens a menu of `PopupMenuItem`s.
struct PopupMenuControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Menu {
      ForEach(node.childIDs, id: \.self) { itemID in
        if let item = store.node(itemID) {
          menuItem(item)
        }
      }
    } label: {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        RufletIcon(
          value: node.props["icon"], size: 20,
          color: MaterialPalette.color(node.string("icon_color")))
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
    }
    .menuStyle(.borderlessButton)
  }

  @ViewBuilder
  private func menuItem(_ item: ControlNode) -> some View {
    if item.bool("_divider") == true {
      Divider()
    } else {
      Button {
        events.fire(item, "click")
      } label: {
        HStack {
          if item.props["icon"] != nil {
            RufletIcon(value: item.props["icon"], size: 16, color: nil)
          }
          if let contentID = item.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          } else {
            Text(item.string("text") ?? "")
          }
        }
      }
      .disabled(item.bool("disabled") ?? false)
    }
  }
}

/// `MenuBar` — a row of `SubmenuButton`s.
struct MenuBarControlView: View {
  let node: ControlNode

  var body: some View {
    HStack(spacing: 4) {
      ControlList(ids: node.childIDs, axis: .horizontal)
    }
    .padding(.horizontal, 8)
    .background(MaterialPalette.color(node.string("bgcolor")))
  }
}

/// `SubmenuButton` — a labelled menu that can nest further submenus.
struct SubmenuButtonControlView: View {
  let node: ControlNode

  var body: some View {
    Menu {
      ControlList(ids: node.controlIDs(forKey: "controls") + node.childIDs, axis: .vertical)
    } label: {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        Text(node.string("text") ?? "")
      }
    }
  }
}

/// `MenuItemButton` — one row of a menu.
struct MenuItemButtonControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button {
      events.fire(node, "click")
    } label: {
      HStack(spacing: 8) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
        }
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        }
        if let trailingID = node.controlID(forKey: "trailing") {
          ControlView(id: trailingID, axis: .none)
        }
      }
    }
    .disabled(node.bool("disabled") ?? false)
  }
}

/// `ContextMenu` — a right-click / long-press menu around its content.
struct ContextMenuControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .contextMenu {
      ControlList(ids: node.controlIDs(forKey: "menu_items") + node.childIDs, axis: .vertical)
    }
  }
}
