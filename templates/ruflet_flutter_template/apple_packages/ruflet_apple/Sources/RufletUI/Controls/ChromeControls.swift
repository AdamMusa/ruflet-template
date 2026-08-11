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
    let metrics = ChromeDefaults.appBar(node)
    Group {
      if FletThemeDefaults.appBarCentersTitle(node) {
        centeredBar
      } else {
        leadingBar
      }
    }
    .padding(.horizontal, metrics.horizontalPadding)
    .frame(height: metrics.toolbarHeight)
    .background(metrics.forceMaterialTransparency
      ? Color.clear : MaterialPalette.color(node.string("bgcolor"), default: barSurface))
    .foregroundColor(MaterialPalette.color(node.string("color")))
    .shadow(
      color: MaterialPalette.color(node.string("shadow_color"), default: .black.opacity(0.2)),
      radius: metrics.elevation > 0 ? metrics.elevation : 0,
      y: metrics.elevation > 0 ? metrics.elevation / 2 : 0)
    .modifier(ChromeClipModifier(behavior: metrics.clipBehavior))
    .modifier(AppBarHeaderSemanticsModifier(excluded: metrics.excludeHeaderSemantics))
  }

  private var leadingBar: some View {
    HStack(spacing: metrics.titleSpacing) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .frame(
            minWidth: 44, idealWidth: node.double("leading_width").map { CGFloat($0) },
            minHeight: 44)
      }

      title
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

      actions.padding(metrics.actionsPadding)
    }
    .opacity(metrics.toolbarOpacity)
    .rufletTextStyle(RufletTextStyle(node: node, styleKey: "toolbar_text_style"))
  }

  private var centeredBar: some View {
    ZStack {
      title.lineLimit(1)
      HStack(spacing: metrics.titleSpacing) {
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
            .frame(
              minWidth: 44, idealWidth: node.double("leading_width").map { CGFloat($0) },
              minHeight: 44)
        }
        Spacer(minLength: 0)
        actions.padding(metrics.actionsPadding)
      }
    }
    .opacity(metrics.toolbarOpacity)
    .rufletTextStyle(RufletTextStyle(node: node, styleKey: "toolbar_text_style"))
  }

  private var actions: some View {
    HStack(spacing: 4) {
      ForEach(node.controlIDs(forKey: "actions"), id: \.self) { actionID in
        ControlView(id: actionID, axis: .none)
          .frame(minWidth: 44, minHeight: 44)
      }
    }
  }

  private var metrics: ChromeDefaults.AppBarValues {
    ChromeDefaults.appBar(node)
  }

  @ViewBuilder
  private var title: some View {
    if let titleID = node.controlID(forKey: "title") {
      ControlView(id: titleID, axis: .none)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "title_text_style"))
    } else if let text = node.string("title") {
      Text(text)
        .font(.headline)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "title_text_style"))
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
    let metrics = ChromeDefaults.bottomAppBar(node)
    HStack {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .horizontal)
      }
    }
    .padding(
      metrics.padding
    )
    .frame(height: metrics.height)
    .frame(maxWidth: .infinity)
    .background(MaterialPalette.color(node.string("bgcolor") ?? "surfacecontainer"))
    .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius))
    .shadow(
      color: MaterialPalette.color(node.string("shadow_color"), default: .black.opacity(0.2)),
      radius: metrics.elevation > 0 ? metrics.elevation : 0,
      y: metrics.elevation > 0 ? metrics.elevation / 2 : 0)
    .modifier(ChromeClipModifier(behavior: metrics.clipBehavior))
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
    let metrics = ChromeDefaults.navigationBar(node)
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
            if metrics.showsLabel(selected: index == selected),
              let label = destination.string("label") {
              Text(label).font(.caption2)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(metrics.labelPadding)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(
          index == selected
            ? MaterialPalette.color("primary", default: .primary)
            : MaterialPalette.color("onsurfacevariant", default: .secondary))
      }
    }
    .frame(height: metrics.height)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(alignment: .top) {
      if let border = ControlProps.border(node.props["border"]) {
        Rectangle().fill(border.color).frame(height: border.width)
      }
    }
    .shadow(
      color: MaterialPalette.color(node.string("shadow_color"), default: .black.opacity(0.2)),
      radius: metrics.elevation > 0 ? metrics.elevation : 0,
      y: metrics.elevation > 0 ? -metrics.elevation / 2 : 0)
    .animation(metrics.animation, value: selected)
  }
}

/// `NavigationRail` — the same destinations laid out vertically.
struct NavigationRailControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let metrics = ChromeDefaults.navigationRail(node)
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
            in: RoundedRectangle(cornerRadius: 12)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(
          index == selected
            ? MaterialPalette.color("onsecondarycontainer", default: .primary)
            : MaterialPalette.color("onsurfacevariant", default: .secondary))
      }

      if metrics.groupAlignment > -1 { Spacer(minLength: 0) }

      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .padding(.vertical, 12)
    .frame(width: extended ? CGFloat(node.double("min_extended_width") ?? 256) : metrics.minWidth)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .shadow(
      color: .black.opacity(0.2), radius: metrics.elevation > 0 ? metrics.elevation : 0,
      x: metrics.elevation > 0 ? metrics.elevation / 2 : 0)
  }
}

