import RufletEngine
import RufletProtocol
import SwiftUI

/// A `View` is Flet's route: it carries its own background and foreground
/// decoration, and `fullscreen_dialog` presents it as a sheet rather than a
/// push.
private struct ViewSurface: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    content
      .background(decoration(node.props["decoration"]))
      .overlay(decoration(node.props["foreground_decoration"]))
      .modifier(FullscreenDialogPresentation(isSheet: node.bool("fullscreen_dialog") == true))
      // `services` hang off the view the way they hang off the page: they are
      // registered rather than laid out.
      .onAppear { _ = node.controlIDs(forKey: "services") }
  }

  @ViewBuilder
  private func decoration(_ value: RufletValue?) -> some View {
    if let map = value?.mapValue {
      RoundedRectangle(cornerRadius: ControlProps.cornerRadius(map["border_radius"]) ?? 0)
        .fill(MaterialPalette.color(map["color"]?.stringValue, default: .clear))
    }
  }
}

/// A route presented as a fullscreen dialog gets the sheet's inset and corner
/// treatment rather than a pushed page's.
private struct FullscreenDialogPresentation: ViewModifier {
  let isSheet: Bool

  func body(content: Content) -> some View {
    if isSheet {
      content
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    } else {
      content
    }
  }
}

/// `ink` paints Material's touch ripple inside the container's own shape.
private struct ContainerInk: ViewModifier {
  let node: ControlNode
  let radii: RufletCornerRadii
  @State private var pressed = false

  func body(content: Content) -> some View {
    let interactive = node.handlesEvent("click") || node.handlesEvent("tap_down")
      || node.handlesEvent("long_press") || node.handlesEvent("hover")
      || node.string("url") != nil
    guard node.bool("ink") == true, interactive, node.bool("disabled") != true else {
      return AnyView(content)
    }
    return AnyView(
      content
        .background(
          RufletRoundedRectangle(radii: radii)
            .fill(pressed
              ? MaterialPalette.color(node.string("ink_color"), default: .primary.opacity(0.1))
              : .clear))
        .simultaneousGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }))
  }
}

/// Flet opens `url` only when it is present. Keeping the gesture conditional
/// preserves a non-interactive Container's native hit-testing behavior.
private struct ContainerURLReporter: ViewModifier {
  let rawURL: String?
  @Environment(\.openURL) private var openURL

  @ViewBuilder
  func body(content: Content) -> some View {
    if let rawURL, let url = URL(string: rawURL) {
      content.onTapGesture { openURL(url) }
    } else {
      content
    }
  }
}

/// `blur` is Flutter's backdrop filter over whatever the container covers.
private struct ContainerBlur: ViewModifier {
  let amount: Double?

  func body(content: Content) -> some View {
    if let amount, amount > 0 {
      content.background(.ultraThinMaterial).blur(radius: CGFloat(amount))
    } else {
      content
    }
  }
}

/// `color_filter` is a colour composited over the container in a blend mode.
private struct ContainerColorFilter: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    guard let map = value?.mapValue,
      let color = MaterialPalette.color(map["color"]?.stringValue)
    else { return AnyView(content) }
    return AnyView(
      content.overlay(
        color.blendMode(ControlProps.blendMode(map["blend_mode"]?.stringValue))))
  }
}

/// `foreground_decoration` paints over the child rather than behind it.
private struct ContainerForeground: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    guard let decoration = node.map("foreground_decoration") else { return AnyView(content) }
    var props = decoration
    // `parseBoxDecoration` names this list `shadows`; Container's own
    // top-level property is singular `shadow`.
    props["shadow"] = decoration["shadows"]
    let decorationNode = ControlNode(id: node.id, type: "Container", props: props)
    let semantics = RufletContainerSemantics(node: decorationNode)
    return AnyView(
      content.overlay(
        ContainerDecorationLayer(semantics: semantics)
          .blendMode(ControlProps.blendMode(semantics.blendMode))
          .modifier(ContainerShadows(value: decoration["shadows"]))
          .overlay(ContainerBorderLayer(
            border: semantics.border, shape: semantics.shape, radii: semantics.radii))
          .allowsHitTesting(false)))
  }
}

/// `shadow` is Flutter's BoxShadow list; SwiftUI takes them one at a time.
private struct ContainerShadows: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    var result = AnyView(content)
    for shadow in RufletBoxShadowSpec.parseList(value) {
      // Flutter's BoxShadow blur radius is sigma*2. SwiftUI's shadow radius
      // is sigma, and a positive spread expands the painted silhouette.
      let blurSigma = CGFloat(shadow.blurRadius) / 2
      let spread = CGFloat(shadow.spreadRadius)
      result = AnyView(
        result.shadow(
          color: MaterialPalette.color(shadow.colorToken, default: .black),
          radius: max(blurSigma + spread, 0),
          x: CGFloat(shadow.offsetX), y: CGFloat(shadow.offsetY)))
    }
    return result
  }
}

struct RufletBoxShadowSpec: Equatable {
  let colorToken: String?
  let offsetX: Double
  let offsetY: Double
  let blurStyle: String
  let blurRadius: Double
  let spreadRadius: Double

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return nil }
    colorToken = map["color"]?.stringValue
    offsetX = map["offset"]?.mapValue?["x"]?.doubleValue ?? 0
    offsetY = map["offset"]?.mapValue?["y"]?.doubleValue ?? 0
    blurStyle = map["blur_style"]?.stringValue?.lowercased() ?? "normal"
    blurRadius = map["blur_radius"]?.doubleValue ?? 0
    spreadRadius = map["spread_radius"]?.doubleValue ?? 0
  }

  static func parseList(_ value: RufletValue?) -> [RufletBoxShadowSpec] {
    let values = value?.arrayValue ?? value.map { [$0] } ?? []
    return values.compactMap(RufletBoxShadowSpec.init)
  }
}

/// `Page` — the session root, wire id 1.
///
/// Its `views` prop is a navigator stack. As Flutter's Navigator does, the
/// native host keeps earlier routes mounted offstage and exposes only the top
/// route to interaction. That retained pair is also what lets Hero geometry
/// move between routes. `_overlay`, `_dialogs` and `_services` hang off the
/// page too, but are presented by the active view rather than laid out inline.
struct PageControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletNativeScene) private var nativeScene
  @Environment(\.rufletEvents) private var events
  @Environment(\.displayScale) private var displayScale
  @Namespace private var heroNamespace
  @StateObject private var popCoordinator = RufletViewPopCoordinator()

  var body: some View {
    Group {
      if let presentationPage {
        Group {
          let viewIDs = presentationPage.controlIDs(forKey: "views")
          if let activeViewID = viewIDs.last {
            ZStack {
              ForEach(viewIDs, id: \.self) { viewID in
                let isActive = RufletHeroSemantics.providesGeometry(
                  viewID: viewID, activeViewID: activeViewID)
                ControlView(id: viewID, axis: .vertical)
                  .environment(
                    \.rufletNavigationContext,
                    navigationContext(page: presentationPage, viewID: viewID))
                  .environment(\.rufletHeroProvidesGeometry, isActive)
                  .opacity(isActive ? 1 : 0)
                  .allowsHitTesting(isActive)
                  .accessibilityHidden(!isActive)
                  .zIndex(isActive ? 1 : 0)
              }
            }
            .animation(.default, value: activeViewID)
          } else {
            Color.clear
          }
        }
        .environment(\.rufletPageScrollCommand, RufletPageScrollCommand(node.props["_scroll_command"]))
        .modifier(PageChrome(node: presentationPage, eventNode: node))
      } else {
        Color.clear
          .modifier(PageChrome(node: node, eventNode: node))
      }
    }
    .environment(\.rufletHeroNamespace, heroNamespace)
    .onOpenURL { url in
      applyClientRoute(PageRouteSemantics.normalizeExternalURL(url))
    }
    .rufletCommandHandler(node.id, method: "push_route") { call, completion in
      guard let route = call.argument("route")?.stringValue else {
        completion(.failure(RufletServiceError.invalidArguments("route is required")))
        return
      }
      applyClientRoute(route)
      completion(.success(.null))
    }
    .modifier(
      PageScreenshotCaptureModifier(
        node: node, store: store, events: events, displayScale: displayScale))
  }

  /// Flet selects the `BasePage` whose `view_id` matches the native platform
  /// view. A scene with no matching BasePage deliberately shows the startup
  /// surface until Ruby handles `multi_view_add` and supplies it.
  private var presentationPage: ControlNode? {
    // The process-wide registry owns the real platform-scene lifecycle and
    // dispatches Page.on_multi_view_add/on_multi_view_remove. Naming that
    // dependency here also keeps the Page contract tied to its actual host,
    // rather than pretending those callbacks originate in a rendered view.
    _ = RufletNativeSceneRegistry.self
    guard let nativeScene else { return node }
    return node.controlIDs(forKey: "multi_views")
      .compactMap(store.node)
      .first(where: { $0.int("view_id") == nativeScene.id })
  }

  /// Flutter's implied AppBar leading button asks the enclosing Navigator to
  /// pop. Flet then emits Page.view_pop (or View.confirm_pop) and waits for
  /// Ruby to patch the view stack; the native host follows the same protocol.
  private func navigationContext(page: ControlNode, viewID: Int) -> RufletNavigationContext {
    let views = page.controlIDs(forKey: "views")
    guard RufletPageNavigation.canImplyLeading(viewCount: views.count),
      let view = store.node(viewID)
    else {
      return RufletNavigationContext()
    }
    return RufletNavigationContext(
      canPop: true,
      fullscreenDialog: view.bool("fullscreen_dialog") ?? false,
      requestPop: {
        popCoordinator.request(page: node, view: view, events: events)
      },
      confirmPop: { shouldPop in
        popCoordinator.confirm(shouldPop: shouldPop)
      })
  }

  /// Flet's route provider updates the Page locally, sends update_control, and
  /// then emits route_change without checking for a subscribed handler.
  private func applyClientRoute(_ route: String) {
    guard store.node(node.id)?.string("route") != route else { return }
    events.setLocal(node.id, "route", .string(route))
    events.update(node.id, ["route": .string(route)])
    events.send(node.id, "route_change", .map(["route": .string(route)]))
  }
}

