import RufletEngine
import RufletProtocol
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Native Apple primitives used to realize Flet chrome controls.
///
/// Constructor and theme defaults are still resolved from the pinned Flet /
/// Flutter contract. This adapter is only the platform color executor; it must
/// not replace a Flet default token with an unrelated Apple default.
enum AppleChromeAppearance {
  static var barSurface: Color {
    #if canImport(UIKit)
    Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
    Color(nsColor: .windowBackgroundColor)
    #else
    .clear
    #endif
  }

  static var groupedSurface: Color {
    #if canImport(UIKit)
    Color(uiColor: .secondarySystemBackground)
    #elseif canImport(AppKit)
    Color(nsColor: .controlBackgroundColor)
    #else
    .clear
    #endif
  }

  static var separator: Color {
    #if canImport(UIKit)
    Color(uiColor: .separator)
    #elseif canImport(AppKit)
    Color(nsColor: .separatorColor)
    #else
    .secondary.opacity(0.25)
    #endif
  }

  static func color(_ raw: String?, fallback: Color) -> Color {
    guard let raw, !raw.isEmpty else { return fallback }
    return MaterialPalette.color(raw, default: fallback)
  }

  static func itemColor(selected: Bool, disabled: Bool) -> Color {
    if disabled { return .secondary.opacity(0.38) }
    return selected ? .accentColor : .secondary
  }
}

/// `AppBar` — the screen's top bar.
///
/// Drawn rather than delegated to a `NavigationView`, because Flet's AppBar is
/// a control the Ruby side patches (title, actions, colours) independently of
/// any navigation stack, and a navigation bar would not accept those patches.
struct AppBarControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletNavigationContext) private var navigation
  @Environment(\.rufletScaffoldHost) private var scaffold

  var body: some View {
    let metrics = ChromeDefaults.appBar(node)
    let elevation = currentElevation(metrics)
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
      ? Color.clear : MaterialPalette.color(node.string("bgcolor") ?? "surface"))
    .foregroundColor(MaterialPalette.color(node.string("color") ?? "onsurface"))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
      radius: elevation > 0 ? elevation : 0,
      y: elevation > 0 ? elevation / 2 : 0)
    .modifier(ChromeClipModifier(behavior: metrics.clipBehavior))
    .modifier(AppBarHeaderSemanticsModifier(excluded: metrics.excludeHeaderSemantics))
    .modifier(ChromeShapeClipModifier(value: node.props["shape"]))
    .font(.system(size: 14))
  }

  /// Flutter supplies a back affordance when the route can pop and nothing
  /// else fills the leading slot; `automatically_imply_leading` turns that off.
  private var impliesLeading: Bool {
    node.bool("automatically_imply_leading") != false
  }

  private func currentElevation(_ metrics: ChromeDefaults.AppBarValues) -> CGFloat {
    scaffold?.scrolledUnder == true ? metrics.scrolledUnderElevation : metrics.elevation
  }

  private var leadingBar: some View {
    HStack(spacing: metrics.titleSpacing) {
      if node.controlID(forKey: "leading") == nil, impliesLeading, navigation.canPop {
        impliedLeadingButton
      }
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .frame(width: metrics.leadingWidth, height: metrics.toolbarHeight)
      }

      title
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, hasLeading ? 0 : metrics.titleSpacing)

      actions.padding(metrics.actionsPadding)
    }
    .opacity(metrics.toolbarOpacity)
    .rufletTextStyle(RufletTextStyle(node: node, styleKey: "toolbar_text_style"))
  }

  private var centeredBar: some View {
    ZStack {
      title.lineLimit(1)
      HStack(spacing: metrics.titleSpacing) {
        if node.controlID(forKey: "leading") == nil, impliesLeading, navigation.canPop {
          impliedLeadingButton
        }
        if let leadingID = node.controlID(forKey: "leading") {
          ControlView(id: leadingID, axis: .none)
            .frame(width: metrics.leadingWidth, height: metrics.toolbarHeight)
        }
        Spacer(minLength: 0)
        actions.padding(metrics.actionsPadding)
      }
    }
    .opacity(metrics.toolbarOpacity)
    .rufletTextStyle(RufletTextStyle(node: node, styleKey: "toolbar_text_style"))
  }

  private var actions: some View {
    HStack(spacing: 0) {
      ForEach(node.controlIDs(forKey: "actions"), id: \.self) { actionID in
        ControlView(id: actionID, axis: .none)
      }
    }
  }

  private var impliedLeadingButton: some View {
    Button(action: navigation.requestPop) {
      Image(systemName: "chevron.backward")
        .font(.system(size: 20, weight: .semibold))
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }
    .frame(width: metrics.leadingWidth, height: metrics.toolbarHeight)
    .buttonStyle(.plain)
    .accessibilityLabel("Back")
  }

  private var metrics: ChromeDefaults.AppBarValues {
    ChromeDefaults.appBar(node)
  }

  private var hasLeading: Bool {
    node.controlID(forKey: "leading") != nil || (impliesLeading && navigation.canPop)
  }

  @ViewBuilder
  private var title: some View {
    if let titleID = node.controlID(forKey: "title") {
      ControlView(id: titleID, axis: .none)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "title_text_style"))
    } else if let text = node.string("title") {
      Text(text)
        .font(.system(size: 22))
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "title_text_style"))
    }
  }

  private var barSurface: Color {
    MaterialPalette.color("surface", default: .clear)
  }
}

