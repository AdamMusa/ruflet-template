import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `PageControl`.
@MainActor
public struct PageControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.locale) private var environmentLocale
  @Environment(\.colorScheme) private var colorScheme
  @State private var invokeToken: UUID?
  @State private var controlListener: UUID?
  @State private var pendingPoppedRoutes: Set<String> = []
  @State private var sentPoppedRoutes: Set<String> = []
  @State private var previousLocales: [String] = []
  @State private var loadedFontSources: Set<String> = []

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletPageLifecycleMonitor(onTransition: lifecycleTransition) {
      PageContext(themeMode: themeMode) {
        GeometryReader { proxy in
          pageStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
              RufletPagePlatformBridge(
                control: control,
                title: control.string("title", default: "")!)
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
      }
      .environment(\.locale, localeConfiguration.locale ?? environmentLocale)
      .environment(
        \.layoutDirection, control.boolean("rtl", default: false) ? .rightToLeft : .leftToRight
      )
      .modifier(RufletPageTintModifier(color: pageTint))
    }
    .onAppear(perform: mount)
    .onDisappear(perform: unmount)
    .onChange(of: control.properties) { _ in controlUpdated() }
    .onChange(of: colorScheme) { scheme in
      backend.updateBrightness(scheme == .dark ? "dark" : "light")
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
    ) { _ in
      localeChanged()
    }
  }

  @ViewBuilder
  private var pageStack: some View {
    let views = effectiveViews
    if views.isEmpty {
      ZStack {
        Color.clear
        RufletPageMedia(control: control)
      }
    } else {
      RufletPageNavigator(
        page: control,
        views: views,
        locale: localeConfiguration.locale ?? environmentLocale,
        layoutDirection: control.boolean("rtl", default: false) ? .rightToLeft : .leftToRight,
        themeMode: themeMode,
        tint: pageTint,
        onRequestPop: markPoppedView,
        onDidRemove: markPoppedView)
    }
  }

  private var effectiveViews: [RufletControl] {
    control.children("views").filter { !pendingPoppedRoutes.contains(route(of: $0)) }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, arguments in
      try await invoke(name, arguments: arguments)
    }
    controlListener = control.addListener { controlUpdated() }
    RufletPagePopRegistry.register(page: control) { view in requestPop(view) }
    localeChanged()
    Task { await loadFontsIfNeeded() }
  }

  private func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    if let controlListener { control.removeListener(controlListener) }
    invokeToken = nil
    controlListener = nil
    RufletPageCaptureRegistry.unregister(backend: control.backend)
    RufletPagePopRegistry.unregister(page: control)
  }

  private func controlUpdated() {
    let publishedRoutes = Set(control.children("views").map(route(of:)))
    pendingPoppedRoutes.formIntersection(publishedRoutes)
    sentPoppedRoutes.formIntersection(publishedRoutes)
    Task { await loadFontsIfNeeded() }
  }

  private func pageSizeChanged(_ size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    backend.updatePageSize(size)
  }

  private func lifecycleTransition(_ state: String) {
    control.triggerEventWithoutSubscribers(
      "app_lifecycle_state_change",
      data: ["state": .string(state)])
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
    guard views.last === top else { return }
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
    guard effectiveViews.count > 1 else { return }
    markPopped(route(of: view))
  }

  private func markPopped(_ route: String) {
    pendingPoppedRoutes.insert(route)
    if sentPoppedRoutes.insert(route).inserted {
      control.triggerEventWithoutSubscribers("view_pop", data: ["route": .string(route)])
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
    parseEnum(RufletThemeMode.self, control.string("theme_mode"), .system)!
  }

  private var pageTint: Color? {
    let theme =
      rufletDictionary(control.dynamicValue(colorScheme == .dark ? "dark_theme" : "theme"))
      ?? rufletDictionary(control.dynamicValue("theme"))
    let scheme = rufletDictionary(theme?["color_scheme"])
    return parseColor(scheme?["primary"] as? String)
  }
}

private struct RufletPageTintModifier: ViewModifier {
  let color: Color?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let color { content.tint(color) } else { content }
  }
}

private enum RufletPageControlError: Error {
  case unknownMethod(String)
}