enum PageRouteSemantics {
  /// Flet discards an external URI's scheme/authority and routes by its
  /// path/query/fragment. `ruflet://app/store?q=1#top` therefore becomes
  /// `/store?q=1#top`.
  static func normalizeExternalURL(_ url: URL) -> String {
    var route = url.path.isEmpty ? "/" : url.path
    if let query = url.query, !query.isEmpty { route += "?\(query)" }
    if let fragment = url.fragment, !fragment.isEmpty { route += "#\(fragment)" }
    return route
  }
}

/// Flet conditionally installs a root RepaintBoundary when
/// `enable_screenshots` is true. The Apple renderer mirrors that boundary at
/// the mounted Page and returns PNG bytes through the Page method call.
private struct PageScreenshotCaptureModifier: ViewModifier {
  let node: ControlNode
  let store: ControlStore
  let events: RufletEventSink
  let displayScale: CGFloat

  func body(content: Content) -> some View {
    content.rufletCommandHandler(node.id, method: "take_screenshot") { call, completion in
      // Consult the current store node rather than the value captured when the
      // view first mounted; Ruby may toggle screenshot support in a later
      // patch without replacing the mounted Page identity.
      guard store.node(node.id)?.bool("enable_screenshots") == true else {
        completion(.success(.null))
        return
      }

      let delay = RufletScreenshotSemantics.delayMilliseconds(call.argument("delay"))
      let pixelRatio = call.argument("pixel_ratio")?.doubleValue.map { CGFloat($0) }
        ?? displayScale
      let capture = {
        guard #available(iOS 16.0, macOS 13.0, *) else {
          completion(.success(.null))
          return
        }
        let renderer = ImageRenderer(
          content: content
            .environmentObject(store)
            .environment(\.rufletEvents, events))
        renderer.scale = pixelRatio

        #if canImport(UIKit)
          let data = renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
          let data = renderer.nsImage
            .flatMap(\.tiffRepresentation)
            .flatMap(NSBitmapImageRep.init(data:))
            .flatMap { $0.representation(using: .png, properties: [:]) }
        #else
          let data: Data? = nil
        #endif
        completion(.success(data.map { .binary([UInt8]($0)) } ?? .null))
      }

      if delay > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1_000, execute: capture)
      } else {
        capture()
      }
    }
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

}

/// The rest of the page's own surface: the fonts it registers, the media it
/// reports, the accessibility overlay, and the route and session events Flet's
/// backend raises on the page rather than on a control.
private struct PageEnvironment: ViewModifier {
  let node: ControlNode
  let eventNode: ControlNode
  @Environment(\.rufletEvents) private var events
  @EnvironmentObject private var store: ControlStore

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
        events.fire(eventNode, "connect")
        _ = node.bool("enable_screenshots")
        _ = node.controlID(forKey: "window")
        _ = node.string("sess")
        _ = node.array("multi_views")
        viewRoutes = routes
      }
      .onDisappear {
        events.fire(eventNode, "disconnect")
        events.fire(eventNode, "close")
      }
      .onChange(of: routes) { nextRoutes in
        // Flet reports the route that the platform navigator popped. Preserve
        // the route rather than reducing this to a count-only notification.
        if nextRoutes.count < viewRoutes.count,
          let popped = viewRoutes.dropFirst(nextRoutes.count).first
        {
          events.fire(eventNode, "view_pop", data: .map(["route": .string(popped)]))
        }
        viewRoutes = nextRoutes
      }
  }

  @State private var viewRoutes: [String] = []

  private var routes: [String] {
    node.controlIDs(forKey: "views").map { id in
      // A View's route defaults to its id in Flet's pop protocol.
      store.node(id)?.string("route") ?? String(id)
    }
  }

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
    events.setLocal(eventNode.id, "media", value)
    events.update(eventNode.id, ["media": value])
    events.fire(eventNode, "media_change", data: value)
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
  let eventNode: ControlNode
  @EnvironmentObject private var store: ControlStore

  func body(content: Content) -> some View {
    content
      .modifier(MaterialThemeModifier(theme: node.map("theme"), darkTheme: node.map("dark_theme")))
      .preferredColorScheme(colorScheme)
      .overlay(overlayLayer)
      .modifier(WindowTitle(title: node.string("title")))
      .modifier(PageLifecycle(node: eventNode))
      .modifier(PageEnvironment(node: node, eventNode: eventNode))
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
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletNavigationContext) private var navigation
  @StateObject private var scaffoldHost = RufletScaffoldHostState()

  var body: some View {
    let main = ControlProps.MainAxisAlignment(node.rufletString("vertical_alignment"))
    let cross = ControlProps.CrossAxisAlignment(node.rufletString("horizontal_alignment"))
    let spacing = CGFloat(node.rufletDouble("spacing"))

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
          .background(
            GeometryReader { proxy in
              Color.clear.preference(
                key: BottomBarFramePreferenceKey.self,
                value: proxy.frame(in: .named(scaffoldCoordinateSpace)))
            })
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .modifier(ViewSurface(node: node))
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
    .coordinateSpace(name: scaffoldCoordinateSpace)
    .onPreferenceChange(BottomBarFramePreferenceKey.self) {
      scaffoldHost.reportBottomBar(frame: $0)
    }
    .onPreferenceChange(FABFramePreferenceKey.self) {
      scaffoldHost.reportFAB(frame: $0)
    }
    .environment(\.rufletScaffoldHost, scaffoldHost)
    .environment(\.rufletScaffoldSlots, scaffoldSlots)
    .modifier(DrawerPresenter(node: node))
    .modifier(DialogPresenter(host: node))
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "show_drawer", "close_drawer", "show_end_drawer", "close_end_drawer":
        RufletViewCommands.performDrawer(
          call.name, view: node, store: store, events: events)
        completion(.success(.null))
      case "confirm_pop":
        navigation.confirmPop(call.argument("should_pop")?.boolValue ?? false)
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
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
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: FABFramePreferenceKey.self,
              value: proxy.frame(in: .named(scaffoldCoordinateSpace)))
          })
        .modifier(
          FABScaffoldPlacement(
            location: node.props["floating_action_button_location"],
            bottomBarHeight: scaffoldHost.bottomBarFrame.height,
            appBarHeight: appBarHeight,
            fabSize: measuredFABSize))
    }
  }

  /// Flet's `FloatingActionButtonLocation`, reduced to the corner it names.
  private var fabAlignment: Alignment {
    RufletFABPlacement(node.props["floating_action_button_location"]).alignment
  }

  private var measuredFABSize: CGSize {
    scaffoldHost.fabFrame.isNull ? CGSize(width: 56, height: 56) : scaffoldHost.fabFrame.size
  }

  private var appBarHeight: CGFloat {
    guard let id = node.controlID(forKey: "appbar"), let appBar = store.node(id) else { return 0 }
    if appBar.type == "CupertinoAppBar" {
      return RufletCupertinoAppBarConfiguration(node: appBar).renderedHeight
    }
    return ChromeDefaults.appBar(appBar).toolbarHeight
  }

  private var scaffoldCoordinateSpace: String { "ruflet-scaffold-\(node.id)" }

  private var scaffoldSlots: RufletScaffoldSlots {
    RufletScaffoldSlots(
      hasDrawer: node.controlID(forKey: "drawer") != nil,
      hasEndDrawer: node.controlID(forKey: "end_drawer") != nil,
      openDrawer: { setDrawerOpen(key: "drawer") },
      openEndDrawer: { setDrawerOpen(key: "end_drawer") })
  }

  private func setDrawerOpen(key: String) {
    guard let id = node.controlID(forKey: key) else { return }
    events.setLocal(id, "_open", .bool(true))
  }
}

/// Exact imperative command surface installed by Flet's `ViewControlState`.
/// Drawer state belongs to the rendered drawer node, while dismissal is an
/// event of that drawer after Scaffold has actually closed it.
enum RufletViewCommands {
  static let methods: Set<String> = [
    "close_drawer", "close_end_drawer", "confirm_pop", "show_drawer",
    "show_end_drawer",
  ]

  static func performDrawer(
    _ method: String,
    view: ControlNode,
    store: ControlStore,
    events: RufletEventSink
  ) {
    let end = method.contains("end_drawer")
    let opening = method.hasPrefix("show")
    let key = end ? "end_drawer" : "drawer"
    guard let id = view.controlID(forKey: key), let drawer = store.node(id) else { return }
    events.setLocal(id, "_open", .bool(opening))
    if !opening { events.fire(drawer, "dismiss") }
  }
}