/// `BottomAppBar` — the same idea anchored to the bottom.
struct BottomAppBarControlView: View {
  let node: ControlNode
  @Environment(\.rufletScaffoldHost) private var scaffold

  var body: some View {
    let metrics = ChromeDefaults.bottomAppBar(node)
    let shape = BottomAppBarHostShape(
      cornerRadii: metrics.cornerRadii,
      guestFrame: scaffold?.fabFrameInBottomBar,
      notch: ChromeDefaults.bottomAppBarNotch(node))
    HStack {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .padding(
      metrics.padding
    )
    .frame(height: metrics.height)
    .frame(maxWidth: .infinity)
    .background(
      shape.fill(
        MaterialPalette.color(node.string("bgcolor") ?? "surfacecontainer", default: .clear),
        style: FillStyle(eoFill: true)))
    .mask(shape.fill(style: FillStyle(eoFill: true)))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
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

  /// Flet's omitted indicator values resolve through Flutter's NavigationBar
  /// theme; the native SwiftUI composition receives those resolved values.
  @ViewBuilder
  private func destinationIndicator(active: Bool) -> some View {
    if active {
      ChromeOutlinedShape(value: node.props["indicator_shape"], defaultKind: .stadium)
        .fill(MaterialPalette.color(
          node.string("indicator_color") ?? "secondarycontainer", default: .clear))
        .frame(width: 64, height: 32)
    }
  }

  var body: some View {
    nativeBar
  }

  private var nativeBar: some View {
    let metrics = ChromeDefaults.navigationBar(node)
    let destinations = node.controlIDs(forKey: "destinations").compactMap { store.node($0) }
    let selected = node.int("selected_index") ?? 0

    return Group {
      if let message = ChromeDefaults.navigationBarValidation(
        destinationCount: destinations.count, selectedIndex: selected)
      {
        ChromeNavigationValidationView(message: message)
      } else {
        navigationBar(destinations: destinations, selected: selected, metrics: metrics)
      }
    }
    .frame(height: metrics.height)
  }

  private func navigationBar(
    destinations: [ControlNode], selected: Int, metrics: ChromeDefaults.NavigationBarValues
  ) -> some View {
    HStack(spacing: 0) {
      ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
        let isSelected = index == selected
        let isDisabled = (node.bool("disabled") ?? false) || (destination.bool("disabled") ?? false)
        Button {
          events.commit(node, key: "selected_index", value: .int(Int64(index)))
        } label: {
          VStack(spacing: 4) {
            destinationIcon(destination, selected: isSelected)
              .foregroundColor(MaterialPalette.color(
                ChromeDefaults.navigationBarItemPalette(
                  selected: isSelected, disabled: isDisabled).iconToken))
              .frame(minWidth: 64, minHeight: 32)
              .background(destinationIndicator(active: isSelected))
            if metrics.showsLabel(selected: isSelected) {
              Text(destination.string("label") ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(MaterialPalette.color(
                  ChromeDefaults.navigationBarItemPalette(
                    selected: isSelected, disabled: isDisabled).labelToken))
                .padding(metrics.labelPadding)
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .modifier(NavigationOverlayTint(node: node, selected: isSelected, disabled: isDisabled))
        .modifier(NavigationDestinationHelpModifier(
          text: isDisabled ? nil : destination.string("tooltip") ?? destination.string("label")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .frame(height: metrics.height)
    .background(MaterialPalette.color(node.string("bgcolor") ?? "surfacecontainer"))
    .overlay(alignment: .top) {
      if let border = ControlProps.border(node.props["border"]) {
        Rectangle().fill(border.color).frame(height: border.width)
      }
    }
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
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
        size: 24,
        color: nil)
    }
  }
}

/// Press/hover tint supplied explicitly by Ruflet's stateful overlay colour.
private struct NavigationOverlayTint: ViewModifier {
  let node: ControlNode
  let selected: Bool
  let disabled: Bool
  @State private var pressed = false
  @State private var hovered = false

  func body(content: Content) -> some View {
    content
      .background(color ?? .clear)
      .onHover { hovered = $0 }
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in if !disabled { pressed = true } }
          .onEnded { _ in pressed = false })
  }

  private var color: Color? {
    guard !disabled, pressed || hovered else { return nil }
    var extra: Set<RufletWidgetState> = []
    if pressed { extra.insert(.pressed) }
    if hovered { extra.insert(.hovered) }
    return MaterialPalette.color(
      stateful: node.props["overlay_color"],
      in: node.widgetStates(selected: selected, extra: extra))
  }
}

private struct NavigationDestinationHelpModifier: ViewModifier {
  let text: String?
  func body(content: Content) -> some View {
    if let text, !text.isEmpty { content.help(text) } else { content }
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

  var body: some View {
    let metrics = ChromeDefaults.navigationRail(node)
    let destinations = node.controlIDs(forKey: "destinations").compactMap { store.node($0) }
    let selected = node.int("selected_index")
    let extended = node.bool("extended") ?? false

    Group {
      if let message = ChromeDefaults.navigationRailValidation(
        destinationCount: destinations.count, selectedIndex: selected,
        minWidth: metrics.minWidth, minExtendedWidth: metrics.minExtendedWidth,
        groupAlignment: metrics.groupAlignment)
      {
        ChromeNavigationValidationView(message: message)
      } else {
        navigationRail(
          destinations: destinations, selected: selected, extended: extended, metrics: metrics)
      }
    }
  }

  private func navigationRail(
    destinations: [ControlNode], selected: Int?, extended: Bool,
    metrics: ChromeDefaults.NavigationRailValues
  ) -> some View {
    VStack(spacing: 0) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
          .padding(.top, 8)
          .padding(.bottom, 8)
      }

      ChromeRailGroupAlignment(alignment: metrics.groupAlignment) {
        VStack(spacing: 0) {
          ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
            let isSelected = index == selected
            let isDisabled = (node.bool("disabled") ?? false) || (destination.bool("disabled") ?? false)
            Button {
              events.commit(node, key: "selected_index", value: .int(Int64(index)))
            } label: {
              Group {
                if extended {
                  HStack(spacing: 0) {
                    railIconPart(destination, selected: isSelected, disabled: isDisabled)
                      .frame(width: metrics.minWidth)
                    railDestinationLabel(destination, selected: isSelected, disabled: isDisabled)
                    Spacer(minLength: 0)
                    Color.clear.frame(width: 8)
                  }
                } else if metrics.showsLabel(extended: false, selected: isSelected) {
                  VStack(spacing: 4) {
                    railIconPart(destination, selected: isSelected, disabled: isDisabled)
                    railDestinationLabel(destination, selected: isSelected, disabled: isDisabled)
                    Color.clear.frame(height: 12)
                  }
                  .padding(.horizontal, 8)
                } else {
                  VStack(spacing: 0) {
                    Color.clear.frame(height: 6)
                    railIconPart(destination, selected: isSelected, disabled: isDisabled)
                    Color.clear.frame(height: 6)
                  }
                  .frame(width: metrics.minWidth)
                }
              }
              .padding(ControlProps.edgeInsets(destination.props["padding"]) ?? EdgeInsets())
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
          }
          if let trailingID = node.controlID(forKey: "trailing") {
            ControlView(id: trailingID, axis: .none)
          }
        }
      }
      .frame(maxHeight: .infinity)
    }
    .frame(width: extended ? metrics.minExtendedWidth : metrics.minWidth)
    .frame(height: node.double("height").map { CGFloat($0) })
    .background(MaterialPalette.color(node.string("bgcolor") ?? "surface"))
    .shadow(
      color: .black.opacity(0.2), radius: metrics.elevation > 0 ? metrics.elevation : 0,
      x: metrics.elevation > 0 ? metrics.elevation / 2 : 0)
  }

  private func railIconPart(
    _ destination: ControlNode, selected: Bool, disabled: Bool
  ) -> some View {
    let palette = ChromeDefaults.navigationRailItemPalette(selected: selected, disabled: disabled)
    let shapeValue = destination.props["indicator_shape"] ?? node.props["indicator_shape"]
    return railDestinationIcon(destination, selected: selected)
      .foregroundColor(MaterialPalette.color(palette.iconToken))
      .frame(width: 56, height: 32)
      .background {
        if ChromeDefaults.navigationRail(node).useIndicator && selected {
          ChromeOutlinedShape(value: shapeValue, defaultKind: .stadium)
            .fill(railIndicator(destination, active: true))
        }
      }
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
        size: 24,
        color: nil)
    }
  }

  @ViewBuilder
  private func railDestinationLabel(
    _ destination: ControlNode, selected: Bool, disabled: Bool
  ) -> some View {
    let color = MaterialPalette.color(
      ChromeDefaults.navigationRailItemPalette(selected: selected, disabled: disabled).labelToken)
    if let labelID = destination.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(color)
        .rufletTextStyle(railLabelStyle(selected: selected))
    } else {
      Text(destination.string("label") ?? "")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(color)
        .rufletTextStyle(railLabelStyle(selected: selected))
    }
  }
}

/// Flutter's `Align(alignment: Alignment(0, groupAlignment))` for the rail's
/// destination/trailing group. A custom `Layout` preserves intermediate
/// values such as -0.5; SwiftUI's top/center/bottom alignments cannot.
private struct ChromeRailGroupAlignment<Content: View>: View {
  let alignment: Double
  @ViewBuilder let content: Content

