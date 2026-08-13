import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `ViewControl`.
@MainActor
public struct ViewControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var popState = RufletViewPopState()
  @State private var invokeToken: UUID?
  @State private var overlayToken: UUID?
  @State private var dialogsToken: UUID?
  @State private var slotRevision = 0
  @State private var drawerPresented = false
  @State private var endDrawerPresented = false
  @State private var scrolledUnderAppBar = false
  @State private var bottomBarHeight = 0.0
  @State private var topBarHeight = 0.0
  @Environment(\.rufletTopViewID) private var topViewID
  @Environment(\.rufletPageBackgroundColor) private var pageBackgroundColor

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    decoratedView
      .environment(
        \.layoutDirection, page.boolean("rtl", default: false) ? .rightToLeft : .leftToRight
      )
      .environment(\.rufletViewScrolledUnder, scrolledUnderAppBar)
      .onAppear(perform: mount)
      .onDisappear(perform: unmount)
      .onChange(of: control.properties) { _ in controlUpdated() }
      .onPreferenceChange(RufletViewScrollPositionKey.self) { position in
        scrolledUnderAppBar = position < -0.5
      }
  }

  private var decoratedView: some View {
    scaffold
      .background {
        RufletViewDecoration(value: control.dynamicValue("decoration"))
      }
      .overlay {
        if control.value("foreground_decoration") != nil {
          RufletViewDecoration(value: control.dynamicValue("foreground_decoration"))
            .allowsHitTesting(false)
        }
      }
  }

  private var scaffold: some View {
    ZStack {
      parseColor(control.string("bgcolor")) ?? pageBackgroundColor ?? Color.rufletSystemBackground
      VStack(spacing: 0) {
        if let appBar = control.child("appbar") {
          appBarView(appBar)
            .background {
              GeometryReader { proxy in
                Color.clear.preference(key: RufletTopBarSizeKey.self, value: proxy.size.height)
              }
            }
        }
        content
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: viewAlignment)
          .padding(
            parsePadding(control.dynamicValue("padding"))
              ?? EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        if let bottom = control.child("navigation_bar") ?? control.child("bottom_appbar") {
          ControlWidget(control: bottom)
            .background {
              GeometryReader { proxy in
                Color.clear.preference(key: RufletBottomBarSizeKey.self, value: proxy.size.height)
              }
            }
        }
      }

      if isTopView {
        topViewLayers
      }

      if let floating = control.child("floating_action_button") {
        RufletFloatingActionPlacement(
          location: control.dynamicValue("floating_action_button_location"),
          topBarHeight: topBarHeight,
          bottomBarHeight: bottomBarHeight
        ) {
          ControlWidget(control: floating)
        }
      }

      if shouldShowLoading {
        LoadingPage(
          isLoading: backend.isLoading,
          message: backend.isLoading
            ? backend.appStartupScreenMessage ?? ""
            : backend.formatAppErrorMessage(backend.error)
        )
        .zIndex(40)
      }

      drawerLayers
    }
    .onPreferenceChange(RufletTopBarSizeKey.self) { topBarHeight = $0 }
    .onPreferenceChange(RufletBottomBarSizeKey.self) { bottomBarHeight = $0 }
  }

  @ViewBuilder
  private var content: some View {
    let column = VStack(alignment: horizontalAlignment, spacing: control.number("spacing") ?? 10) {
      ForEach(control.children("controls")) { child in
        ControlWidget(control: child)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: viewAlignment)
    .background {
      GeometryReader { proxy in
        Color.clear.preference(
          key: RufletViewScrollPositionKey.self,
          value: proxy.frame(in: .named("ruflet_view_scroll_\(control.id)")).minY)
      }
    }

    let scrollable = ScrollableControl(
      control: control,
      scrollDirection: .vertical,
      wrapIntoScrollableView: true
    ) { column }
    .coordinateSpace(name: "ruflet_view_scroll_\(control.id)")

    if control.boolean("on_scroll", default: false) {
      ScrollNotificationControl(control: control) { scrollable }
    } else {
      scrollable
    }
  }

  @ViewBuilder
  private func appBarView(_ appBar: RufletControl) -> some View {
    let _ = markAppBarAsParentNotifying(appBar)
    ControlWidget(control: appBar)
  }

  private var topViewLayers: some View {
    ZStack {
      ForEach(page.child("_overlay", visibleOnly: false)?.children("controls") ?? []) { overlay in
        ControlWidget(control: overlay)
      }
      ForEach(page.child("_dialogs", visibleOnly: false)?.children("controls") ?? []) { dialog in
        ControlWidget(control: dialog)
      }
      RufletPageMedia(control: page)
    }
    .id(slotRevision)
    .zIndex(20)
  }

  @ViewBuilder
  private var drawerLayers: some View {
    if let drawer = control.child("drawer"), drawerPresented {
      RufletViewDrawerLayer(edge: .leading) {
        ControlWidget(control: drawer)
      } onDismiss: {
        closeDrawer(drawer, end: false)
      }
      .zIndex(30)
    }
    if let drawer = control.child("end_drawer"), endDrawerPresented {
      RufletViewDrawerLayer(edge: .trailing) {
        ControlWidget(control: drawer)
      } onDismiss: {
        closeDrawer(drawer, end: true)
      }
      .zIndex(31)
    }
  }

  private func mount() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, arguments in
      try await invoke(name, arguments: arguments)
    }
    if let overlay = page.child("_overlay", visibleOnly: false) {
      overlayToken = overlay.addListener { slotRevision &+= 1 }
    }
    if let dialogs = page.child("_dialogs", visibleOnly: false) {
      dialogsToken = dialogs.addListener { slotRevision &+= 1 }
    }
    RufletViewPopRegistry.register(control: control) {
      await popState.request(control: control)
    }
  }

  private func unmount() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    if let overlayToken, let overlay = page.child("_overlay", visibleOnly: false) {
      overlay.removeListener(overlayToken)
    }
    if let dialogsToken, let dialogs = page.child("_dialogs", visibleOnly: false) {
      dialogs.removeListener(dialogsToken)
    }
    invokeToken = nil
    overlayToken = nil
    dialogsToken = nil
    popState.cancel()
    RufletViewPopRegistry.unregister(control: control)
  }

  private func controlUpdated() {
    if control.child("drawer") == nil { drawerPresented = false }
    if control.child("end_drawer") == nil { endDrawerPresented = false }
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    switch name {
    case "show_drawer":
      drawerPresented = control.child("drawer") != nil
    case "close_drawer":
      if let drawer = control.child("drawer"), drawerPresented { closeDrawer(drawer, end: false) }
    case "show_end_drawer":
      endDrawerPresented = control.child("end_drawer") != nil
    case "close_end_drawer":
      if let drawer = control.child("end_drawer"), endDrawerPresented {
        closeDrawer(drawer, end: true)
      }
    case "confirm_pop":
      popState.confirm(arguments.map?["should_pop"]?.bool ?? false)
    default:
      break
    }
    return .null
  }

  private func closeDrawer(_ drawer: RufletControl, end: Bool) {
    if end { endDrawerPresented = false } else { drawerPresented = false }
    control.backend.triggerControlEvent(controlID: drawer.id, name: "dismiss", data: .null)
  }

  private func markAppBarAsParentNotifying(_ appBar: RufletControl) -> Bool {
    appBar.notifyParent = true
    return true
  }

  private var page: RufletControl {
    guard let page = control.parentControl else {
      preconditionFailure("ViewControl requires a Page parent")
    }
    return page
  }

  private var backend: RufletBackend {
    guard let backend = control.backend as? RufletBackend else {
      preconditionFailure("ViewControl requires RufletBackend")
    }
    return backend
  }

  private var isTopView: Bool {
    topViewID.map { $0 == control.id } ?? (page.children("views").last === control)
  }

  private var shouldShowLoading: Bool {
    (backend.isLoading || !backend.error.isEmpty) && (backend.showAppStartupScreen ?? false)
  }

  private var horizontalAlignment: HorizontalAlignment {
    switch control.string("horizontal_alignment")?.lowercased() {
    case "center": .center
    case "end": .trailing
    default: .leading
    }
  }

  private var viewAlignment: Alignment {
    let horizontal: HorizontalAlignment = horizontalAlignment
    switch control.string("vertical_alignment")?.lowercased() {
    case "center":
      return horizontal == .center ? .center : (horizontal == .trailing ? .trailing : .leading)
    case "end":
      return horizontal == .center
        ? .bottom : (horizontal == .trailing ? .bottomTrailing : .bottomLeading)
    default:
      return horizontal == .center ? .top : (horizontal == .trailing ? .topTrailing : .topLeading)
    }
  }

}

