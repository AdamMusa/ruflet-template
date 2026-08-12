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
      if RufletThemeDefaults.appBarCentersTitle(node) {
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
    // A secondary bar sits under the primary one and carries no heading
    // weight of its own.
    .font(node.bool("secondary") == true ? .subheadline : nil)
  }

  /// Flutter supplies a back affordance when the route can pop and nothing
  /// else fills the leading slot; `automatically_imply_leading` turns that off.
  private var impliesLeading: Bool {
    node.bool("automatically_imply_leading") != false
  }

  /// `elevation_on_scroll` is the raised height Material 3 uses once content
  /// has scrolled under the bar. Without a scroll position to read, the bar
  /// takes it as its elevation when it is the larger of the two.
  private var scrolledElevation: CGFloat {
    CGFloat(max(node.double("elevation_on_scroll") ?? 0, 0))
  }

  private var leadingBar: some View {
    HStack(spacing: metrics.titleSpacing) {
      if node.controlID(forKey: "leading") == nil, impliesLeading, scrolledElevation >= 0 {
        EmptyView()
      }
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

  /// `indicator_color` and `indicator_shape` describe the pill behind the
  /// selected destination; an absent shape is Material's stadium.
  @ViewBuilder
  private func destinationIndicator(active: Bool) -> some View {
    if active {
      RoundedRectangle(
        cornerRadius: ControlProps.cornerRadius(node.map("indicator_shape")?["radius"]) ?? 16)
        .fill(MaterialPalette.color(
          node.string("indicator_color"),
          default: MaterialPalette.color("secondarycontainer", default: .clear)))
    }
  }

  var body: some View {
    if node.bool("adaptive") == true {
      CupertinoNavigationBarControlView(node: node)
    } else {
      materialBar
    }
  }

  private var materialBar: some View {
    let metrics = ChromeDefaults.navigationBar(node)
    let destinations = node.controlIDs(forKey: "destinations").compactMap { store.node($0) }
    let selected = node.int("selected_index") ?? 0

    return HStack(spacing: 0) {
      ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
        Button {
          events.commit(node, key: "selected_index", value: .int(Int64(index)))
        } label: {
          VStack(spacing: 4) {
            destinationIcon(destination, selected: index == selected)
              .frame(minWidth: 64, minHeight: 32)
              .background(destinationIndicator(active: index == selected))
            if metrics.showsLabel(selected: index == selected),
              let label = destination.string("label") {
              Text(label).font(.caption2).padding(metrics.labelPadding)
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled((node.bool("disabled") ?? false) || (destination.bool("disabled") ?? false))
        .modifier(
          NavigationOverlayTint(color: MaterialPalette.color(node.string("overlay_color"))))
        .foregroundColor(
          index == selected
            ? MaterialPalette.color("primary", default: .primary)
            : MaterialPalette.color("onsurfacevariant", default: .secondary))
      }
    }
    .frame(height: metrics.height)
    .background(MaterialPalette.color(node.string("bgcolor")))
    // Material 3 tints an elevated surface towards the primary colour.
    .background(MaterialPalette.color(node.string("surface_tint_color")))
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

  @ViewBuilder
  private func destinationIcon(_ destination: ControlNode, selected: Bool) -> some View {
    let selectedID = destination.controlID(forKey: "selected_icon")
    let iconID = destination.controlID(forKey: "icon")
    if selected, let selectedID {
      ControlView(id: selectedID, axis: .none)
    } else if let iconID {
      ControlView(id: iconID, axis: .none)
    } else {
      RufletIcon(
        value: selected
          ? (destination.props["selected_icon"] ?? destination.props["icon"])
          : destination.props["icon"],
        size: 22,
        color: nil)
    }
  }
}

/// The pill Material 3 draws behind the selected destination.
private struct NavigationOverlayTint: ViewModifier {
  let color: Color?
  @State private var pressed = false

  func body(content: Content) -> some View {
    guard let color else { return AnyView(content) }
    return AnyView(
      content
        .background(pressed ? color : .clear)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }))
  }
}

/// `NavigationRail` — the same destinations laid out vertically.
struct NavigationRailControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  private func railLabelStyle(selected: Bool) -> RufletTextStyle {
    guard selected else {
      return RufletTextStyle(node: node, styleKey: "unselected_label_text_style")
    }
    return RufletTextStyle(node: node, styleKey: "selected_label_text_style")
  }

  private func railIndicator(_ destination: ControlNode, active: Bool) -> Color {
    guard active else { return .clear }
    return MaterialPalette.color(
      destination.string("indicator_color") ?? node.string("indicator_color"),
      default: MaterialPalette.color("secondarycontainer", default: .clear))
  }

  private func railIndicatorRadius(_ destination: ControlNode) -> CGFloat {
    ControlProps.cornerRadius(destination.map("indicator_shape")?["radius"])
      ?? ControlProps.cornerRadius(node.map("indicator_shape")?["radius"])
      ?? 12
  }

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
            railDestinationIcon(destination, selected: index == selected)
            if metrics.showsLabel(extended: extended, selected: index == selected) {
              railDestinationLabel(destination, selected: index == selected)
              Spacer(minLength: 0)
            }
          }
          .padding(
            ControlProps.edgeInsets(destination.props["padding"])
              ?? EdgeInsets(
                top: 10, leading: extended ? 16 : 12,
                bottom: 10, trailing: extended ? 16 : 12))
          .background(
            railIndicator(destination, active: metrics.useIndicator && index == selected),
            in: RoundedRectangle(cornerRadius: railIndicatorRadius(destination))
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled((node.bool("disabled") ?? false) || (destination.bool("disabled") ?? false))
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

  @ViewBuilder
  private func railDestinationIcon(_ destination: ControlNode, selected: Bool) -> some View {
    let selectedID = destination.controlID(forKey: "selected_icon")
    let iconID = destination.controlID(forKey: "icon")
    if selected, let selectedID {
      ControlView(id: selectedID, axis: .none)
    } else if let iconID {
      ControlView(id: iconID, axis: .none)
    } else {
      RufletIcon(
        value: selected
          ? (destination.props["selected_icon"] ?? destination.props["icon"])
          : destination.props["icon"],
        size: 22,
        color: nil)
    }
  }

  @ViewBuilder
  private func railDestinationLabel(_ destination: ControlNode, selected: Bool) -> some View {
    if let labelID = destination.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
        .rufletTextStyle(railLabelStyle(selected: selected))
    } else {
      Text(destination.string("label") ?? "")
        .rufletTextStyle(railLabelStyle(selected: selected))
    }
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
    let height: CGFloat
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
    let labelBehavior: NavigationRailLabelBehavior

    func showsLabel(extended: Bool, selected: Bool) -> Bool {
      // Flutter sets labelType to none for an extended rail because the
      // extended constructor itself displays every destination label.
      if extended { return true }
      switch labelBehavior {
      case .all: return true
      case .selected: return selected
      case .none: return false
      }
    }
  }

  enum NavigationRailLabelBehavior { case all, selected, none }

  static func appBar(_ node: ControlNode) -> AppBarValues {
    AppBarValues(
      toolbarHeight: RufletThemeDefaults.appBarHeight(node),
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
      // Flutter Material 3's NavigationBar constructor resolves an omitted
      // height through _NavigationBarDefaultsM3 to 80 logical pixels.
      height: CGFloat(node.double("height") ?? 80),
      elevation: CGFloat(node.double("elevation") ?? 0),
      animation: .easeInOut(duration: duration),
      labelPadding: ControlProps.edgeInsets(node.props["label_padding"])
        ?? EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
      labelBehavior: behavior)
  }

  static func navigationRail(_ node: ControlNode) -> NavigationRailValues {
    let labelBehavior: NavigationRailLabelBehavior = switch node.string("label_type")?.lowercased() {
    case "none": .none
    case "selected": .selected
    default: .all
    }
    return NavigationRailValues(
      elevation: CGFloat(node.double("elevation") ?? 0),
      groupAlignment: node.double("group_alignment") ?? -1,
      minWidth: CGFloat(node.double("min_width") ?? 72),
      useIndicator: node.bool("use_indicator") ?? true,
      labelBehavior: labelBehavior)
  }
}