  init(alignment: Double, @ViewBuilder content: () -> Content) {
    self.alignment = alignment
    self.content = content()
  }

  @ViewBuilder
  var body: some View {
    #if os(iOS)
      if #available(iOS 16, *) {
        ChromeRailGroupAlignmentLayout(alignment: alignment) { content }
      } else {
        content.frame(
          maxHeight: .infinity,
          alignment: alignment <= -0.5 ? .top : (alignment >= 0.5 ? .bottom : .center))
      }
    #else
      ChromeRailGroupAlignmentLayout(alignment: alignment) { content }
    #endif
  }
}

@available(iOS 16.0, *)
private struct ChromeRailGroupAlignmentLayout: Layout {
  let alignment: Double

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let childSize = child.sizeThatFits(.init(width: proposal.width, height: nil))
    return CGSize(
      width: proposal.width ?? childSize.width,
      height: proposal.height?.isFinite == true ? proposal.height! : childSize.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    guard let child = subviews.first else { return }
    let childSize = child.sizeThatFits(.init(width: bounds.width, height: nil))
    let factor = CGFloat((min(max(alignment, -1), 1) + 1) / 2)
    let y = bounds.minY + max(bounds.height - childSize.height, 0) * factor
    child.place(
      at: CGPoint(x: bounds.midX, y: y), anchor: .top,
      proposal: .init(width: bounds.width, height: childSize.height))
  }
}