private struct BottomBarFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .null
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

private struct FABFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .null
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// Flet delegates these placements to Flutter's Scaffold. The important
/// distinction for BottomAppBar is docked (the FAB centre sits on the bar's
/// top edge), floating (a 16pt gap), and contained (centred inside the bar).
private struct FABScaffoldPlacement: ViewModifier {
  let location: RufletValue?
  let bottomBarHeight: CGFloat
  let appBarHeight: CGFloat
  let fabSize: CGSize

  func body(content: Content) -> some View {
    let padding = RufletFABPlacement(location).padding(
      bottomBarHeight: bottomBarHeight, appBarHeight: appBarHeight, fabSize: fabSize)
    return content
      .padding(padding)
  }
}

/// Source-derived placement names for the FAB slot shared by View and Pagelet.
/// The rendering stays a native overlay; only the Scaffold geometry contract
/// (start/center/end and top/float/docked/contained) is carried across.
struct RufletFABPlacement: Equatable {
  enum Horizontal: Equatable { case start, center, end }
  enum Vertical: Equatable { case top, floating, docked, contained, custom }

  let horizontal: Horizontal
  let vertical: Vertical
  let customOffset: CGPoint?
  let mini: Bool

  init(_ value: RufletValue?) {
    if let point = Self.point(value) {
      horizontal = .end
      vertical = .custom
      customOffset = point
      mini = false
      return
    }
    let raw = value?.stringValue?.lowercased()
      .replacingOccurrences(of: "_", with: "") ?? "endfloat"
    horizontal = raw.contains("center") ? .center : (raw.contains("start") ? .start : .end)
    vertical = raw.contains("top") ? .top
      : raw.contains("docked") ? .docked
      : raw.contains("contained") ? .contained : .floating
    customOffset = nil
    mini = raw.hasPrefix("mini")
  }

  var alignment: Alignment {
    switch (horizontal, vertical) {
    case (.start, .top): return .topLeading
    case (.center, .top): return .top
    case (.end, .top): return .topTrailing
    case (.start, _): return .bottomLeading
    case (.center, _): return .bottom
    case (.end, _): return .bottomTrailing
    }
  }

  func padding(
    bottomBarHeight: CGFloat, appBarHeight: CGFloat, fabSize: CGSize
  ) -> EdgeInsets {
    if let customOffset {
      return EdgeInsets(
        top: 0, leading: 0,
        bottom: customOffset.y - fabSize.height,
        trailing: customOffset.x - fabSize.width)
    }
    let horizontalInset: CGFloat = horizontal == .center ? 0 : (mini ? 12 : 16)
    switch vertical {
    case .top:
      return EdgeInsets(
        top: max(0, appBarHeight - fabSize.height / 2),
        leading: horizontal == .start ? horizontalInset : 0,
        bottom: 0, trailing: horizontal == .end ? horizontalInset : 0)
    case .contained:
      return EdgeInsets(
        top: 0, leading: horizontal == .start ? horizontalInset : 0,
        bottom: max(0, (bottomBarHeight - fabSize.height) / 2),
        trailing: horizontal == .end ? horizontalInset : 0)
    case .docked:
      return EdgeInsets(
        top: 0, leading: horizontal == .start ? horizontalInset : 0,
        bottom: max(0, bottomBarHeight - fabSize.height / 2),
        trailing: horizontal == .end ? horizontalInset : 0)
    case .floating, .custom:
      return EdgeInsets(
        top: 0, leading: horizontal == .start ? horizontalInset : 0,
        bottom: bottomBarHeight + (mini ? 12 : 16),
        trailing: horizontal == .end ? horizontalInset : 0)
    }
  }

  private static func point(_ value: RufletValue?) -> CGPoint? {
    if let items = value?.arrayValue, items.count > 1 {
      return CGPoint(x: items[0].doubleValue ?? 0, y: items[1].doubleValue ?? 0)
    }
    if let map = value?.mapValue {
      return CGPoint(x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0)
    }
    return nil
  }
}

/// `Container` — the single-child decorator: padding, background, border,
/// corner radius, alignment, and an optional tap target.
struct ContainerControlView: View {
  let node: ControlNode
  let axis: LayoutAxis

  @Environment(\.rufletEvents) private var events
  var body: some View {
    let semantics = RufletContainerSemantics(node: node)

    content
      .padding(semantics.padding ?? EdgeInsets())
      // A ResponsiveRow supplies Flutter-tight horizontal constraints. Apply
      // them before painting the Container so its background, border and hit
      // target fill the grid cell instead of stopping at the text's intrinsic
      // width.
      .modifier(
        ContainerAlignmentModifier(
          alignment: semantics.alignment,
          requiresTightWidth: axis.requiresTightWidth)
      )
      .background(
        ContainerDecorationLayer(semantics: semantics)
          .blendMode(ControlProps.blendMode(semantics.blendMode)))
      .overlay(ContainerBorderLayer(
        border: semantics.border, shape: semantics.shape, radii: semantics.radii))
      .modifier(ContainerClip(
        behavior: semantics.clipBehavior, shape: semantics.shape, radii: semantics.radii))
      .modifier(ContainerContentShape(shape: semantics.shape, radii: semantics.radii))
      .modifier(TapReporter(node: node, events: events))
      .modifier(ContainerURLReporter(rawURL: node.string("url")))
      .modifier(ContainerInk(node: node, radii: semantics.radii))
      .modifier(ContainerBlur(amount: semantics.blur.maximumSigma))
      .modifier(ContainerColorFilter(value: node.props["color_filter"]))
      .modifier(ContainerForeground(node: node))
      .modifier(ContainerShadows(value: node.props["shadow"]))
      .modifier(
        MaterialThemeModifier(theme: node.map("theme"), darkTheme: node.map("dark_theme")))
      .preferredColorScheme(themeMode)
      .modifier(ContainerImplicitAnimation(node: node))
      .allowsHitTesting(!node.rufletBool("ignore_interactions"))
  }

  /// `theme_mode` overrides the platform for this subtree, the way a Container
  /// carrying its own theme does in Flutter.
  private var themeMode: ColorScheme? {
    switch node.string("theme_mode")?.lowercased() {
    case "light": return .light
    case "dark": return .dark
    default: return nil
    }
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

}

struct RufletContainerAnimationSpec: Equatable {
  let durationMilliseconds: Double
  let curve: String

  init?(_ value: RufletValue?) {
    guard let value else { return nil }
    if case .bool(true) = value {
      durationMilliseconds = 1_000
      curve = "linear"
    } else if let duration = value.doubleValue {
      durationMilliseconds = max(duration, 0)
      curve = "linear"
    } else if let map = value.mapValue {
      durationMilliseconds = max(map["duration"]?.doubleValue ?? 0, 0)
      curve = map["curve"]?.stringValue?.lowercased() ?? "linear"
    } else {
      return nil
    }
  }

  var animation: Animation {
    RufletCurve.animation(curve, duration: durationMilliseconds / 1_000)
  }
}

private struct ContainerImplicitAnimation: ViewModifier {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var pendingToken = UUID()

  private var state: [RufletValue] {
    ["width", "height", "margin", "alignment", "padding", "bgcolor", "gradient",
     "border", "border_radius", "shadow", "shape", "blend_mode", "image",
     "foreground_decoration"].map { node.props[$0] ?? .null }
  }

  func body(content: Content) -> some View {
    guard let spec = RufletContainerAnimationSpec(node.props["animate"]) else {
      return AnyView(content)
    }
    return AnyView(
      content
        .animation(spec.animation, value: state)
        .onChange(of: state) { _ in
          guard node.handlesEvent("animation_end") else { return }
          let token = UUID()
          pendingToken = token
          DispatchQueue.main.asyncAfter(
            deadline: .now() + spec.durationMilliseconds / 1_000
          ) {
            guard pendingToken == token else { return }
            events.fire(node, "animation_end", data: .string("container"))
          }
        })
  }
}

enum RufletContainerShape: String, Equatable {
  case rectangle
  case circle

  init(_ raw: String?) {
    self = raw?.lowercased() == "circle" ? .circle : .rectangle
  }
}

enum RufletContainerClipBehavior: String, Equatable {
  case none
  case hardEdge
  case antiAlias
  case antiAliasWithSaveLayer

  init(_ raw: String?, hasBorderRadius: Bool) {
    let normalized = raw?.lowercased().replacingOccurrences(of: "_", with: "")
    switch normalized {
    case "none": self = .none
    case "hardedge": self = .hardEdge
    case "antialiaswithsavelayer": self = .antiAliasWithSaveLayer
    case "antialias": self = .antiAlias
    default: self = hasBorderRadius ? .antiAlias : .none
    }
  }
}

struct RufletContainerBlur: Equatable {
  let sigmaX: Double
  let sigmaY: Double
  let tileMode: String?
  var maximumSigma: Double? {
    let value = max(sigmaX, sigmaY)
    return value > 0 ? value : nil
  }