struct ChromeClipModifier: ViewModifier {
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
    let selected = node.int("selected_index") ?? 0
    let controls = drawerControls

    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(controls.enumerated()), id: \.element) { childIndex, childID in
          if let child = store.node(childID), child.type == "NavigationDrawerDestination" {
            destinationRow(
              child,
              index: destinationIndex(for: childIndex, in: controls),
              selected: selected)
          } else {
            ControlView(id: childID, axis: .vertical)
          }
        }
      }
      .padding(.vertical, 16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(MaterialPalette.color(node.string("bgcolor"), default: drawerSurface))
    .shadow(
      color: MaterialPalette.color(node.string("shadow_color"), default: .black.opacity(0.2)),
      radius: CGFloat(max(node.double("elevation") ?? 0, 0)),
      x: CGFloat(max(node.double("elevation") ?? 0, 0) / 2))
  }

  @ViewBuilder
  private func destinationRow(_ destination: ControlNode, index: Int, selected: Int?) -> some View {
    Button {
      events.commit(node, key: "selected_index", value: .int(Int64(index)))
    } label: {
      HStack(spacing: 12) {
        drawerDestinationIcon(destination, selected: index == selected)
        if let labelID = destination.controlID(forKey: "label") {
          ControlView(id: labelID, axis: .none)
        } else {
          Text(destination.string("label") ?? "")
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(MaterialPalette.color(destination.string("bgcolor")))
      .background(
        index == selected
          ? MaterialPalette.color(
            node.string("indicator_color"),
            default: MaterialPalette.color("secondarycontainer", default: .clear)) : .clear,
        in: RoundedRectangle(cornerRadius: drawerIndicatorRadius)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(destination.bool("disabled") ?? false)
    .foregroundColor(
      index == selected
        ? MaterialPalette.color("onsecondarycontainer", default: .primary)
        : MaterialPalette.color("onsurface", default: .primary)
    )
    .padding(drawerTilePadding)
  }

  private var drawerControls: [Int] {
    let explicit = node.controlIDs(forKey: "controls")
    return explicit.isEmpty ? node.childIDs : explicit
  }

  /// Flutter's NavigationDrawer selected index counts destinations, not
  /// headings/dividers interleaved in the controls list.
  private func destinationIndex(for childIndex: Int, in controls: [Int]) -> Int {
    controls.prefix(childIndex).reduce(into: 0) { count, childID in
      if store.node(childID)?.type == "NavigationDrawerDestination" { count += 1 }
    }
  }

  private var drawerTilePadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["tile_padding"])
      ?? EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
  }

  private var drawerIndicatorRadius: CGFloat {
    ControlProps.cornerRadius(node.map("indicator_shape")?["radius"]) ?? 28
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

  @ViewBuilder
  private func drawerDestinationIcon(_ destination: ControlNode, selected: Bool) -> some View {
    let selectedID = destination.controlID(forKey: "selected_icon")
    let iconID = destination.controlID(forKey: "icon")
    if selected, let selectedID {
      ControlView(id: selectedID, axis: .none)
    } else if let iconID {
      ControlView(id: iconID, axis: .none)
    } else {
      RufletIcon(
        value: selected
          ? (destination.props["selected_icon"] ?? destination.props["icon"])
          : destination.props["icon"],
        size: 22,
        color: nil)
    }
  }
}
