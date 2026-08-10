import RufletEngine
import RufletProtocol
import SwiftUI

/// `Page` — the session root, wire id 1.
///
/// Its `views` prop is a navigator stack; Flet renders the top of it, and so
/// does this. `_overlay`, `_dialogs` and `_services` hang off the page too, but
/// they are presented by the active view rather than laid out inline.
struct PageControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    Group {
      if let viewID = node.controlIDs(forKey: "views").last {
        ControlView(id: viewID, axis: .vertical)
      } else {
        Color.clear
      }
    }
    .modifier(PageChrome(node: node))
  }
}

/// Page-level appearance: title, theme mode and the overlay layer.
private struct PageChrome: ViewModifier {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  func body(content: Content) -> some View {
    content
      .modifier(MaterialThemeModifier(theme: node.map("theme"), darkTheme: node.map("dark_theme")))
      .preferredColorScheme(colorScheme)
      .overlay(overlayLayer)
      .modifier(WindowTitle(title: node.string("title")))
      .environment(\.layoutDirection, node.fletBool("rtl") ? .rightToLeft : .leftToRight)
  }

  /// `theme_mode` is `"light"`, `"dark"` or `"system"`; only the first two
  /// override the platform.
  private var colorScheme: ColorScheme? {
    switch node.string("theme_mode")?.lowercased() {
    case "light": return .light
    case "dark": return .dark
    default: return nil
    }
  }

  /// `page.overlay` — controls drawn above the view, outside its layout.
  @ViewBuilder
  private var overlayLayer: some View {
    if let overlayID = node.controlID(forKey: "_overlay"),
      let overlay = store.node(overlayID),
      !overlay.childIDs.isEmpty
    {
      ZStack {
        ControlList(ids: overlay.childIDs, axis: .none)
      }
      .allowsHitTesting(true)
    }
  }
}

/// Resolves the page theme while constructing the parent view, before SwiftUI
/// asks any descendant control for its body.
private struct MaterialThemeModifier: ViewModifier {
  init(theme: [String: RufletValue]?, darkTheme: [String: RufletValue]?) {
    MaterialPalette.configure(theme: theme, darkTheme: darkTheme)
  }

  func body(content: Content) -> some View { content }
}

private struct WindowTitle: ViewModifier {
  let title: String?

  func body(content: Content) -> some View {
    #if os(macOS)
      content.navigationTitle(title ?? "")
    #else
      content
    #endif
  }
}

/// `View` — one screen in the page's navigator stack.
///
/// Carries the screen chrome (`appbar`, `navigation_bar`, `drawer`,
/// `floating_action_button`) alongside its `controls`, which Flet composes into
/// a Scaffold. The equivalent here is a `VStack` between the bars, with the FAB
/// and drawer as overlays.
struct ViewControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    let main = ControlProps.MainAxisAlignment(node.fletString("vertical_alignment"))
    let cross = ControlProps.CrossAxisAlignment(node.fletString("horizontal_alignment"))
    let spacing = CGFloat(node.fletDouble("spacing"))

    VStack(spacing: 0) {
      VStack(alignment: cross.horizontal, spacing: main.usesSpacers ? 0 : spacing) {
        if main == .center || main == .end { Spacer(minLength: 0) }
        ControlList(ids: node.childIDs, axis: .vertical)
        if main == .center || main == .start { Spacer(minLength: 0) }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      .modifier(ScrollableStack(node: node, axis: .vertical))

      if let bottomBarID = node.controlID(forKey: "bottom_appbar") {
        ControlView(id: bottomBarID, axis: .none)
      }
      if let navBarID = node.controlID(forKey: "navigation_bar") {
        ControlView(id: navBarID, axis: .none)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // Flutter's Scaffold owns AppBar placement. In particular, a primary
    // AppBar is inset below the system status area independently of whatever
    // platform view the body contains. Keeping the bar as an ordinary VStack
    // child allowed AVPlayerViewController (and other UIKit controls) to alter
    // the stack's safe-area proposal when a Studio tab switched to Preview.
    // `safeAreaInset` is SwiftUI's scaffold-equivalent contract: the bar stays
    // below the notch and the remaining body is reduced by its exact height.
    .safeAreaInset(edge: .top, spacing: 0) {
      if let appBarID = node.controlID(forKey: "appbar") {
        ControlView(id: appBarID, axis: .none)
      }
    }
    .background {
      MaterialPalette.color(
        node.string("bgcolor") ?? store.page?.string("bgcolor") ?? "surface",
        default: .clear
      )
      .ignoresSafeArea(edges: .bottom)
    }
    .overlay(floatingActionButton, alignment: fabAlignment)
    .modifier(DrawerPresenter(node: node))
    .modifier(DialogPresenter(host: node))
  }

  @ViewBuilder
  private var floatingActionButton: some View {
    if let fabID = node.controlID(forKey: "floating_action_button") {
      ControlView(id: fabID, axis: .none)
        .padding(16)
    }
  }

  /// Flet's `FloatingActionButtonLocation`, reduced to the corner it names.
  private var fabAlignment: Alignment {
    let location = node.string("floating_action_button_location")?.lowercased() ?? ""
    if location.contains("center") { return .bottom }
    if location.contains("start") || location.contains("left") { return .bottomLeading }
    if location.contains("top") { return .topTrailing }
    return .bottomTrailing
  }
}

/// `Container` — the single-child decorator: padding, background, border,
/// corner radius, alignment, and an optional tap target.
struct ContainerControlView: View {
  let node: ControlNode
  let axis: LayoutAxis

  @Environment(\.rufletEvents) private var events

  var body: some View {
    let radius = ControlProps.cornerRadius(node.props["border_radius"]) ?? 0
    let border = ControlProps.border(node.props["border"])
    let alignment = ControlProps.continuousAlignment(node.props["alignment"])

    content
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      // A ResponsiveRow supplies Flutter-tight horizontal constraints. Apply
      // them before painting the Container so its background, border and hit
      // target fill the grid cell instead of stopping at the text's intrinsic
      // width.
      .modifier(
        ContainerAlignmentModifier(
          alignment: alignment,
          requiresTightWidth: axis.requiresTightWidth)
      )
      .background(background(radius: radius))
      .overlay(borderStroke(border: border, radius: radius))
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .contentShape(RoundedRectangle(cornerRadius: radius))
      .modifier(TapReporter(node: node, events: events))
      .allowsHitTesting(!node.fletBool("ignore_interactions"))
  }

  @ViewBuilder
  private var content: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: axis)
    } else if !node.childIDs.isEmpty {
      ControlList(ids: node.childIDs, axis: .vertical)
    } else {
      Color.clear
    }
  }

  @ViewBuilder
  private func background(radius: CGFloat) -> some View {
    let gradient = GradientProps.linear(node.props["gradient"])
    if let gradient {
      RoundedRectangle(cornerRadius: radius).fill(gradient)
    } else if let color = MaterialPalette.color(node.string("bgcolor")) {
      RoundedRectangle(cornerRadius: radius).fill(color)
    }
  }

  @ViewBuilder
  private func borderStroke(border: (color: Color, width: CGFloat)?, radius: CGFloat) -> some View {
    if let border {
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(border.color, lineWidth: border.width)
    }
  }
}