/// Pinned Flet/Flutter semantic defaults consumed by native Apple chrome.
enum ChromeDefaults {
  struct AppBarValues {
    let toolbarHeight: CGFloat
    let toolbarOpacity: Double
    let horizontalPadding: CGFloat
    let titleSpacing: CGFloat
    let leadingWidth: CGFloat
    let actionsPadding: EdgeInsets
    let elevation: CGFloat
    let scrolledUnderElevation: CGFloat
    let clipBehavior: String
    let excludeHeaderSemantics: Bool
    let forceMaterialTransparency: Bool
  }

  struct BottomAppBarValues {
    let padding: EdgeInsets
    let height: CGFloat
    let elevation: CGFloat
    let cornerRadii: RufletCornerRadii
    let clipBehavior: String
    let notchMargin: CGFloat
  }

  enum BottomAppBarNotchKind: Equatable { case none, circular, automatic }

  struct BottomAppBarNotchValues: Equatable {
    let kind: BottomAppBarNotchKind
    let inverted: Bool
    let margin: CGFloat
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

  struct NavigationItemPalette: Equatable {
    let iconToken: String
    let labelToken: String
  }

  struct NavigationRailValues {
    let elevation: CGFloat
    let groupAlignment: Double
    let minWidth: CGFloat
    let minExtendedWidth: CGFloat
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