/// Flet constructor values and theme fallbacks for the Material chrome
/// controls. Keeping these pure lets tests exercise omission and explicit DSL
/// values without snapshot-specific constants in the views.
enum ChromeDefaults {
  struct AppBarValues {
    let toolbarHeight: CGFloat
    let toolbarOpacity: Double
    let horizontalPadding: CGFloat
    let titleSpacing: CGFloat
    let actionsPadding: EdgeInsets
    let elevation: CGFloat
    let clipBehavior: String
    let excludeHeaderSemantics: Bool
    let forceMaterialTransparency: Bool
  }

  struct BottomAppBarValues {
    let padding: EdgeInsets
    let height: CGFloat?
    let elevation: CGFloat
    let cornerRadius: CGFloat
    let clipBehavior: String
    let notchMargin: CGFloat
  }

  enum NavigationLabelBehavior {
    case alwaysShow, alwaysHide, onlyShowSelected
  }

  struct NavigationBarValues {
    let height: CGFloat?
    let elevation: CGFloat
    let animation: Animation
    let labelPadding: EdgeInsets
    let labelBehavior: NavigationLabelBehavior

    func showsLabel(selected: Bool) -> Bool {
      switch labelBehavior {
      case .alwaysShow: return true
      case .alwaysHide: return false
      case .onlyShowSelected: return selected
      }
    }
  }

  struct NavigationRailValues {
    let elevation: CGFloat
    let groupAlignment: Double
    let minWidth: CGFloat
    let useIndicator: Bool
  }

  static func appBar(_ node: ControlNode) -> AppBarValues {
    AppBarValues(
      toolbarHeight: FletThemeDefaults.appBarHeight(node),
      toolbarOpacity: node.double("toolbar_opacity") ?? 1,
      horizontalPadding: 8,
      titleSpacing: CGFloat(node.double("title_spacing") ?? 4),
      actionsPadding: ControlProps.edgeInsets(node.props["actions_padding"]) ?? EdgeInsets(),
      elevation: CGFloat(node.double("elevation") ?? 0),
      clipBehavior: node.string("clip_behavior") ?? "none",
      excludeHeaderSemantics: node.bool("exclude_header_semantics") ?? false,
      forceMaterialTransparency: node.bool("force_material_transparency") ?? false)
  }

  static func bottomAppBar(_ node: ControlNode) -> BottomAppBarValues {
    let radius = ControlProps.cornerRadius(node.props["border_radius"]) ?? 0
    return BottomAppBarValues(
      padding: ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets(),
      height: node.double("height").map { CGFloat($0) },
      elevation: CGFloat(node.double("elevation") ?? 0),
      cornerRadius: radius,
      clipBehavior: node.string("clip_behavior") ?? (radius > 0 ? "antiAlias" : "none"),
      notchMargin: CGFloat(node.double("notch_margin") ?? 4))
  }

  static func navigationBar(_ node: ControlNode) -> NavigationBarValues {
    let raw = node.string("label_behavior")?.lowercased().replacingOccurrences(of: "_", with: "")
    let behavior: NavigationLabelBehavior = switch raw {
    case "alwayshide": .alwaysHide
    case "onlyshowselected": .onlyShowSelected
    default: .alwaysShow
    }
    let duration = max(node.double("animation_duration") ?? 500, 0) / 1000
    return NavigationBarValues(
      height: node.double("height").map { CGFloat($0) },
      elevation: CGFloat(node.double("elevation") ?? 0),
      animation: .easeInOut(duration: duration),
      labelPadding: ControlProps.edgeInsets(node.props["label_padding"])
        ?? EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
      labelBehavior: behavior)
  }

  static func navigationRail(_ node: ControlNode) -> NavigationRailValues {
    NavigationRailValues(
      elevation: CGFloat(node.double("elevation") ?? 0),
      groupAlignment: node.double("group_alignment") ?? -1,
      minWidth: CGFloat(node.double("min_width") ?? 72),
      useIndicator: node.bool("use_indicator") ?? true)
  }
}

private struct ChromeClipModifier: ViewModifier {
  let behavior: String
  func body(content: Content) -> some View {
    behavior.lowercased() == "none" ? AnyView(content) : AnyView(content.clipped())
  }
}

private struct AppBarHeaderSemanticsModifier: ViewModifier {
  let excluded: Bool
  func body(content: Content) -> some View {
    if excluded { content } else { content.accessibilityAddTraits(.isHeader) }
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
        in: Capsule()
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundColor(
      index == selected
        ? MaterialPalette.color("onsecondarycontainer", default: .primary)
        : MaterialPalette.color("onsurface", default: .primary)
    )
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