/// Flet passes its continuous Flutter `Alignment(x, y)` straight to `Align`.
/// SwiftUI's frame API only exposes nine discrete alignment guides, so a
/// custom layout performs Flutter's exact free-space calculation instead of
/// rounding values such as `{x: 0.25, y: -0.6}` to center/top.
private struct ContainerAlignmentModifier: ViewModifier {
  let alignment: FletAlignment?
  let requiresTightWidth: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if let alignment {
      if #available(iOS 16.0, macOS 13.0, *) {
        ContinuousAlignmentLayout(alignment: alignment) { content }
      } else {
        LegacyContinuousAlignment(alignment: alignment) { content }
      }
    } else if requiresTightWidth {
      content.frame(maxWidth: .infinity, alignment: .center)
    } else {
      content
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct ContinuousAlignmentLayout: Layout {
  let alignment: FletAlignment

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let childSize = child.sizeThatFits(proposal)
    return CGSize(
      width: finite(proposal.width) ?? childSize.width,
      height: finite(proposal.height) ?? childSize.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    guard let child = subviews.first else { return }
    let childSize = child.sizeThatFits(proposal)
    let origin = FletGeometry.alignedOrigin(
      alignment: alignment, containerSize: bounds.size, childSize: childSize)
    child.place(
      at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
      anchor: .topLeading,
      proposal: ProposedViewSize(width: childSize.width, height: childSize.height))
  }

  private func finite(_ value: CGFloat?) -> CGFloat? {
    guard let value, value.isFinite else { return nil }
    return max(value, 0)
  }
}

/// iOS 15 compatibility. GeometryReader supplies the bounded Align size while
/// the preference measures the child without changing its layout footprint.
private struct LegacyContinuousAlignment<Content: View>: View {
  let alignment: FletAlignment
  @ViewBuilder let content: () -> Content
  @State private var childSize: CGSize = .zero

  var body: some View {
    GeometryReader { proxy in
      let origin = FletGeometry.alignedOrigin(
        alignment: alignment, containerSize: proxy.size, childSize: childSize)
      content()
        .background(
          GeometryReader { childProxy in
            Color.clear.preference(key: AlignedChildSizeKey.self, value: childProxy.size)
          }
        )
        .onPreferenceChange(AlignedChildSizeKey.self) { childSize = $0 }
        .offset(x: origin.x, y: origin.y)
    }
  }
}

private struct AlignedChildSizeKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// `Card` — a raised surface around a single child.
struct CardControlView: View {
  let node: ControlNode

  var body: some View {
    let radius = ControlProps.cornerRadius(node.props["shape"]) ?? 12

    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["margin"]) ?? EdgeInsets())
    .background(
      RoundedRectangle(cornerRadius: radius)
        .fill(MaterialPalette.color(node.string("color"), default: cardSurface))
        .shadow(radius: CGFloat(node.double("elevation") ?? 1)))
  }

  private var cardSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.secondarySystemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.controlBackgroundColor)
    #else
      return .gray.opacity(0.1)
    #endif
  }
}