private struct RufletTopViewIDKey: EnvironmentKey {
  static let defaultValue: Int? = nil
}

extension EnvironmentValues {
  var rufletTopViewID: Int? {
    get { self[RufletTopViewIDKey.self] }
    set { self[RufletTopViewIDKey.self] = newValue }
  }
}

struct RufletFloatingActionLocation: Equatable {
  enum Horizontal { case start, center, end }
  enum Vertical { case top, float, docked, contained }

  let horizontal: Horizontal
  let vertical: Vertical
  let mini: Bool
  let customOffset: CGSize?

  static func parse(_ value: Any?) -> RufletFloatingActionLocation {
    if let details = rufletDictionary(value), details["dx"] != nil || details["dy"] != nil {
      return RufletFloatingActionLocation(
        horizontal: .end,
        vertical: .float,
        mini: false,
        customOffset: CGSize(
          width: parseDouble(details["dx"], 0)!,
          height: parseDouble(details["dy"], 0)!))
    }
    if let offset = parseOffset(value) {
      return RufletFloatingActionLocation(
        horizontal: .end,
        vertical: .float,
        mini: false,
        customOffset: offset)
    }

    let raw = (value as? String)?.lowercased() ?? "endfloat"
    let mini = raw.hasPrefix("mini")
    let normalized = mini ? String(raw.dropFirst(4)) : raw
    let horizontal: Horizontal =
      normalized.hasPrefix("start")
      ? .start : (normalized.hasPrefix("center") ? .center : .end)
    let vertical: Vertical
    if normalized.hasSuffix("top") {
      vertical = .top
    } else if normalized.hasSuffix("docked") {
      vertical = .docked
    } else if normalized.hasSuffix("contained") {
      vertical = .contained
    } else {
      vertical = .float
    }
    return RufletFloatingActionLocation(
      horizontal: horizontal,
      vertical: vertical,
      mini: mini,
      customOffset: nil)
  }
}

