import RufletProtocol
import SwiftUI

/// Local acknowledgement state while a native pop waits for the Ruby tree.
///
/// Wire control IDs identify the exact View occurrence. Routes cannot do that:
/// a valid stack may contain the same route more than once, and filtering by a
/// route string would remove every occurrence while waiting for Ruby's patch.
struct RufletPagePopState: Equatable {
  private(set) var pendingViewIDs: Set<Int> = []
  private(set) var sentViewIDs: Set<Int> = []

  func isPending(viewID: Int) -> Bool {
    pendingViewIDs.contains(viewID)
  }

  mutating func mark(viewID: Int) -> Bool {
    pendingViewIDs.insert(viewID)
    return sentViewIDs.insert(viewID).inserted
  }

  mutating func reconcile(publishedViewIDs: Set<Int>) {
    pendingViewIDs.formIntersection(publishedViewIDs)
    sentViewIDs.formIntersection(publishedViewIDs)
  }
}

/// Apple-native port of Flet's `PageControl`.
@MainActor
public struct PageControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.locale) private var environmentLocale
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.rufletThemeMode) private var inheritedThemeMode
  @State private var invokeToken: UUID?
  @State private var controlListener: UUID?
  @State private var overlayListener: UUID?
  @State private var dialogsListener: UUID?
  @State private var topLayersRevision = 0
  @State private var popState = RufletPagePopState()
  @State private var previousLocales: [String] = []
  @State private var loadedFontSources: Set<String> = []
  @State private var physicalSafeAreaInsets: RufletSafeAreaInsets

  public init(control: RufletControl) {
    self.control = control
    _physicalSafeAreaInsets = State(initialValue: rufletCurrentWindowSafeAreaInsets())
  }

  public var body: some View {
    RufletPageLifecycleMonitor(onTransition: lifecycleTransition) {
      PageContext(themeMode: themeMode, theme: activePageTheme, design: pageDesign) {
        GeometryReader { proxy in
          pageStack
            .environment(\.rufletSafeAreaInsets, physicalSafeAreaInsets)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
              ZStack {
                RufletPagePlatformBridge(
                  control: control,
                  title: control.string("title", default: "")!)
                RufletWindowSafeAreaProbe { insets in
                  if physicalSafeAreaInsets != insets { physicalSafeAreaInsets = insets }
                }
                .frame(width: 0, height: 0)
              }
            }
            .overlay(alignment: .topLeading) {
              RufletPageKeyboardMonitor(
                enabled: control.boolean("on_keyboard_event", default: false),
                onEvent: keyboardEvent,
                onBack: popTopViewIfAllowed)
            }
            .onAppear { pageSizeChanged(proxy.size) }
            .onChange(of: proxy.size, perform: pageSizeChanged)
        }
        // Measure the full viewport here, before passing its physical insets
        // to the Flet scaffold. Ignoring the safe area on a descendant makes
        // GeometryProxy.safeAreaInsets collapse to zero, which puts native
        // bar content under the Dynamic Island and home indicator.
        .ignoresSafeArea(.container)
      }
      .environment(\.locale, localeConfiguration.locale ?? environmentLocale)
      .environment(
        \.layoutDirection, control.boolean("rtl", default: false) ? .rightToLeft : .leftToRight
      )
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.revision) { _ in controlUpdated() }
    .onChange(of: colorScheme) { scheme in
      backend.updateBrightness(scheme == .dark ? "dark" : "light")
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
    ) { _ in
      localeChanged()
    }
    .overlay(alignment: .topTrailing) {
      if control.boolean("show_semantics_debugger", default: false) {
        RufletPageSemanticsDebugger(page: control)
      }
    }
  }

  @ViewBuilder
  private var pageStack: some View {
    let views = effectiveViews
    ZStack {
      if views.isEmpty {
        Color.clear
      } else {
        RufletPageNavigator(
          page: control,
          views: views,
          locale: localeConfiguration.locale ?? environmentLocale,
          layoutDirection: control.boolean("rtl", default: false) ? .rightToLeft : .leftToRight,
          themeMode: themeMode,
          theme: activePageTheme,
          design: pageDesign,
          tint: pageTint,
          onRequestPop: markPoppedView,
          onDidRemove: markPoppedView)
      }

      if let overlay = control.child("_overlay", visibleOnly: false),
        let dialogs = control.child("_dialogs", visibleOnly: false)
      {
        RufletPageTopLayers(
          page: control,
          overlay: overlay,
          dialogs: dialogs,
          revision: topLayersRevision)
      } else {
        RufletPageMedia(control: control)
      }
    }
  }

  private var effectiveViews: [RufletControl] {
    control.children("views").filter { !popState.isPending(viewID: $0.id) }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    synchronizeThemeCache()
    invokeToken = control.addInvokeMethodListener { name, arguments in
      try await invoke(name, arguments: arguments)
    }
    controlListener = control.addListener { controlUpdated() }
    if let overlay = control.child("_overlay", visibleOnly: false) {
      overlayListener = overlay.addListener { topLayersRevision &+= 1 }
    }
    if let dialogs = control.child("_dialogs", visibleOnly: false) {
      dialogsListener = dialogs.addListener { topLayersRevision &+= 1 }
    }
    RufletPagePopRegistry.register(page: control) { view in requestPop(view) }
    localeChanged()
    Task { await loadFontsIfNeeded() }
  }

  private func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    if let controlListener { control.removeListener(controlListener) }
    if let overlayListener,
      let overlay = control.child("_overlay", visibleOnly: false)
    {
      overlay.removeListener(overlayListener)
    }
    if let dialogsListener,
      let dialogs = control.child("_dialogs", visibleOnly: false)
    {
      dialogs.removeListener(dialogsListener)
    }
    invokeToken = nil
    controlListener = nil
    overlayListener = nil
    dialogsListener = nil
    RufletPageCaptureRegistry.unregister(backend: control.backend)
    RufletPagePopRegistry.unregister(page: control)
  }

  private func controlUpdated() {
    synchronizeThemeCache()
    popState.reconcile(publishedViewIDs: Set(control.children("views").map(\.id)))
    Task { await loadFontsIfNeeded() }
  }

  private func pageSizeChanged(_ size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    backend.updatePageSize(size)
  }

  private func lifecycleTransition(_ state: String) {
    RufletPageEventContract.appLifecycleChanged(control, state: state)
  }

  private func localeChanged() {
    let identifiers = Locale.preferredLanguages
    guard identifiers != previousLocales else { return }
    previousLocales = identifiers
    let locales: [RufletValue] = identifiers.map { identifier in
      let locale = Locale(identifier: identifier)
      return .map(
        locale.rufletMap.mapValues { value in
          value.map(RufletValue.string) ?? .null
        })
    }
    control.triggerEvent("locale_change", data: ["locales": .array(locales)])
  }

  private func keyboardEvent(_ event: RufletKeyboardEvent) {
    control.triggerEventWithoutSubscribers("keyboard_event", data: event.value)
  }

  private func popTopViewIfAllowed() {
    let views = effectiveViews
    guard let top = views.last else { return }
    requestPop(top)
  }

  private func requestPop(_ top: RufletControl) {
    let views = effectiveViews
    guard views.last?.id == top.id else { return }
    if top.boolean("can_pop", default: true) {
      completePop(top, viewCount: views.count)
    } else if top.boolean("on_confirm_pop", default: false) {
      Task {
        if await RufletViewPopRegistry.confirmPop(control: top) {
          completePop(top, viewCount: views.count)
        }
      }
    }
  }

  private func completePop(_ view: RufletControl, viewCount: Int) {
    if viewCount <= 1 {
      rufletCloseNativeScene()
    } else {
      markPoppedView(view)
    }
  }

  private func markPoppedView(_ view: RufletControl) {
    let views = effectiveViews
    guard views.count > 1, views.last?.id == view.id else { return }
    markPopped(view)
  }

  private func markPopped(_ view: RufletControl) {
    if popState.mark(viewID: view.id) {
      control.triggerEventWithoutSubscribers(
        "view_pop", data: ["route": .string(route(of: view))])
    }
  }

  private func route(of view: RufletControl) -> String {
    view.string("route", default: String(view.id))!
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    let values = arguments.map ?? [:]
    switch name {
    case "take_screenshot":
      guard control.boolean("enable_screenshots", default: false) else { return .null }
      let delay = parseDuration(values["delay"].map(rufletAny), 0.02)!
      if delay > 0 {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      let ratio = CGFloat(values["pixel_ratio"]?.number ?? defaultApplePixelRatio())
      return RufletPageCaptureRegistry.capture(
        backend: control.backend,
        pixelRatio: max(ratio, 0.1)
      ).map(RufletValue.binary) ?? .null

    case "push_route":
      if let route = values["route"]?.text { backend.onRouteUpdated(route) }
      return .null

    case "get_device_info":
      return getAppleDeviceInfo()

    case "set_allowed_device_orientations":
      let orientations = values["orientations"]?.array?.compactMap(\.text) ?? []
      try await setAllowedAppleDeviceOrientations(orientations)
      return .null

    default:
      throw RufletPageControlError.unknownMethod(name)
    }
  }

  private func loadFontsIfNeeded() async {
    guard let fonts = control.value("fonts")?.map else { return }
    for sourceValue in fonts.values {
      guard let sourceText = sourceValue.text,
        !loadedFontSources.contains(sourceText),
        let source = control.backend.resolveAssetSource(sourceValue)
      else { continue }
      do {
        try await RufletUserFonts.load(from: source)
        loadedFontSources.insert(sourceText)
      } catch {
        // Pinned Flet treats one failed custom font as isolated from the Page.
      }
    }
  }

  private var backend: RufletBackend {
    guard let backend = control.backend as? RufletBackend else {
      preconditionFailure("PageControl requires RufletBackend")
    }
    return backend
  }

  private var localeConfiguration: LocaleConfiguration {
    parseLocaleConfiguration(control.dynamicValue("locale_configuration"))
  }

  private var themeMode: RufletThemeMode {
    parseEnum(RufletThemeMode.self, control.string("theme_mode"), inheritedThemeMode)!
  }

  private var pageThemes: RufletPageThemes {
    parsePageThemes(
      theme: control.dynamicValue("theme"),
      darkTheme: control.dynamicValue("dark_theme"))
  }

  /// Flet caches its parsed light and dark ThemeData objects in private
  /// control properties. Swift's parsed themes are value types, but retaining
  /// the corresponding source values preserves the same change-detection
  /// contract without sending either private key to the server.
  private func synchronizeThemeCache() {
    let lightTheme = control.value("theme") ?? .null
    let darkTheme = control.value("dark_theme") ?? lightTheme
    var updates: [String: RufletValue] = [:]
    if control.value("_lightTheme") != lightTheme { updates["_lightTheme"] = lightTheme }
    if control.value("_darkTheme") != darkTheme { updates["_darkTheme"] = darkTheme }
    if !updates.isEmpty {
      control.updateProperties(updates, client: true, server: false, notify: false)
    }
  }

  private var activePageTheme: RufletTheme {
    pageThemes.active(themeMode: themeMode, systemColorScheme: colorScheme)
  }

  private var pageTint: Color? {
    activePageTheme.appleAccentColor
  }

  private var pageDesign: RufletPageDesign {
    rufletPageDesign(
      adaptive: control.boolean("adaptive", default: false),
      platform: control.string("platform"),
      defaultPlatform: rufletDefaultTargetPlatform)
  }
}