  struct NavigationDrawerValues {
    let elevation: CGFloat
    let tilePadding: EdgeInsets
    let tileHeight: CGFloat
    let indicatorWidth: CGFloat
    let indicatorHeight: CGFloat
  }

  static func navigationBarValidation(
    destinationCount: Int, selectedIndex: Int
  ) -> String? {
    guard destinationCount >= 2 else {
      return "NavigationBar.destinations requires at least two destinations"
    }
    guard (0..<destinationCount).contains(selectedIndex) else {
      return "NavigationBar.selected_index must reference a destination"
    }
    return nil
  }

  static func navigationRailValidation(
    destinationCount: Int, selectedIndex: Int?, minWidth: CGFloat,
    minExtendedWidth: CGFloat, groupAlignment: Double
  ) -> String? {
    if let selectedIndex, !(0..<destinationCount).contains(selectedIndex) {
      return "NavigationRail.selected_index must be nil or reference a destination"
    }
    guard minWidth > 0 else { return "NavigationRail.min_width must be greater than zero" }
    guard minExtendedWidth >= minWidth else {
      return "NavigationRail.min_extended_width must be at least min_width"
    }
    guard (-1...1).contains(groupAlignment) else {
      return "NavigationRail.group_alignment must be between -1 and 1"
    }
    return nil
  }

  static func validatedDrawerSelection(_ selectedIndex: Int?, destinationCount: Int) -> Int? {
    guard let selectedIndex, (0..<destinationCount).contains(selectedIndex) else { return nil }
    return selectedIndex
  }

  static func appBar(_ node: ControlNode) -> AppBarValues {
    AppBarValues(
      toolbarHeight: RufletThemeDefaults.appBarHeight(node),
      toolbarOpacity: node.double("toolbar_opacity") ?? 1,
      horizontalPadding: 0,
      titleSpacing: CGFloat(node.double("title_spacing") ?? 16),
      leadingWidth: CGFloat(node.double("leading_width") ?? 56),
      actionsPadding: ControlProps.edgeInsets(node.props["actions_padding"]) ?? EdgeInsets(),
      elevation: CGFloat(node.double("elevation") ?? 0),
      scrolledUnderElevation: CGFloat(node.double("elevation_on_scroll") ?? 3),
      clipBehavior: node.string("clip_behavior") ?? "none",
      excludeHeaderSemantics: node.bool("exclude_header_semantics") ?? false,
      forceMaterialTransparency: node.bool("force_material_transparency") ?? false)
  }

  static func bottomAppBar(_ node: ControlNode) -> BottomAppBarValues {
    let radii = ControlProps.cornerRadii(node.props["border_radius"])
      ?? RufletCornerRadii(uniform: 0)
    return BottomAppBarValues(
      padding: ControlProps.edgeInsets(node.props["padding"])
        ?? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
      height: CGFloat(node.double("height") ?? 80),
      elevation: CGFloat(node.double("elevation") ?? 3),
      cornerRadii: radii,
      clipBehavior: radii.maximum > 0
        ? (node.string("clip_behavior") == "none" ? "antiAlias" : node.string("clip_behavior") ?? "antiAlias")
        : node.string("clip_behavior") ?? "none",
      notchMargin: CGFloat(node.double("notch_margin") ?? 4))
  }

  static func bottomAppBarNotch(_ node: ControlNode) -> BottomAppBarNotchValues {
    let shape = node.map("shape")
    let kind: BottomAppBarNotchKind = switch shape?["_type"]?.stringValue?.lowercased() {
    case "circular": .circular
    case "auto": .automatic
    default: .automatic
    }
    return BottomAppBarNotchValues(
      kind: kind,
      inverted: shape?["inverted"]?.boolValue ?? false,
      margin: CGFloat(node.double("notch_margin") ?? 4))
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
      height: CGFloat(node.double("height") ?? 80),
      elevation: CGFloat(node.double("elevation") ?? 3),
      animation: .easeInOut(duration: duration),
      labelPadding: ControlProps.edgeInsets(node.props["label_padding"])
        ?? EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0),
      labelBehavior: behavior)
  }

