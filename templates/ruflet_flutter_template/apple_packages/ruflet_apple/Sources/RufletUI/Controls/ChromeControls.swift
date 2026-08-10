import RufletEngine
import RufletProtocol
import SwiftUI

/// `AppBar` — the screen's top bar.
///
/// Drawn rather than delegated to a `NavigationView`, because Flet's AppBar is
/// a control the Ruby side patches (title, actions, colours) independently of
/// any navigation stack, and a navigation bar would not accept those patches.
struct AppBarControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      if FletThemeDefaults.appBarCentersTitle(node) {
        centeredBar
      } else {
        leadingBar
      }
    }
    .padding(.horizontal, 8)
    .frame(height: toolbarHeight)
    .background(MaterialPalette.color(node.string("bgcolor"), default: barSurface))
    .foregroundColor(MaterialPalette.color(node.string("color")))
    .overlay(alignment: .bottom) {
      if (node.double("elevation") ?? 0) > 0 { Divider() }
    }
  }

  private var leadingBar: some View {
    HStack(spacing: 4) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .frame(
            minWidth: 44, idealWidth: node.double("leading_width").map { CGFloat($0) },
            minHeight: 44)
      }

      title
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

      actions
    }
  }

  private var centeredBar: some View {
    ZStack {
      title.lineLimit(1)
      HStack(spacing: 4) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
            .frame(
              minWidth: 44, idealWidth: node.double("leading_width").map { CGFloat($0) },
              minHeight: 44)
        }
        Spacer(minLength: 0)
        actions
      }
    }
  }

  private var actions: some View {
    HStack(spacing: 4) {
      ForEach(node.controlIDs(forKey: "actions"), id: \.self) { actionID in
        ControlView(id: actionID, axis: .none)
          .frame(minWidth: 44, minHeight: 44)
      }
    }
  }

  private var toolbarHeight: CGFloat {
    FletThemeDefaults.appBarHeight(node)
  }

  @ViewBuilder
  private var title: some View {
    if let titleID = node.controlID(forKey: "title") {
      ControlView(id: titleID, axis: .none)
    } else if let text = node.string("title") {
      Text(text).font(.headline)
    }
  }

  private var barSurface: Color {
    MaterialPalette.color(for: node, property: "bgcolor", default: .clear)
  }
}

/// `BottomAppBar` — the same idea anchored to the bottom.
struct BottomAppBarControlView: View {
  let node: ControlNode

  var body: some View {
    HStack {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .horizontal)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(
      top: 8, leading: 12, bottom: 8, trailing: 12))
    .frame(maxWidth: .infinity)
    .background(MaterialPalette.color(node.string("bgcolor") ?? "surfacecontainer"))
    .overlay(alignment: .top) { Divider() }
  }
}

/// `NavigationBar` — the bottom tab bar.
///
/// Reports `change` with the new index, which `Page#apply_event_value_to_control`
/// writes back onto `selected_index`, so Ruby and the renderer stay in step.
struct NavigationBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let destinations = node.controlIDs(forKey: "destinations").compactMap { store.node($0) }
    let selected = node.int("selected_index") ?? 0

    HStack(spacing: 0) {
      ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
        Button {
          events.commit(node, key: "selected_index", value: .int(Int64(index)))
        } label: {
          VStack(spacing: 4) {
            RufletIcon(
              value: index == selected
                ? (destination.props["selected_icon"] ?? destination.props["icon"])
                : destination.props["icon"],
              size: 22,
              color: nil)
            if let label = destination.string("label") {
              Text(label).font(.caption2)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(
          index == selected
            ? MaterialPalette.color("primary", default: .primary)
            : MaterialPalette.color("onsurfacevariant", default: .secondary))
      }
    }
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(alignment: .top) { Divider() }
  }
}

/// `NavigationRail` — the same destinations laid out vertically.
struct NavigationRailControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let destinations = node.controlIDs(forKey: "destinations").compactMap { store.node($0) }
    let selected = node.int("selected_index") ?? 0
    let extended = node.bool("extended") ?? false

    VStack(spacing: 4) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none).padding(.bottom, 8)
      }

      ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
        Button {
          events.commit(node, key: "selected_index", value: .int(Int64(index)))
        } label: {
          HStack(spacing: 8) {
            RufletIcon(
              value: index == selected
                ? (destination.props["selected_icon"] ?? destination.props["icon"])
                : destination.props["icon"],
              size: 22, color: nil)
            if extended, let label = destination.string("label") {
              Text(label)
              Spacer(minLength: 0)
            }
          }
          .padding(.horizontal, extended ? 16 : 12)
          .padding(.vertical, 10)
          .background(
            index == selected
              ? MaterialPalette.color("secondarycontainer", default: .clear) : .clear,
            in: RoundedRectangle(cornerRadius: 12))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(
          index == selected
            ? MaterialPalette.color("onsecondarycontainer", default: .primary)
            : MaterialPalette.color("onsurfacevariant", default: .secondary))
      }

      Spacer(minLength: 0)

      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .padding(.vertical, 12)
    .frame(width: extended ? CGFloat(node.double("min_extended_width") ?? 200) : 72)
    .background(MaterialPalette.color(node.string("bgcolor")))
  }
}

/// `NavigationDrawer` — the slide-in side panel.
///
/// Presented by the view that owns it (see `DrawerPresenter`); rendering one
/// inline would put it in the layout, which is not where a drawer belongs.
struct NavigationDrawerControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let selected = node.int("selected_index")

    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(node.childIDs.enumerated()), id: \.element) { index, childID in
          if let child = store.node(childID), child.type == "NavigationDrawerDestination" {
            destinationRow(child, index: index, selected: selected)
          } else {
            ControlView(id: childID, axis: .vertical)
          }
        }
      }
      .padding(.vertical, 16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(MaterialPalette.color(node.string("bgcolor"), default: drawerSurface))
  }

  @ViewBuilder
  private func destinationRow(_ destination: ControlNode, index: Int, selected: Int?) -> some View {
    Button {
      events.commit(node, key: "selected_index", value: .int(Int64(index)))
    } label: {
      HStack(spacing: 12) {
        RufletIcon(value: destination.props["icon"], size: 22, color: nil)
        if let labelID = destination.controlID(forKey: "label") {
          ControlView(id: labelID, axis: .none)
        } else {
          Text(destination.string("label") ?? "")
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        index == selected
          ? MaterialPalette.color("secondarycontainer", default: .clear) : .clear,
        in: Capsule())
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundColor(
      index == selected
        ? MaterialPalette.color("onsecondarycontainer", default: .primary)
        : MaterialPalette.color("onsurface", default: .primary))
    .padding(.horizontal, 8)
  }

  private var drawerSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.windowBackgroundColor)
    #else
      return .white
    #endif
  }
}