  init(_ value: RufletValue?) {
    if let scalar = value?.doubleValue {
      sigmaX = scalar
      sigmaY = scalar
      tileMode = nil
    } else if let list = value?.arrayValue {
      sigmaX = list.first?.doubleValue ?? 0
      sigmaY = list.dropFirst().first?.doubleValue ?? list.first?.doubleValue ?? 0
      tileMode = nil
    } else if let map = value?.mapValue {
      sigmaX = map["sigma_x"]?.doubleValue ?? 0
      sigmaY = map["sigma_y"]?.doubleValue ?? 0
      tileMode = map["tile_mode"]?.stringValue
    } else {
      sigmaX = 0
      sigmaY = 0
      tileMode = nil
    }
  }
}

struct RufletDecorationImageSpec: Equatable {
  let source: RufletImageSource
  let fit: String?
  let alignment: RufletAlignment
  let repeatMode: RufletImagePresentation.RepeatMode
  let matchTextDirection: Bool
  let scale: Double
  let opacity: Double
  let filterQuality: String
  let invertColors: Bool
  let antiAlias: Bool
  let colorFilter: RufletValue?

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return nil }
    let source = RufletImageSource(value: map["src"])
    guard source != .missing else { return nil }
    self.source = source
    fit = map["fit"]?.stringValue?.lowercased()
    alignment = ControlProps.continuousAlignment(map["alignment"]) ?? .center
    repeatMode = RufletImagePresentation.RepeatMode(map["repeat"]?.stringValue)
    matchTextDirection = map["match_text_direction"]?.boolValue ?? false
    scale = map["scale"]?.doubleValue ?? 1
    opacity = map["opacity"]?.doubleValue ?? 1
    filterQuality = map["filter_quality"]?.stringValue?.lowercased() ?? "medium"
    invertColors = map["invert_colors"]?.boolValue ?? false
    antiAlias = map["anti_alias"]?.boolValue ?? false
    colorFilter = map["color_filter"]
  }

  var interpolation: Image.Interpolation {
    switch filterQuality {
    case "none": return .none
    case "low": return .low
    case "high": return .high
    default: return .medium
    }
  }
}

struct RufletContainerSemantics {
  let padding: EdgeInsets?
  let alignment: RufletAlignment?
  let radii: RufletCornerRadii
  let hasBorderRadius: Bool
  let shape: RufletContainerShape
  let clipBehavior: RufletContainerClipBehavior
  let border: RufletBorder?
  let backgroundColorToken: String?
  let blendMode: String?
  let gradient: RufletGradientSpec?
  let image: RufletDecorationImageSpec?
  let blur: RufletContainerBlur

  init(node: ControlNode) {
    padding = ControlProps.edgeInsets(node.props["padding"])
    alignment = ControlProps.continuousAlignment(node.props["alignment"])
    let parsedRadii = ControlProps.cornerRadii(node.props["border_radius"])
    hasBorderRadius = parsedRadii != nil
    radii = parsedRadii ?? RufletCornerRadii(uniform: 0)
    shape = RufletContainerShape(node.string("shape"))
    clipBehavior = RufletContainerClipBehavior(
      node.string("clip_behavior"), hasBorderRadius: hasBorderRadius)
    border = RufletContainerBorderParser.parse(node.props["border"])
    backgroundColorToken = node.string("bgcolor")
    blendMode = node.string("blend_mode")
    gradient = RufletGradientSpec(node.props["gradient"])
    image = RufletDecorationImageSpec(node.props["image"])
    blur = RufletContainerBlur(node.props["blur"])
  }
}

/// Container passes `Theme.colorScheme.primary` as Flet's default side color.
/// A present BorderSide also defaults to width 1 and solid style; absent sides
/// remain `BorderSide.none` and therefore are not painted.
private enum RufletContainerBorderParser {
  static func parse(_ value: RufletValue?) -> RufletBorder? {
    guard let map = value?.mapValue else { return nil }

    func side(_ value: RufletValue?) -> RufletBorderSide? {
      guard let map = value?.mapValue else { return nil }
      if map["style"]?.stringValue?.lowercased() == "none" { return nil }
      let width = CGFloat(map["width"]?.doubleValue ?? 1)
      guard width > 0 else { return nil }
      return RufletBorderSide(
        color: MaterialPalette.color(map["color"]?.stringValue, default: .primary),
        width: width)
    }

    // Keep accepting the compact uniform side emitted by older Ruflet Ruby
    // clients while matching Flet's four-side map when present.
    if map["width"] != nil || map["color"] != nil || map["style"] != nil {
      guard let uniform = side(value) else { return nil }
      return RufletBorder(top: uniform, right: uniform, bottom: uniform, left: uniform)
    }
    let border = RufletBorder(
      top: side(map["top"]), right: side(map["right"]),
      bottom: side(map["bottom"]), left: side(map["left"]))
    return border.isEmpty ? nil : border
  }
}

private struct ContainerClip: ViewModifier {
  let behavior: RufletContainerClipBehavior
  let shape: RufletContainerShape
  let radii: RufletCornerRadii

  @ViewBuilder
  func body(content: Content) -> some View {
    switch (behavior, shape) {
    case (.none, _): content
    case (.hardEdge, .circle): content.clipShape(Circle(), style: FillStyle(antialiased: false))
    case (.hardEdge, .rectangle):
      content.clipShape(RufletRoundedRectangle(radii: radii), style: FillStyle(antialiased: false))
    case (_, .circle): content.clipShape(Circle(), style: FillStyle(antialiased: true))
    case (_, .rectangle):
      content.clipShape(RufletRoundedRectangle(radii: radii), style: FillStyle(antialiased: true))
    }
  }
}

private struct ContainerContentShape: ViewModifier {
  let shape: RufletContainerShape
  let radii: RufletCornerRadii

  @ViewBuilder
  func body(content: Content) -> some View {
    if shape == .circle { content.contentShape(Circle()) }
    else { content.contentShape(RufletRoundedRectangle(radii: radii)) }
  }
}

private struct ContainerDecorationLayer: View {
  let semantics: RufletContainerSemantics

  @ViewBuilder
  var body: some View {
    GeometryReader { geometry in
      if semantics.shape == .circle {
        ZStack {
          Circle().fill(fillStyle(size: geometry.size))
          if let image = semantics.image {
            ContainerDecorationImage(spec: image).clipShape(Circle())
          }
        }
      } else {
        ZStack {
          RufletRoundedRectangle(radii: semantics.radii).fill(fillStyle(size: geometry.size))
          if let image = semantics.image {
            ContainerDecorationImage(spec: image)
              .clipShape(RufletRoundedRectangle(radii: semantics.radii))
          }
        }
      }
    }
  }

  private func fillStyle(size: CGSize) -> AnyShapeStyle {
    if let gradient = semantics.gradient { return gradient.shapeStyle(size: size) }
    if let color = MaterialPalette.color(semantics.backgroundColorToken) {
      return AnyShapeStyle(color)
    }
    return AnyShapeStyle(Color.clear)
  }
}

private struct ContainerDecorationImage: View {
  let spec: RufletDecorationImageSpec
  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    Group { image }
      .modifier(DecorationImageFit(fit: spec.fit))
      .opacity(spec.opacity)
      .scaleEffect(
        x: spec.matchTextDirection && layoutDirection == .rightToLeft ? -1 : 1,
        y: 1)
      .modifier(DecorationImageInvert(enabled: spec.invertColors))
      .modifier(DecorationImageColorFilter(value: spec.colorFilter))
      .allowsHitTesting(false)
  }

  @ViewBuilder
  private var image: some View {
    switch spec.source {
    case .binary(let data):
      PlatformImageView(
        data: data, repeatMode: spec.repeatMode, interpolation: spec.interpolation)
    case .remote(let url) where url.isFileURL:
      if let data = try? Data(contentsOf: url) {
        PlatformImageView(
          data: data, repeatMode: spec.repeatMode, interpolation: spec.interpolation)
      }
    case .remote(let url):
      AsyncImage(url: url) { image in
        image.resizable(resizingMode: spec.repeatMode.swiftUI).interpolation(spec.interpolation)
      } placeholder: { Color.clear }
    case .asset(let name):
      if let data = RufletImageSource.packagedData(named: name) {
        PlatformImageView(
          data: data, repeatMode: spec.repeatMode, interpolation: spec.interpolation)
      } else {
        Image(name).resizable(resizingMode: spec.repeatMode.swiftUI).interpolation(spec.interpolation)
      }
    case .empty, .invalid, .missing:
      Color.clear
    }
  }
}

private struct DecorationImageInvert: ViewModifier {
  let enabled: Bool
  @ViewBuilder func body(content: Content) -> some View {
    if enabled { content.colorInvert() } else { content }
  }
}

private struct DecorationImageFit: ViewModifier {
  let fit: String?

  func body(content: Content) -> some View {
    switch fit?.lowercased() {
    case "cover": return AnyView(content.aspectRatio(contentMode: .fill))
    case "fill": return AnyView(content)
    case "none", "scaledown": return AnyView(content.fixedSize())
    default: return AnyView(content.aspectRatio(contentMode: .fit))
    }
  }
}

private struct DecorationImageColorFilter: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    guard let map = value?.mapValue,
      let color = MaterialPalette.color(map["color"]?.stringValue)
    else { return AnyView(content) }
    return AnyView(content.colorMultiply(color).blendMode(
      ControlProps.blendMode(map["blend_mode"]?.stringValue)))
  }
}