/// Page overlay and modal ownership sits above the native route navigator,
/// matching Flet's single Overlay stack. Cached hidden route controllers must
/// never mount or consume page dialogs.
@MainActor
private struct RufletPageTopLayers: View {
  @ObservedObject var page: RufletControl
  @ObservedObject var overlay: RufletControl
  @ObservedObject var dialogs: RufletControl
  let revision: Int

  var body: some View {
    let _ = revision
    ZStack {
      ForEach(overlay.children("controls")) { control in
        ControlWidget(control: control)
          .id(ObjectIdentifier(control))
      }
      ForEach(dialogs.children("controls")) { control in
        ControlWidget(control: control)
          // Ruby publishes the dialogs collection as a fresh control snapshot
          // every time `show_dialog` runs. The wire id intentionally stays the
          // same, but the native presenter must be rebound to that new control
          // instance or SwiftUI can retain the previous presentation latch.
          .id(ObjectIdentifier(control))
      }
      RufletPageMedia(control: page)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .zIndex(100)
  }
}

/// Centralizes the Page events which pinned Flet raises from both its Page
/// widget and backend. Keeping the exact subscriber policy here prevents
/// scene, media, and route integrations from drifting apart.
@MainActor
enum RufletPageEventContract {
  static func appLifecycleChanged(_ page: RufletControl, state: String) {
    page.triggerEventWithoutSubscribers(
      "app_lifecycle_state_change",
      data: ["state": .string(state)])
  }