  static func navigationBarItemPalette(
    selected: Bool, disabled: Bool
  ) -> NavigationItemPalette {
    if disabled {
      return NavigationItemPalette(
        iconToken: "onsurfacevariant,0.38", labelToken: "onsurfacevariant,0.38")
    }
    return NavigationItemPalette(
      iconToken: selected ? "onsecondarycontainer" : "onsurfacevariant",
      labelToken: selected ? "onsurface" : "onsurfacevariant")
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
      minWidth: CGFloat(node.double("min_width") ?? 80),
      minExtendedWidth: CGFloat(node.double("min_extended_width") ?? 256),
      useIndicator: node.bool("use_indicator") ?? true,
      labelBehavior: labelBehavior)
  }

  static func navigationRailItemPalette(
    selected: Bool, disabled: Bool
  ) -> NavigationItemPalette {
    NavigationItemPalette(
      iconToken: disabled
        ? "onsurface,0.38"
        : selected ? "onsecondarycontainer" : "onsurfacevariant",
      labelToken: disabled ? "onsurface,0.38" : "onsurface")
  }

  static func navigationDrawer(_ node: ControlNode) -> NavigationDrawerValues {
    NavigationDrawerValues(
      elevation: CGFloat(node.double("elevation") ?? 1),
      tilePadding: ControlProps.edgeInsets(node.props["tile_padding"])
        ?? EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
      tileHeight: 56,
      indicatorWidth: 336,
      indicatorHeight: 56)
  }

  static func navigationDrawerItemPalette(
    selected: Bool, disabled: Bool
  ) -> NavigationItemPalette {
    let token = disabled
      ? "onsurfacevariant,0.38"
      : selected ? "onsecondarycontainer" : "onsurfacevariant"
    return NavigationItemPalette(iconToken: token, labelToken: token)
  }

  static func outlinedShape(
    _ value: RufletValue?, defaultKind: ChromeOutlinedShapeKind
  ) -> ChromeOutlinedShapeValues {
    let map = value?.mapValue
    let kind: ChromeOutlinedShapeKind = switch map?["_type"]?.stringValue?.lowercased() {
    case "stadium": .stadium
    case "circle": .circle
    case "beveledrectangle": .beveledRectangle
    case "continuousrectangle": .continuousRectangle
    case "roundedrectangle": .roundedRectangle
    default: defaultKind
    }
    let side = map?["side"]?.mapValue
    return ChromeOutlinedShapeValues(
      kind: kind,
      radii: ControlProps.cornerRadii(map?["radius"]) ?? RufletCornerRadii(uniform: 0),
      sideWidth: CGFloat(side?["width"]?.doubleValue ?? 0),
      sideColorToken: side?["color"]?.stringValue)
  }
}

/// A BottomAppBar path with the FAB guest rectangle subtracted using even-odd
/// fill. Flutter receives the same two rectangles through ScaffoldGeometry;
/// using the measured native FAB keeps extended and mini FABs correct too.
private struct BottomAppBarHostShape: Shape {
  let cornerRadii: RufletCornerRadii
  let guestFrame: CGRect?
  let notch: ChromeDefaults.BottomAppBarNotchValues

  func path(in rect: CGRect) -> Path {
    var path = RufletRoundedRectangle(radii: cornerRadii).path(in: rect)
    guard notch.kind != .none, let guestFrame else { return path }
    let cutout = guestFrame.insetBy(dx: -notch.margin, dy: -notch.margin)
    guard cutout.maxY > rect.minY, cutout.minY < rect.maxY else { return path }

    let local = cutout.offsetBy(dx: -rect.minX, dy: -rect.minY)
    if notch.kind == .automatic {
      path.addRoundedRect(
        in: local,
        cornerSize: CGSize(width: min(local.width, local.height) / 2,
                           height: min(local.width, local.height) / 2))
    } else {
      let diameter = max(local.width, local.height)
      let circle = CGRect(
        x: local.midX - diameter / 2,
        y: notch.inverted ? rect.height - diameter / 2 : -diameter / 2,
        width: diameter,
        height: diameter)
      path.addEllipse(in: circle)
    }
    return path
  }
}

enum ChromeOutlinedShapeKind: Equatable {
  case roundedRectangle, stadium, circle, beveledRectangle, continuousRectangle
}