private extension RufletBorder {
  var uniformSide: RufletBorderSide? {
    guard let first = [top, right, bottom, left].compactMap({ $0 }).first else { return nil }
    let sides = [top, right, bottom, left]
    guard sides.allSatisfy({ side in
      guard let side else { return false }
      return side.width == first.width
    }) else { return nil }
    return first
  }
}

private struct ContainerBorderLayer: View {
  let border: RufletBorder?
  let shape: RufletContainerShape
  let radii: RufletCornerRadii

  @ViewBuilder
  var body: some View {
    if let border {
      if shape == .circle, let side = border.uniformSide {
        Circle().strokeBorder(side.color, lineWidth: side.width)
      } else {
        RufletBorderOverlay(border: border, radii: radii)
      }
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

enum RufletCardVariant: String, Equatable {
  case elevated
  case filled
  case outlined

  init(_ value: String?) {
    self = RufletCardVariant(rawValue: value?.lowercased() ?? "") ?? .elevated
  }
}

enum RufletCardShapeKind: String, Equatable {
  case roundedRectangle = "roundedrectangle"
  case stadium
  case circle
  case beveledRectangle = "beveledrectangle"
  case continuousRectangle = "continuousrectangle"
}

/// Values Card obtains from Flutter's constructor and Material 3 defaults.
/// Flet forwards optional wire fields unchanged, so resolving the nil cases is
/// native-renderer work rather than Ruby DSL policy.
struct RufletCardMetrics: Equatable {
  /// Rendering policy only. Semantic values below always retain the pinned
  /// Flet/Flutter defaults even when a native GroupBox realizes the control.
  let requiresCustomAppearance: Bool
  let variant: RufletCardVariant
  let fillToken: String
  let shadowToken: String
  let elevation: CGFloat
  let margin: EdgeInsets
  let shapeKind: RufletCardShapeKind
  let shapeWasParsed: Bool
  let radii: RufletCornerRadii
  let eccentricity: CGFloat
  let outlineToken: String?
  let outlineWidth: CGFloat
  let outlineStrokeAlign: CGFloat
  let clipBehavior: String
  let semanticContainer: Bool
  let showBorderOnForeground: Bool

  init(node: ControlNode) {
    requiresCustomAppearance = ["bgcolor", "shadow_color", "elevation", "shape"]
      .contains { node.props[$0] != nil }
    variant = RufletCardVariant(node.string("variant"))
    fillToken = node.string("bgcolor") ?? Self.defaultFill(variant)
    shadowToken = node.string("shadow_color") ?? "shadow"
    elevation = CGFloat(node.double("elevation") ?? (variant == .elevated ? 1 : 0))
    margin = ControlProps.edgeInsets(node.props["margin"])
      ?? EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
    clipBehavior = node.string("clip_behavior") ?? "none"
    semanticContainer = node.bool("semantic_container") != false
    showBorderOnForeground = node.bool("show_border_on_foreground") != false

    let shape = node.map("shape")
    let parsedKind = RufletCardShapeKind(
      rawValue: shape?["_type"]?.stringValue?.lowercased() ?? "")
    shapeWasParsed = parsedKind != nil
    shapeKind = parsedKind ?? .roundedRectangle
    radii = shapeWasParsed
      ? (ControlProps.cornerRadii(shape?["radius"]) ?? RufletCornerRadii(uniform: 0))
      : RufletCornerRadii(uniform: 12)
    eccentricity = CGFloat(shape?["eccentricity"]?.doubleValue ?? 0)

    if shapeWasParsed, let side = shape?["side"]?.mapValue,
      side["style"]?.stringValue?.lowercased() != "none"
    {
      outlineToken = side["color"]?.stringValue ?? "black"
      outlineWidth = CGFloat(side["width"]?.doubleValue ?? 1)
      outlineStrokeAlign = CGFloat(side["stroke_align"]?.doubleValue ?? -1)
    } else if !shapeWasParsed, variant == .outlined {
      outlineToken = "outlinevariant"
      outlineWidth = 1
      outlineStrokeAlign = -1
    } else {
      outlineToken = nil
      outlineWidth = 0
      outlineStrokeAlign = -1
    }
  }

  /// Compatibility for callers/tests interested in the uniform Material
  /// default. Rendering uses all four values from `radii`.
  var radius: CGFloat { radii.maximum }

  private static func defaultFill(_ variant: RufletCardVariant) -> String {
    switch variant {
    case .elevated: return "surfacecontainerlow"
    case .filled: return "surfacecontainerhighest"
    case .outlined: return "surface"
    }
  }
}

/// ShapeBorder subset accepted by Flet's `parseShape`. All five names retain
/// their native outline, fill and clipping geometry instead of collapsing to
/// whichever corner happened to be largest.
struct RufletCardShape: Shape {
  let kind: RufletCardShapeKind
  let radii: RufletCornerRadii
  let eccentricity: CGFloat

  func path(in rect: CGRect) -> Path {
    switch kind {
    case .circle:
      let adjusted: CGRect
      if eccentricity == 0 || rect.width == rect.height {
        let side = min(rect.width, rect.height)
        adjusted = CGRect(
          x: rect.midX - side / 2, y: rect.midY - side / 2,
          width: side, height: side)
      } else if rect.width < rect.height {
        let delta = (1 - eccentricity) * (rect.height - rect.width) / 2
        adjusted = rect.insetBy(dx: 0, dy: delta)
      } else {
        let delta = (1 - eccentricity) * (rect.width - rect.height) / 2
        adjusted = rect.insetBy(dx: delta, dy: 0)
      }
      return Path(ellipseIn: adjusted)
    case .stadium:
      return RoundedRectangle(cornerRadius: min(rect.width, rect.height) / 2).path(in: rect)
    case .beveledRectangle:
      let scale = cornerScale(in: rect)
      let tl = radii.topLeft * scale
      let tr = radii.topRight * scale
      let bl = radii.bottomLeft * scale
      let br = radii.bottomRight * scale
      var path = Path()
      path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + tr))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
      path.addLine(to: CGPoint(x: rect.maxX - br, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bl))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
      path.closeSubpath()
      return path
    case .continuousRectangle:
      // Flutter's continuous corner has a softer cubic transition than a
      // rounded rectangle. SwiftUI's continuous corner style is its native
      // equivalent on Apple platforms.
      if radii.topLeft == radii.topRight,
        radii.topLeft == radii.bottomLeft,
        radii.topLeft == radii.bottomRight
      {
        return RoundedRectangle(cornerRadius: radii.topLeft, style: .continuous).path(in: rect)
      }
      return RufletRoundedRectangle(radii: radii).path(in: rect)
    case .roundedRectangle:
      return RufletRoundedRectangle(radii: radii).path(in: rect)
    }
  }

  private func cornerScale(in rect: CGRect) -> CGFloat {
    func ratio(_ extent: CGFloat, _ sum: CGFloat) -> CGFloat {
      sum > 0 ? extent / sum : 1
    }
    return min(
      1,
      ratio(rect.width, radii.topLeft + radii.topRight),
      ratio(rect.width, radii.bottomLeft + radii.bottomRight),
      ratio(rect.height, radii.topLeft + radii.bottomLeft),
      ratio(rect.height, radii.topRight + radii.bottomRight))
  }
}

private struct CardClip: ViewModifier {
  let metrics: RufletCardMetrics

  @ViewBuilder
  func body(content: Content) -> some View {
    if metrics.clipBehavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(
        RufletCardShape(
          kind: metrics.shapeKind, radii: metrics.radii,
          eccentricity: metrics.eccentricity))
    }
  }
}

private struct CardBorderLayer: View {
  let shape: RufletCardShape
  let color: Color
  let width: CGFloat
  let strokeAlign: CGFloat

  @ViewBuilder
  var body: some View {
    if strokeAlign <= -1 {
      // BorderSide.strokeAlignInside is Flet's parser default. Doubling a
      // centred SwiftUI stroke then clipping its outer half retains the full
      // requested width on the inside, matching Flutter's stroke inset.
      shape.stroke(color, lineWidth: width * 2).clipShape(shape)
    } else {
      shape.stroke(color, lineWidth: width)
    }
  }
}

/// `Card` — the Flet contract realized with native Apple presentation.
struct CardControlView: View {
  let node: ControlNode

  @ViewBuilder
  var body: some View {
    let metrics = RufletCardMetrics(node: node)
    if metrics.requiresCustomAppearance {
      customCard(metrics)
    } else {
      GroupBox { cardContent }
        .padding(metrics.margin)
        .modifier(NativeCardClip(enabled: metrics.clipBehavior.lowercased() != "none"))
        .accessibilityElement(children: metrics.semanticContainer ? .combine : .contain)
    }
  }