  static func routeChanged(_ page: RufletControl, route: String) {
    page.triggerEventWithoutSubscribers("route_change", data: ["route": .string(route)])
  }

  static func platformBrightnessChanged(_ page: RufletControl, brightness: String) {
    page.triggerEventWithoutSubscribers("platform_brightness_change", data: .string(brightness))
  }

  static func mediaChanged(
    _ pageOrView: RufletControl,
    media: RufletPageMediaData
  ) {
    pageOrView.triggerEvent("media_change", data: media.value)
  }

  static func multiViewAdded(_ page: RufletControl, view: RufletMultiView) {
    page.triggerEventWithoutSubscribers("multi_view_add", data: view.value)
  }

  static func multiViewRemoved(_ page: RufletControl, viewID: Int) {
    page.triggerEventWithoutSubscribers("multi_view_remove", data: .int(Int64(viewID)))
  }

  static func multiViewControls(in page: RufletControl) -> [RufletControl] {
    page.children("multi_views", visibleOnly: false)
  }
}

/// Native counterpart of Flutter's `showSemanticsDebugger` development aid.
/// Apple does not expose its Accessibility Inspector as an embeddable view,
/// so the renderer presents the live control accessibility contract without
/// intercepting application input.
@MainActor
struct RufletPageSemanticsDebugger: View {
  @ObservedObject var page: RufletControl

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 4) {
        Text("Accessibility tree")
          .font(.caption.bold())
        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
          Text(entry)
            .font(.caption2.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(8)
    }
    .frame(width: 300)
    .frame(maxHeight: 320)
    .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
    .foregroundStyle(.white)
    .padding(8)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  var entries: [String] {
    var result: [String] = []
    var visited: Set<ObjectIdentifier> = []

    func append(_ control: RufletControl, depth: Int) {
      guard visited.insert(ObjectIdentifier(control)).inserted else { return }
      let semanticText =
        control.string("semantics_label")
        ?? control.string("label")
        ?? control.string("tooltip")
      let prefix = String(repeating: "  ", count: depth)
      result.append(
        prefix + control.type + "#\(control.id)"
          + (semanticText.map { ": \($0)" } ?? ""))
      for property in control.properties.keys.sorted() {
        for child in control.children(property) {
          append(child, depth: depth + 1)
        }
      }
    }

    append(page, depth: 0)
    return result
  }
}

private enum RufletPageControlError: Error {
  case unknownMethod(String)
}