/// `SafeArea` — insets its content past the notch and home indicator.
struct SafeAreaControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      } else {
        ControlList(ids: node.childIDs, axis: .vertical)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["minimum_padding"]) ?? EdgeInsets())
    // SwiftUI already applies the active safe area. Match Flet's property
    // names so a control can explicitly opt an edge out of that protection.
    .modifier(SafeAreaEdges(node: node))
  }
}

private struct SafeAreaEdges: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    var ignored: Edge.Set = []
    if node.bool("avoid_intrusions_top") == false { ignored.insert(.top) }
    if node.bool("avoid_intrusions_bottom") == false { ignored.insert(.bottom) }
    if node.bool("avoid_intrusions_left") == false { ignored.insert(.leading) }
    if node.bool("avoid_intrusions_right") == false { ignored.insert(.trailing) }
    return content.edgesIgnoringSafeArea(ignored)
  }
}

/// `Divider` / `VerticalDivider`.
struct DividerControlView: View {
  let node: ControlNode
  let isVertical: Bool

  var body: some View {
    let thickness = CGFloat(node.double("thickness") ?? 1)
    let color = MaterialPalette.color(node.string("color"), default: .gray.opacity(0.3))
    let extent = CGFloat(node.double("height") ?? node.double("width") ?? 16)

    Rectangle()
      .fill(color)
      .frame(
        width: isVertical ? thickness : nil,
        height: isVertical ? nil : thickness
      )
      .frame(
        width: isVertical ? extent : nil,
        height: isVertical ? nil : extent
      )
      .padding(.leading, CGFloat(node.double("leading_indent") ?? 0))
      .padding(.trailing, CGFloat(node.double("trailing_indent") ?? 0))
  }
}

/// `Placeholder` — a marked-out box for layout work in progress.
struct PlaceholderControlView: View {
  let node: ControlNode

  var body: some View {
    let color = MaterialPalette.color(node.string("color"), default: .blue)
    ZStack {
      Rectangle().stroke(color, lineWidth: CGFloat(node.double("stroke_width") ?? 2))
      Path { path in
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 1, y: 1))
      }
      .stroke(color, lineWidth: 1)
    }
    .frame(minWidth: 48, minHeight: 48)
  }
}

/// `RotatedBox` — quarter turns, as Flutter counts them.
struct RotatedBoxControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .rotationEffect(.degrees(Double(node.int("quarter_turns") ?? 0) * 90))
  }
}

/// `Pagelet` — a screen-in-a-screen with its own bars.
struct PageletControlView: View {
  let node: ControlNode

  var body: some View {
    VStack(spacing: 0) {
      if let appBarID = node.controlID(forKey: "appbar") {
        ControlView(id: appBarID, axis: .none)
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .vertical)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      if let barID = node.controlID(forKey: "navigation_bar")
        ?? node.controlID(forKey: "bottom_appbar")
      {
        ControlView(id: barID, axis: .none)
      }
    }
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(alignment: .bottomTrailing) {
      if let fabID = node.controlID(forKey: "floating_action_button") {
        ControlView(id: fabID, axis: .none).padding(16)
      }
    }
  }
}

/// `AnimatedSwitcher` — cross-fades whenever its content changes.
struct AnimatedSwitcherControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
          .id(contentID)
          .transition(.opacity)
      }
    }
    .animation(
      .easeInOut(duration: (node.double("duration") ?? 300) / 1000),
      value: node.controlID(forKey: "content"))
  }
}

/// A wrapper with no Apple-side behaviour of its own: render the content.
struct PassthroughControlView: View {
  let node: ControlNode

  var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }
}

/// Flet's `LinearGradient` on a container background.
enum GradientProps {
  static func linear(_ value: RufletValue?) -> LinearGradient? {
    guard let map = value?.mapValue else { return nil }
    let colors = (map["colors"]?.arrayValue ?? [])
      .compactMap { MaterialPalette.color($0.stringValue) }
    guard colors.count >= 2 else { return nil }

    let begin = FletGeometry.unitPoint(
      alignment: ControlProps.continuousAlignment(map["begin"]) ?? .topCenter)
    let end = FletGeometry.unitPoint(
      alignment: ControlProps.continuousAlignment(map["end"]) ?? .bottomCenter)
    return LinearGradient(
      colors: colors,
      startPoint: UnitPoint(x: begin.x, y: begin.y),
      endPoint: UnitPoint(x: end.x, y: end.y))
  }
}