  private func customCard(_ metrics: RufletCardMetrics) -> some View {
    let shape = RufletCardShape(
      kind: metrics.shapeKind, radii: metrics.radii,
      eccentricity: metrics.eccentricity)
    let outline = MaterialPalette.color(metrics.outlineToken, default: .clear)

    return ZStack {
      shape
        .fill(MaterialPalette.color(metrics.fillToken, default: .clear))
        .shadow(
          color: MaterialPalette.color(metrics.shadowToken, default: .black).opacity(0.2),
          radius: metrics.elevation)
      if metrics.outlineWidth > 0, !metrics.showBorderOnForeground {
        CardBorderLayer(
          shape: shape, color: outline, width: metrics.outlineWidth,
          strokeAlign: metrics.outlineStrokeAlign)
      }
      Group {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        }
      }
      .modifier(CardClip(metrics: metrics))
      if metrics.outlineWidth > 0, metrics.showBorderOnForeground {
        CardBorderLayer(
          shape: shape, color: outline, width: metrics.outlineWidth,
          strokeAlign: metrics.outlineStrokeAlign)
      }
    }
    // Card.margin belongs to the Material widget itself. LayoutControl then
    // applies the shared margin wrapper too unless Ruby marks it skipped,
    // exactly mirroring the Flet control tree rather than painting the margin
    // inside the card's fill.
    .padding(metrics.margin)
    // Flutter's `semanticContainer` decides whether the card is one element
    // to a screen reader or a group of them.
    .accessibilityElement(children: metrics.semanticContainer ? .combine : .contain)
  }

  @ViewBuilder
  private var cardContent: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    }
  }
}

private struct NativeCardClip: ViewModifier {
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled { content.clipped() } else { content }
  }
}

/// `SafeArea` — insets its content past the notch and home indicator.
struct SafeAreaControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  @ViewBuilder
  var body: some View {
    let contentID = node.controlID(forKey: "content")
    if RufletRequiredContent.validationError(
      contentID: contentID, content: contentID.flatMap(store.node),
      message: SafeAreaInsetMath.missingContentError) == nil,
      let contentID
    {
      safeArea(contentID: contentID)
    } else {
      RufletContainerError(SafeAreaInsetMath.missingContentError)
    }
  }

  private func safeArea(contentID: Int) -> some View {
    GeometryReader { geometry in
      let padding = SafeAreaInsetMath.resolved(
        safeArea: geometry.safeAreaInsets,
        minimum: ControlProps.edgeInsets(node.props["minimum_padding"]) ?? EdgeInsets(),
        left: node.rufletBool("avoid_intrusions_left"),
        top: node.rufletBool("avoid_intrusions_top"),
        right: node.rufletBool("avoid_intrusions_right"),
        bottom: node.rufletBool("avoid_intrusions_bottom"))
      ControlView(id: contentID, axis: .none)
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    // Flutter's SafeArea occupies the full incoming box and consumes the
    // selected MediaQuery padding itself. Do the same rather than stacking
    // SwiftUI's implicit safe area and `minimum` additively.
    .ignoresSafeArea(.container)
    // `maintain_bottom_view_padding` keeps the bottom inset while the
    // keyboard is up rather than letting it collapse.
    .modifier(
      MaintainBottomInset(enabled: node.rufletBool("maintain_bottom_view_padding")))
  }
}

enum SafeAreaInsetMath {
  static let missingContentError = "SafeArea.content must be provided and visible"

  static func resolved(
    safeArea: EdgeInsets, minimum: EdgeInsets,
    left: Bool, top: Bool, right: Bool, bottom: Bool
  ) -> EdgeInsets {
    EdgeInsets(
      top: max(top ? safeArea.top : 0, minimum.top),
      leading: max(left ? safeArea.leading : 0, minimum.leading),
      bottom: max(bottom ? safeArea.bottom : 0, minimum.bottom),
      trailing: max(right ? safeArea.trailing : 0, minimum.trailing))
  }
}

/// `Divider` / `VerticalDivider`.
struct DividerControlView: View {
  let node: ControlNode
  let isVertical: Bool
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    let metrics = DividerGeometry.metrics(
      node: node, isVertical: isVertical, displayScale: displayScale)
    let color = MaterialPalette.color(metrics.colorToken, default: .clear)

    DividerLine(color: color, radii: ControlProps.cornerRadii(node.props["radius"]))
      .frame(
        width: isVertical ? metrics.thickness : nil,
        height: isVertical ? nil : metrics.thickness
      )
      .padding(isVertical ? .top : .leading, metrics.leadingIndent)
      .padding(isVertical ? .bottom : .trailing, metrics.trailingIndent)
      .frame(
        width: isVertical ? metrics.extent : nil,
        height: isVertical ? nil : metrics.extent)
  }
}

enum DividerGeometry {
  struct Metrics: Equatable {
    let extent: CGFloat
    let thickness: CGFloat
    let leadingIndent: CGFloat
    let trailingIndent: CGFloat
    let colorToken: String
  }

  /// Flutter 3.38.7's Material-3 divider defaults: 16 logical points of
  /// space, a 1-point line, zero indents and colorScheme.outlineVariant.
  /// An *explicit* zero thickness remains a one-device-pixel hairline.
  static func metrics(
    node: ControlNode, isVertical: Bool, displayScale: CGFloat
  ) -> Metrics {
    Metrics(
      extent: nonNegative(node.double(isVertical ? "width" : "height")) ?? 16,
      thickness: thickness(node.double("thickness"), displayScale: displayScale),
      leadingIndent: nonNegative(node.double("leading_indent")) ?? 0,
      trailingIndent: nonNegative(node.double("trailing_indent")) ?? 0,
      colorToken: node.string("color") ?? "outlinevariant")
  }

  static func thickness(_ requested: Double?, displayScale: CGFloat) -> CGFloat {
    guard let requested else { return 1 }
    assert(requested >= 0, "Divider thickness must be non-negative")
    if requested == 0 { return 1 / max(displayScale, 1) }
    return CGFloat(requested)
  }

  private static func nonNegative(_ requested: Double?) -> CGFloat? {
    guard let requested else { return nil }
    assert(requested >= 0, "Divider dimensions and indents must be non-negative")
    return CGFloat(requested)
  }
}

private struct DividerLine: View {
  let color: Color
  let radii: RufletCornerRadii?

  @ViewBuilder var body: some View {
    if let radii {
      RufletRoundedRectangle(radii: radii).fill(color)
    } else {
      Rectangle().fill(color)
    }
  }
}

/// `Placeholder` — a marked-out box for layout work in progress.
struct PlaceholderControlView: View {
  let node: ControlNode

  var body: some View {
    let metrics = PlaceholderGeometry.metrics(node)
    let color = MaterialPalette.color(metrics.colorToken, default: .clear)
    ZStack {
      PlaceholderMark(color: color, strokeWidth: metrics.strokeWidth)
        // Flutter's CustomPainter returns false from hitTest; the mark must
        // never steal gestures from the optional child.
        .allowsHitTesting(false)
      // Flutter's Placeholder can hold a child, and falls back to its own
      // size only where the layout leaves it unconstrained.
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .frame(
      idealWidth: metrics.fallbackWidth,
      idealHeight: metrics.fallbackHeight)
  }
}

enum PlaceholderGeometry {
  struct Metrics: Equatable {
    let fallbackWidth: CGFloat
    let fallbackHeight: CGFloat
    let strokeWidth: CGFloat
    let colorToken: String
  }

  static func metrics(_ node: ControlNode) -> Metrics {
    Metrics(
      fallbackWidth: CGFloat(node.rufletDouble("fallback_width")),
      fallbackHeight: CGFloat(node.rufletDouble("fallback_height")),
      strokeWidth: CGFloat(node.rufletDouble("stroke_width")),
      colorToken: node.string("color") ?? "#ff455a64")
  }
}

private struct PlaceholderMark: View {
  let color: Color
  let strokeWidth: CGFloat

  var body: some View {
    Canvas { context, size in
      var path = Path()
      path.addRect(CGRect(origin: .zero, size: size))
      path.move(to: CGPoint(x: size.width, y: 0))
      path.addLine(to: CGPoint(x: 0, y: size.height))
      path.move(to: .zero)
      path.addLine(to: CGPoint(x: size.width, y: size.height))
      context.stroke(path, with: .color(color), lineWidth: strokeWidth)
    }
  }
}

private struct RufletContainerError: View {
  let message: String
  init(_ message: String) { self.message = message }
  var body: some View {
    Text(message).font(.caption).foregroundStyle(.red)
  }
}

/// `RotatedBox` — quarter turns, as Flutter counts them.
struct RotatedBoxControlView: View {
  let node: ControlNode

  var body: some View {
    let turns = RotatedQuarterTurnMath.quarterTurns(node)
    if #available(iOS 16.0, macOS 13.0, *) {
      RotatedQuarterTurnLayout(quarterTurns: turns) {
        Group {
          if let contentID = node.controlID(forKey: "content") {
            ControlView(id: contentID, axis: .none)
          }
        }
        .rotationEffect(.degrees(Double(turns) * 90))
      }
    } else {
      Group {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        }
      }
      .rotationEffect(.degrees(Double(turns) * 90))
    }
  }
}