private struct RufletFloatingActionPlacement<Content: View>: View {
  let location: RufletFloatingActionLocation
  let topBarHeight: Double
  let bottomBarHeight: Double
  @ViewBuilder let content: () -> Content

  init(
    location: Any?,
    topBarHeight: Double,
    bottomBarHeight: Double,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.location = .parse(location)
    self.topBarHeight = topBarHeight
    self.bottomBarHeight = bottomBarHeight
    self.content = content
  }

  var body: some View {
    GeometryReader { proxy in
      content()
        .background {
          GeometryReader { buttonProxy in
            Color.clear
              .preference(key: RufletFloatingActionSizeKey.self, value: buttonProxy.size)
          }
        }
        .position(position(in: proxy.size))
        .onPreferenceChange(RufletFloatingActionSizeKey.self) { size = $0 }
    }
    .allowsHitTesting(true)
  }

  @State private var size = CGSize(width: 56, height: 56)

  private func position(in container: CGSize) -> CGPoint {
    if let custom = location.customOffset {
      return CGPoint(
        x: container.width - custom.width + size.width / 2,
        y: container.height - custom.height + size.height / 2)
    }

    let margin = 16.0
    let x: Double
    switch location.horizontal {
    case .start: x = margin + size.width / 2
    case .center: x = container.width / 2
    case .end: x = container.width - margin - size.width / 2
    }

    let y: Double
    switch location.vertical {
    case .top:
      y = topBarHeight + margin + size.height / 2
    case .contained:
      y =
        bottomBarHeight > 0
        ? container.height - bottomBarHeight / 2
        : container.height - margin - size.height / 2
    case .docked:
      y =
        bottomBarHeight > 0
        ? container.height - bottomBarHeight
        : container.height - margin - size.height / 2
    case .float:
      y = container.height - bottomBarHeight - margin - size.height / 2
    }
    return CGPoint(x: x, y: y)
  }
}

private struct RufletBottomBarSizeKey: PreferenceKey {
  static let defaultValue = 0.0
  static func reduce(value: inout Double, nextValue: () -> Double) { value = nextValue() }
}

private struct RufletTopBarSizeKey: PreferenceKey {
  static let defaultValue = 0.0
  static func reduce(value: inout Double, nextValue: () -> Double) { value = nextValue() }
}

private struct RufletFloatingActionSizeKey: PreferenceKey {
  static let defaultValue = CGSize(width: 56, height: 56)
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct RufletViewScrollPositionKey: PreferenceKey {
  static let defaultValue = 0.0
  static func reduce(value: inout Double, nextValue: () -> Double) { value = nextValue() }
}

@MainActor
private final class RufletViewPopState: ObservableObject {
  private var continuation: CheckedContinuation<Bool, Never>?
  private var timeout: Task<Void, Never>?

  func request(control: RufletControl) async -> Bool {
    cancel()
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      control.triggerEvent("confirm_pop")
      timeout = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 300_000_000_000)
        guard !Task.isCancelled else { return }
        confirm(false)
      }
    }
  }

  func confirm(_ shouldPop: Bool) {
    timeout?.cancel()
    timeout = nil
    continuation?.resume(returning: shouldPop)
    continuation = nil
  }

  func cancel() { confirm(false) }
}

private struct RufletViewDrawerLayer<Content: View>: View {
  let edge: Edge
  @ViewBuilder let content: () -> Content
  let onDismiss: () -> Void

  var body: some View {
    ZStack(alignment: edge == .leading ? .leading : .trailing) {
      Color.black.opacity(0.28)
        .ignoresSafeArea()
        .onTapGesture(perform: onDismiss)
      content()
        .frame(maxWidth: 360, maxHeight: .infinity)
        .background(Color.rufletSystemBackground)
        .transition(.move(edge: edge))
    }
    .animation(.easeInOut(duration: 0.25), value: edge)
    .accessibilityAddTraits(.isModal)
  }
}

private struct RufletViewDecoration: View {
  let value: Any?

  var body: some View {
    let details = rufletDictionary(value)
    let radius = parseBorderRadius(details?["border_radius"], .zero)!
    let border = parseBorder(details?["border"])
    ZStack {
      if let gradient = parseGradient(details?["gradient"]) {
        RufletGradientShapeStyle(gradient: gradient)
      } else {
        parseColor(details?["color"] as? String) ?? .clear
      }
      if let border { RufletBorderOverlay(border: border, radius: radius) }
    }
    .clipShape(RufletCornerShape(radius: radius))
  }
}
