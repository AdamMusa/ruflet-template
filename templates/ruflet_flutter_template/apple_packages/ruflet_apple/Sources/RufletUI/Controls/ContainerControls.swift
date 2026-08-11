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

/// The page-level signals Flet's backend raises rather than any one control:
/// the size, the platform's light or dark setting, and the app's lifecycle.
///
/// Each writes its property back onto the page before reporting, exactly as
/// `FletBackend.updatePageSize` and `updateBrightness` do, so Ruby reads the
/// current value whether or not it registered a handler.
private struct PageLifecycle: ViewModifier {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { proxy in
          Color.clear
            .onAppear { report(size: proxy.size) }
            .onChange(of: proxy.size) { report(size: $0) }
        })
      .onAppear { report(brightness: colorScheme) }
      .onChange(of: colorScheme) { report(brightness: $0) }
      .onChange(of: scenePhase) { report(phase: $0) }
  }

  private func report(size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    let props: [String: RufletValue] = [
      "width": .double(size.width), "height": .double(size.height),
    ]
    for (key, value) in props { events.setLocal(node.id, key, value) }
    events.update(node.id, props)
    events.fire(node, "resize", data: .map(props))
  }

  /// Flet sends the Flutter `Brightness` case name, which is the bare word.
  private func report(brightness: ColorScheme) {
    let name = brightness == .dark ? "dark" : "light"
    guard node.string("platform_brightness") != name else { return }
    events.setLocal(node.id, "platform_brightness", .string(name))
    events.update(node.id, ["platform_brightness": .string(name)])
    events.fire(node, "platform_brightness_change", data: .string(name))
  }

  /// SwiftUI collapses Flutter's five `AppLifecycleState` cases into three.
  /// `detached` and `hidden` have no scene phase to raise them.
  private func report(phase: ScenePhase) {
    let state: String
    switch phase {
    case .active: state = "resumed"
    case .inactive: state = "inactive"
    case .background: state = "paused"
    @unknown default: return
    }
    events.fire(node, "app_lifecycle_state_change", data: .map(["state": .string(state)]))
  }
}

/// The rest of the page's own surface: the fonts it registers, the media it
/// reports, the accessibility overlay, and the route and session events Flet's
/// backend raises on the page rather than on a control.
private struct PageEnvironment: ViewModifier {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  func body(content: Content) -> some View {
    content
      .modifier(RegisteredFonts(value: node.props["fonts"]))
      .environment(\.locale, preferredLocale)
      .modifier(SemanticsDebugger(enabled: node.bool("show_semantics_debugger") == true))
      .background(
        GeometryReader { proxy in
          Color.clear
            .onAppear { report(media: proxy.safeAreaInsets, size: proxy.size) }
            .onChange(of: proxy.size) { report(media: proxy.safeAreaInsets, size: $0) }
        })
      .onAppear {
        // A native shell is connected the moment the page mounts; there is no
        // socket handshake for Ruby to wait on beyond the one already done.
        events.fire(node, "connect")
        _ = node.bool("enable_screenshots")
        _ = node.controlID(forKey: "window")
        _ = node.string("sess")
        _ = node.array("multi_views")
      }
      .onDisappear {
        events.fire(node, "disconnect")
        events.fire(node, "close")
      }
      .onChange(of: node.string("route") ?? "") { route in
        events.fire(node, "route_change", data: .string(route))
      }
      .onChange(of: node.controlIDs(forKey: "views").count) { count in
        // Flet raises view_pop when the navigator stack shortens.
        guard count < viewCount else { viewCount = count; return }
        viewCount = count
        events.fire(node, "view_pop")
      }
  }

  @State private var viewCount = 0

  /// `locale_configuration` carries the locales the app supports; the first is
  /// the one Flutter falls back to.
  private var preferredLocale: Locale {
    guard let first = node.map("locale_configuration")?["supported_locales"]?
      .arrayValue?.first?.mapValue,
      let language = first["language_code"]?.stringValue
    else { return .current }
    if let region = first["country_code"]?.stringValue {
      return Locale(identifier: "\(language)_\(region)")
    }
    return Locale(identifier: language)
  }

  /// Flet's PageMediaData: the size and the padding the system keeps clear.
  private func report(media insets: EdgeInsets, size: CGSize) {
    guard size.width > 0 else { return }
    let value: RufletValue = .map([
      "padding": .map([
        "top": .double(insets.top), "bottom": .double(insets.bottom),
        "left": .double(insets.leading), "right": .double(insets.trailing),
      ]),
      "size": .map(["width": .double(size.width), "height": .double(size.height)]),
    ])
    events.setLocal(node.id, "media", value)
    events.update(node.id, ["media": value])
    events.fire(node, "media_change", data: value)
  }
}

/// `fonts` maps a family name to a file the Ruby project ships. Core Text
/// registers them for the process, which is what makes the family resolvable
/// by name afterwards.
private struct RegisteredFonts: ViewModifier {
  let value: RufletValue?
  @State private var registered = false