enum RotatedQuarterTurnMath {
  static func quarterTurns(_ node: ControlNode) -> Int { node.int("quarter_turns") ?? 0 }
  static func normalized(_ turns: Int) -> Int { ((turns % 4) + 4) % 4 }
  static func swapsAxes(_ turns: Int) -> Bool { normalized(turns) % 2 == 1 }
  static func outputSize(_ child: CGSize, quarterTurns: Int) -> CGSize {
    swapsAxes(quarterTurns) ? CGSize(width: child.height, height: child.width) : child
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RotatedQuarterTurnLayout: Layout {
  let quarterTurns: Int
  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let childProposal =
      RotatedQuarterTurnMath.swapsAxes(quarterTurns)
      ? ProposedViewSize(width: proposal.height, height: proposal.width) : proposal
    return RotatedQuarterTurnMath.outputSize(
      child.sizeThatFits(childProposal), quarterTurns: quarterTurns)
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize,
    subviews: Subviews, cache: inout Void
  ) {
    guard let child = subviews.first else { return }
    let childSize =
      RotatedQuarterTurnMath.swapsAxes(quarterTurns)
      ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
    child.place(
      at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
      proposal: ProposedViewSize(width: childSize.width, height: childSize.height))
  }
}

/// `Pagelet` — a screen-in-a-screen with its own bars.
struct PageletControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @StateObject private var scaffoldHost = RufletScaffoldHostState()

  @ViewBuilder
  var body: some View {
    let presentation = PageletPresentation(node: node)
    if let contentID = presentation.contentID,
      presentation.validationError(content: store.node(contentID)) == nil
    {
      pagelet(contentID: contentID)
    } else {
      Text(PageletPresentation.missingContentError)
        .font(.caption).foregroundStyle(.red)
    }
  }

  private func pagelet(contentID: Int) -> some View {
    VStack(spacing: 0) {
      if let appBarID = node.controlID(forKey: "appbar") {
        ControlView(id: appBarID, axis: .none)
      }
      ControlView(id: contentID, axis: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      if let navigationID = node.controlID(forKey: "navigation_bar") {
        ControlView(id: navigationID, axis: .none)
      } else if let bottomBarID = node.controlID(forKey: "bottom_appbar") {
        ControlView(id: bottomBarID, axis: .none)
          .background(
            GeometryReader { proxy in
              Color.clear.preference(
                key: BottomBarFramePreferenceKey.self,
                value: proxy.frame(in: .named(scaffoldCoordinateSpace)))
            })
      }
    }
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(floatingActionButton, alignment: fabAlignment)
    .coordinateSpace(name: scaffoldCoordinateSpace)
    .onPreferenceChange(BottomBarFramePreferenceKey.self) {
      scaffoldHost.reportBottomBar(frame: $0)
    }
    .onPreferenceChange(FABFramePreferenceKey.self) {
      scaffoldHost.reportFAB(frame: $0)
    }
    .environment(\.rufletScaffoldHost, scaffoldHost)
    .environment(\.rufletScaffoldSlots, scaffoldSlots)
    .modifier(DrawerPresenter(node: node))
    // A Pagelet's persistent bottom sheet is distinct from its modal drawers.
    .overlay(alignment: .bottom) { drawer(forKey: "bottom_sheet") }
    .rufletCommandHandler(node.id) { call, completion in
      guard PageletPresentation.methods.contains(call.name) else {
        completion(.failure(rufletUnsupported("Pagelet", call)))
        return
      }
      RufletViewCommands.performDrawer(
        call.name, view: node, store: store, events: events)
      completion(.success(.null))
    }
  }

  @ViewBuilder
  private func drawer(forKey key: String) -> some View {
    if let id = node.controlID(forKey: key) {
      ControlView(id: id, axis: .vertical)
    }
  }

  /// Flutter's FloatingActionButtonLocation names a corner and whether the
  /// button is docked into the bar below it.
  private var fabAlignment: Alignment {
    RufletFABPlacement(node.props["floating_action_button_location"]).alignment
  }

  @ViewBuilder
  private var floatingActionButton: some View {
    if let fabID = node.controlID(forKey: "floating_action_button") {
      ControlView(id: fabID, axis: .none)
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: FABFramePreferenceKey.self,
              value: proxy.frame(in: .named(scaffoldCoordinateSpace)))
          })
        .modifier(FABScaffoldPlacement(
          location: node.props["floating_action_button_location"],
          bottomBarHeight: scaffoldHost.bottomBarFrame.height,
          appBarHeight: appBarHeight,
          fabSize: measuredFABSize))
    }
  }

  private var measuredFABSize: CGSize {
    scaffoldHost.fabFrame.isNull ? CGSize(width: 56, height: 56) : scaffoldHost.fabFrame.size
  }

  private var appBarHeight: CGFloat {
    guard let id = node.controlID(forKey: "appbar"), let appBar = store.node(id) else { return 0 }
    if appBar.type == "CupertinoAppBar" {
      return RufletCupertinoAppBarConfiguration(node: appBar).renderedHeight
    }
    return ChromeDefaults.appBar(appBar).toolbarHeight
  }

  private var scaffoldCoordinateSpace: String { "ruflet-pagelet-scaffold-\(node.id)" }

  private var scaffoldSlots: RufletScaffoldSlots {
    RufletScaffoldSlots(
      hasDrawer: node.controlID(forKey: "drawer") != nil,
      hasEndDrawer: node.controlID(forKey: "end_drawer") != nil,
      openDrawer: { setDrawerOpen(key: "drawer") },
      openEndDrawer: { setDrawerOpen(key: "end_drawer") })
  }

  private func setDrawerOpen(key: String) {
    guard let id = node.controlID(forKey: key) else { return }
    events.setLocal(id, "_open", .bool(true))
  }
}

struct PageletPresentation {
  static let missingContentError = "Pagelet.content must be provided and visible"
  static let methods: Set<String> = [
    "close_drawer", "close_end_drawer", "show_drawer", "show_end_drawer",
  ]

  let node: ControlNode
  var contentID: Int? { node.controlID(forKey: "content") }

  /// Flet's `buildWidget("content")` filters both unresolved references and
  /// controls whose common `visible` property is false before Pagelet builds.
  func validationError(content: ControlNode?) -> String? {
    guard contentID != nil, let content, content.bool("visible") != false else {
      return Self.missingContentError
    }
    return nil
  }
}

/// `AnimatedSwitcher` — cross-fades whenever its content changes.
struct AnimatedSwitcherControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @State private var current: AnimatedSwitcherEntry?
  @State private var outgoing: [AnimatedSwitcherEntry] = []
  @State private var removalTasks: [UUID: Task<Void, Never>] = [:]

  private var presentation: AnimatedSwitcherPresentation {
    AnimatedSwitcherPresentation(node: node)
  }

  @ViewBuilder
  var body: some View {
    if let contentID = presentation.contentID,
      let content = store.node(contentID), presentation.validationError(content: content) == nil
    {
      ZStack {
        ForEach(outgoing) { entry in
          switcherContent(entry)
            .transition(.identity)
        }
        if let current {
          switcherContent(current)
            .transition(.identity)
        } else {
          // Flutter's AnimatedSwitcher paints its first child immediately;
          // `onAppear` is too late to be the first visible frame in SwiftUI.
          ControlView(id: contentID, axis: .none)
            .id(contentIdentity)
        }
      }
      .clipped()
      .onAppear { install(contentID: contentID, animated: false) }
      .onChange(of: contentIdentity) { _ in
        install(contentID: contentID, animated: true)
      }
      .onDisappear {
        removalTasks.values.forEach { $0.cancel() }
        removalTasks.removeAll()
        current = nil
        outgoing.removeAll()
      }
    } else {
      Text(AnimatedSwitcherPresentation.missingContentError)
        .font(.caption)
        .foregroundStyle(.red)
    }
  }

  private func install(contentID: Int, animated: Bool) {
    let next = AnimatedSwitcherEntry(
      controlID: contentID, identity: contentIdentity)
    guard current?.identity != next.identity else { return }
    if let previous = current {
      outgoing.append(previous)
      scheduleRemoval(previous)
    }
    current = next
    guard animated else { return }
    current?.progress = 0
    withAnimation(presentation.inAnimation) { current?.progress = 1 }
    for index in outgoing.indices where outgoing[index].identity != next.identity {
      withAnimation(presentation.outAnimation) { outgoing[index].progress = 0 }
    }
  }

  private var contentIdentity: AnimatedSwitcherIdentity {
    let contentID = presentation.contentID
    return AnimatedSwitcherIdentity(
      controlID: contentID,
      revision: contentID.flatMap {
        store.node($0)?.internals["_flet_animated_switcher_revision"]?.intValue
      } ?? 0)
  }

  private func scheduleRemoval(_ entry: AnimatedSwitcherEntry) {
    removalTasks[entry.id]?.cancel()
    removalTasks[entry.id] = Task { @MainActor in
      let nanos = UInt64(max(0, presentation.effectiveReverseDuration) * 1_000_000_000)
      try? await Task.sleep(nanoseconds: nanos)
      guard !Task.isCancelled else { return }
      outgoing.removeAll { $0.id == entry.id }
      removalTasks[entry.id] = nil
    }
  }

  @ViewBuilder
  private func switcherContent(_ entry: AnimatedSwitcherEntry) -> some View {
    ControlView(id: entry.controlID, axis: .none)
      .id(entry.identity)
      .opacity(presentation.transition == "fade" ? entry.progress : 1)
      .scaleEffect(presentation.transition == "scale" ? entry.progress : 1)
      .rotationEffect(.degrees(
        presentation.transition == "rotation" ? Double(entry.progress) * 360 : 0))
  }
}

struct AnimatedSwitcherPresentation {
  static let missingContentError = "AnimatedSwitcher.content must be provided and visible"