struct ChromeOutlinedShapeValues: Equatable {
  let kind: ChromeOutlinedShapeKind
  let radii: RufletCornerRadii
  let sideWidth: CGFloat
  let sideColorToken: String?
}

/// SwiftUI path equivalents for every `OutlinedBorder` Flet 0.80.5 accepts.
/// The wire shape remains the source of truth; defaults are supplied only by
/// the corresponding Flutter Material component.
private struct ChromeOutlinedShape: Shape {
  let values: ChromeOutlinedShapeValues

  init(value: RufletValue?, defaultKind: ChromeOutlinedShapeKind) {
    values = ChromeDefaults.outlinedShape(value, defaultKind: defaultKind)
  }

  func path(in rect: CGRect) -> Path {
    switch values.kind {
    case .stadium:
      return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
    case .circle:
      return Path(ellipseIn: rect)
    case .roundedRectangle:
      return RufletRoundedRectangle(radii: values.radii).path(in: rect)
    case .continuousRectangle:
      // Flutter's continuous border uses smoother cubic corners. The same
      // declared corner radii and bounds are preserved here.
      return RufletRoundedRectangle(radii: values.radii).path(in: rect)
    case .beveledRectangle:
      let radius = min(values.radii.maximum, min(rect.width, rect.height) / 2)
      var path = Path()
      path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
      path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
      path.closeSubpath()
      return path
    }
  }
}

private struct ChromeShapeClipModifier: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    guard value?.mapValue != nil else { return AnyView(content) }
    let shape = ChromeOutlinedShape(value: value, defaultKind: .roundedRectangle)
    return AnyView(
      content
        .clipShape(shape)
        .overlay {
          if shape.values.sideWidth > 0 {
            shape.stroke(
              MaterialPalette.color(shape.values.sideColorToken, default: .black),
              lineWidth: shape.values.sideWidth)
          }
        })
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
    let controls = drawerControls
    let selected = ChromeDefaults.validatedDrawerSelection(
      node.int("selected_index"),
      destinationCount: controls.reduce(into: 0) { count, childID in
        if store.node(childID)?.type == "NavigationDrawerDestination" { count += 1 }
      })
    let metrics = ChromeDefaults.navigationDrawer(node)

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
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
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(MaterialPalette.color(node.string("bgcolor") ?? "surfacecontainerlow"))
    .shadow(
      color: AppleChromeAppearance.color(node.string("shadow_color"), fallback: .clear),
      radius: metrics.elevation > 0 ? metrics.elevation : 0,
      x: metrics.elevation > 0 ? metrics.elevation / 2 : 0)
  }

  @ViewBuilder
  private func destinationRow(_ destination: ControlNode, index: Int, selected: Int?) -> some View {
    let active = index == selected
    let disabled = destination.bool("disabled") ?? false
    let metrics = ChromeDefaults.navigationDrawer(node)
    Button {
      events.commit(node, key: "selected_index", value: .int(Int64(index)))
    } label: {
      HStack(spacing: 12) {
        Color.clear.frame(width: 16)
        let palette = ChromeDefaults.navigationDrawerItemPalette(
          selected: active, disabled: disabled)
        drawerDestinationIcon(destination, selected: active)
          .foregroundColor(MaterialPalette.color(palette.iconToken))
        Text(destination.string("label") ?? "")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(MaterialPalette.color(palette.labelToken))
        Spacer(minLength: 0)
      }
      .frame(height: metrics.tileHeight)
      .frame(maxWidth: metrics.indicatorWidth)
      .background(MaterialPalette.color(destination.string("bgcolor")))
      .background {
        if active {
          if node.props["indicator_shape"] != nil {
            ChromeOutlinedShape(value: node.props["indicator_shape"], defaultKind: .roundedRectangle)
              .fill(MaterialPalette.color(
                node.string("indicator_color") ?? "secondarycontainer", default: .clear))
              .frame(maxWidth: .infinity, minHeight: metrics.indicatorHeight)
          } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
              .fill(MaterialPalette.color(
                node.string("indicator_color") ?? "secondarycontainer", default: .clear))
              .frame(maxWidth: .infinity, minHeight: metrics.indicatorHeight)
          }
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .padding(metrics.tilePadding)
    .accessibilityAddTraits(active ? .isSelected : [])
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
        size: 24,
        color: nil)
    }
  }
}

private struct ChromeNavigationValidationView: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.caption)
      .foregroundColor(.red)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .accessibilityLabel(message)
  }
}