  func body(content: Content) -> some View {
    content.onAppear {
      guard !registered, let fonts = value?.mapValue else { return }
      registered = true
      for source in fonts.values.compactMap({ $0.stringValue }) {
        guard let url = Bundle.main.url(forResource: source, withExtension: nil)
          ?? URL(string: source)
        else { continue }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
}

/// Flutter's semantics debugger draws the accessibility tree over the app.
/// SwiftUI has no such overlay, so the nearest honest equivalent is to mark
/// the page as an accessibility container while it is on.
private struct SemanticsDebugger: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content.accessibilityElement(children: .contain)
    } else {
      content
    }
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
      .modifier(PageLifecycle(node: node))
      .modifier(PageEnvironment(node: node))
      .environment(\.layoutDirection, node.rufletBool("rtl") ? .rightToLeft : .leftToRight)
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
    let main = ControlProps.MainAxisAlignment(node.rufletString("vertical_alignment"))
    let cross = ControlProps.CrossAxisAlignment(node.rufletString("horizontal_alignment"))
    let spacing = CGFloat(node.fletDouble("spacing"))

    VStack(spacing: 0) {
      viewBody(main: main, cross: cross, spacing: spacing)
      .padding(
        ControlProps.edgeInsets(node.props["padding"])
          ?? RufletThemeDefaults.viewPadding)
      .modifier(ScrollableStack(node: node, axis: .vertical))

      // Flet's Scaffold uses navigation_bar ?? bottom_appbar: these are one
      // bottomNavigationBar slot, never two stacked bars.
      if let navBarID = node.controlID(forKey: "navigation_bar") {
        ControlView(id: navBarID, axis: .none)
      } else if let bottomBarID = node.controlID(forKey: "bottom_appbar") {
        ControlView(id: bottomBarID, axis: .none)
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
  private func viewBody(
    main: ControlProps.MainAxisAlignment,
    cross: ControlProps.CrossAxisAlignment,
    spacing: CGFloat
  ) -> some View {
    if #available(iOS 16.0, macOS 13.0, *) {
      RufletFlexLayout(
        axis: .vertical,
        spacing: spacing,
        mainAlignment: main,
        crossAlignment: cross,
        tight: false
      ) {
        ForEach(node.childIDs, id: \.self) { childID in
          RufletFlexChild(id: childID, axis: .vertical)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    } else {
      VStack(alignment: cross.horizontal, spacing: main.usesSpacers ? 0 : spacing) {
        if main == .center || main == .end || main == .spaceAround || main == .spaceEvenly {
          Spacer(minLength: 0)
        }
        ControlList(ids: node.childIDs, axis: .vertical)
        if main == .center || main == .start || main == .spaceAround || main == .spaceEvenly {
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
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
    let radii = ControlProps.cornerRadii(node.props["border_radius"])
      ?? RufletCornerRadii(uniform: 0)
    let border = ControlProps.borderSides(node.props["border"])
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
      .background(background(radii: radii))
      .overlay(borderStroke(border: border, radii: radii))
      .clipShape(RufletRoundedRectangle(radii: radii))
      .contentShape(RufletRoundedRectangle(radii: radii))
      .modifier(TapReporter(node: node, events: events))
      .allowsHitTesting(!node.rufletBool("ignore_interactions"))
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
  private func background(radii: RufletCornerRadii) -> some View {
    let gradient = GradientProps.linear(node.props["gradient"])
    if let gradient {
      RufletRoundedRectangle(radii: radii).fill(gradient)
    } else if let color = MaterialPalette.color(node.string("bgcolor")) {
      RufletRoundedRectangle(radii: radii).fill(color)
    }
  }

  @ViewBuilder
  private func borderStroke(border: RufletBorder?, radii: RufletCornerRadii) -> some View {
    if let border {
      RufletBorderOverlay(border: border, radii: radii)
    }
  }
}

private struct RufletBorderOverlay: View {
  let border: RufletBorder
  let radii: RufletCornerRadii

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let top = border.top {
          top.color.frame(width: geometry.size.width, height: top.width)
            .position(x: geometry.size.width / 2, y: top.width / 2)
        }
        if let right = border.right {
          right.color.frame(width: right.width, height: geometry.size.height)
            .position(x: geometry.size.width - right.width / 2, y: geometry.size.height / 2)
        }
        if let bottom = border.bottom {
          bottom.color.frame(width: geometry.size.width, height: bottom.width)
            .position(x: geometry.size.width / 2, y: geometry.size.height - bottom.width / 2)
        }
        if let left = border.left {
          left.color.frame(width: left.width, height: geometry.size.height)
            .position(x: left.width / 2, y: geometry.size.height / 2)
        }
      }
      .clipShape(RufletRoundedRectangle(radii: radii))
    }
    .allowsHitTesting(false)
  }
}

/// Flet passes its continuous Flutter `Alignment(x, y)` straight to `Align`.
/// SwiftUI's frame API only exposes nine discrete alignment guides, so a
/// custom layout performs Flutter's exact free-space calculation instead of
/// rounding values such as `{x: 0.25, y: -0.6}` to center/top.
private struct ContainerAlignmentModifier: ViewModifier {
  let alignment: RufletAlignment?
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
  let alignment: RufletAlignment

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
    let origin = RufletGeometry.alignedOrigin(
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
  let alignment: RufletAlignment
  @ViewBuilder let content: () -> Content
  @State private var childSize: CGSize = .zero

  var body: some View {
    GeometryReader { proxy in
      let origin = RufletGeometry.alignedOrigin(
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
        .fill(MaterialPalette.color(node.string("bgcolor"), default: cardSurface))
        .shadow(
          color: MaterialPalette.color(
            node.string("shadow_color"), default: .black.opacity(0.2)),
          radius: CGFloat(node.double("elevation") ?? 1)))
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

    let begin = RufletGeometry.unitPoint(
      alignment: ControlProps.continuousAlignment(map["begin"]) ?? .topCenter)
    let end = RufletGeometry.unitPoint(
      alignment: ControlProps.continuousAlignment(map["end"]) ?? .bottomCenter)
    return LinearGradient(
      colors: colors,
      startPoint: UnitPoint(x: begin.x, y: begin.y),
      endPoint: UnitPoint(x: end.x, y: end.y))
  }
}