  let node: ControlNode
  var contentID: Int? { node.controlID(forKey: "content") }
  /// Legacy inspection surface retained for existing package callers. Native
  /// rendering uses `effectiveDuration`, which is pinned to Dart parseDuration.
  var duration: Double { Self.durationSeconds(node.props["duration"], default: 1) }
  var reverseDuration: Double {
    Self.durationSeconds(node.props["reverse_duration"], default: 1)
  }
  var effectiveDuration: Double {
    Self.fletDurationSeconds(node.props["duration"], default: 1)
  }
  var effectiveReverseDuration: Double {
    Self.fletDurationSeconds(node.props["reverse_duration"], default: 1)
  }
  var switchInCurve: String { Self.fletCurve(node.string("switch_in_curve")) }
  var switchOutCurve: String { Self.fletCurve(node.string("switch_out_curve")) }
  var transition: String {
    switch node.string("transition")?.lowercased() {
    case "rotation": return "rotation"
    case "scale": return "scale"
    default: return "fade"
    }
  }
  var inAnimation: Animation {
    RufletCurve.animation(switchInCurve, duration: effectiveDuration)
  }
  var outAnimation: Animation {
    RufletCurve.animation(switchOutCurve, duration: effectiveReverseDuration)
  }

  func validationError(content: ControlNode?) -> String? {
    guard contentID != nil, let content, content.bool("visible") != false else {
      return Self.missingContentError
    }
    return nil
  }

  /// Flet's `parseCurve(value, Curves.linear)` falls back to linear for both
  /// omitted and unknown tokens rather than SwiftUI's general ease-in-out
  /// fallback.
  static func fletCurve(_ value: String?) -> String {
    guard let value, RufletCurve.names.contains(value.lowercased()) else {
      return "linear"
    }
    return value
  }

  /// Exact `parseDuration` behavior used by the renderer. Dart's `parseInt`
  /// accepts ints and integer strings; fractional doubles/components become
  /// zero instead of being truncated.
  static func fletDurationSeconds(
    _ value: RufletValue?,
    default defaultValue: Double
  ) -> Double {
    guard let value, !value.isNull else { return defaultValue }
    if case .int(let milliseconds) = value { return Double(milliseconds) / 1_000 }
    if case .string(let raw) = value { return Double(Int64(raw) ?? 0) / 1_000 }
    if case .extended(type: 3, let microseconds) = value {
      return Double(Int64(microseconds) ?? 0) / 1_000_000
    }
    guard let map = value.mapValue else { return 0 }
    func integer(_ key: String) -> Int64 {
      switch map[key] {
      case .int(let value): return value
      case .string(let value): return Int64(value) ?? 0
      default: return 0
      }
    }
    let microseconds = integer("microseconds")
      + 1_000 * integer("milliseconds")
      + 1_000_000 * integer("seconds")
      + 60_000_000 * integer("minutes")
      + 3_600_000_000 * integer("hours")
      + 86_400_000_000 * integer("days")
    return Double(microseconds) / 1_000_000
  }

  /// Compatibility accessor retained for broad presentation tests. Renderer
  /// behavior uses `fletDurationSeconds`, matching pinned Dart exactly.
  static func durationSeconds(_ value: RufletValue?, default defaultValue: Double) -> Double {
    guard let value, !value.isNull else { return defaultValue }
    if case .int(let milliseconds) = value { return Double(milliseconds) / 1_000 }
    if case .double(let milliseconds) = value { return Double(Int(milliseconds)) / 1_000 }
    if case .string(let raw) = value { return Double(Int(raw) ?? 0) / 1_000 }
    if case .extended(type: 3, let microseconds) = value {
      return Double(Int64(microseconds) ?? 0) / 1_000_000
    }
    guard let map = value.mapValue else { return 0 }
    func integer(_ key: String) -> Int {
      switch map[key] {
      case .int(let value): return Int(value)
      case .double(let value): return Int(value)
      case .string(let value): return Int(value) ?? 0
      default: return 0
      }
    }
    let microseconds = integer("microseconds")
      + 1_000 * integer("milliseconds")
      + 1_000_000 * integer("seconds")
      + 60_000_000 * integer("minutes")
      + 3_600_000_000 * integer("hours")
      + 86_400_000_000 * integer("days")
    return Double(microseconds) / 1_000_000
  }
}

struct AnimatedSwitcherIdentity: Hashable {
  let controlID: Int?
  let revision: Int
}

private struct AnimatedSwitcherEntry: Identifiable {
  let id = UUID()
  let controlID: Int
  let identity: AnimatedSwitcherIdentity
  var progress: CGFloat = 1
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

/// Flet's three Flutter gradient constructors represented without renderer
/// policy. Storing wire-level tokens makes omitted/default semantics directly
/// testable and defers theme colour resolution until SwiftUI paints.
enum RufletGradientSpec: Equatable {
  case linear(
    colors: [String], stops: [Double]?, begin: RufletAlignment, end: RufletAlignment,
    tileMode: String, rotation: Double?)
  case radial(
    colors: [String], stops: [Double]?, center: RufletAlignment, radius: Double,
    focal: RufletAlignment?, focalRadius: Double, tileMode: String, rotation: Double?)
  case sweep(
    colors: [String], stops: [Double]?, center: RufletAlignment,
    startAngle: Double, endAngle: Double, tileMode: String, rotation: Double?)

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return nil }
    let colors = map["colors"]?.arrayValue?.compactMap(\.stringValue) ?? []
    guard colors.count >= 2 else { return nil }
    let stops = map["stops"]?.arrayValue?.compactMap(\.doubleValue)
    let rotation = map["rotation"]?.doubleValue
    let tileMode = map["tile_mode"]?.stringValue?.lowercased() ?? "clamp"
    switch map["_type"]?.stringValue?.lowercased() {
    case "linear":
      self = .linear(
        colors: colors, stops: stops,
        begin: ControlProps.continuousAlignment(map["begin"]) ?? .centerLeft,
        end: ControlProps.continuousAlignment(map["end"]) ?? .centerRight,
        tileMode: tileMode, rotation: rotation)
    case "radial":
      self = .radial(
        colors: colors, stops: stops,
        center: ControlProps.continuousAlignment(map["center"]) ?? .center,
        radius: map["radius"]?.doubleValue ?? 0.5,
        focal: ControlProps.continuousAlignment(map["focal"]),
        focalRadius: map["focal_radius"]?.doubleValue ?? 0,
        tileMode: tileMode, rotation: rotation)
    case "sweep":
      self = .sweep(
        colors: colors, stops: stops,
        center: ControlProps.continuousAlignment(map["center"]) ?? .center,
        startAngle: map["start_angle"]?.doubleValue ?? 0,
        endAngle: map["end_angle"]?.doubleValue ?? 0,
        tileMode: tileMode, rotation: rotation)
    default:
      return nil
    }
  }

  func shapeStyle(size: CGSize) -> AnyShapeStyle {
    switch self {
    case .linear(let colors, let stops, let begin, let end, _, _):
      return AnyShapeStyle(LinearGradient(
        gradient: gradient(colors: colors, stops: stops),
        startPoint: unitPoint(begin),
        endPoint: unitPoint(end)))
    case .radial(let colors, let stops, let center, let radius, _, _, _, _):
      return AnyShapeStyle(RadialGradient(
        gradient: gradient(colors: colors, stops: stops),
        center: unitPoint(center),
        startRadius: 0, endRadius: CGFloat(max(radius, 0)) * min(size.width, size.height)))
    case .sweep(let colors, let stops, let center, let start, let end, _, _):
      return AnyShapeStyle(AngularGradient(
        gradient: gradient(colors: colors, stops: stops),
        center: unitPoint(center),
        startAngle: .radians(start), endAngle: .radians(end)))
    }
  }

  private func gradient(colors: [String], stops: [Double]?) -> Gradient {
    let resolved = colors.map { MaterialPalette.color($0, default: .clear) }
    guard let stops, stops.count == resolved.count else { return Gradient(colors: resolved) }
    return Gradient(stops: zip(resolved, stops).map {
      Gradient.Stop(color: $0.0, location: $0.1)
    })
  }

  private func unitPoint(_ alignment: RufletAlignment) -> UnitPoint {
    let point = RufletGeometry.unitPoint(alignment: alignment)
    return UnitPoint(x: point.x, y: point.y)
  }
}

/// Compatibility entry point for controls that only accept a linear gradient.
public enum GradientProps {
  public static func linear(_ value: RufletValue?) -> LinearGradient? {
    guard case .linear(let tokens, let stops, let beginAlignment, let endAlignment, _, _)? =
      RufletGradientSpec(value)
    else { return nil }
    let colors = tokens.map { MaterialPalette.color($0, default: .clear) }
    let gradient: Gradient
    if let stops, stops.count == colors.count {
      gradient = Gradient(stops: zip(colors, stops).map {
        Gradient.Stop(color: $0.0, location: $0.1)
      })
    } else {
      gradient = Gradient(colors: colors)
    }
    let begin = RufletGeometry.unitPoint(alignment: beginAlignment)
    let end = RufletGeometry.unitPoint(alignment: endAlignment)
    return LinearGradient(
      gradient: gradient,
      startPoint: UnitPoint(x: begin.x, y: begin.y),
      endPoint: UnitPoint(x: end.x, y: end.y))
  }
}
