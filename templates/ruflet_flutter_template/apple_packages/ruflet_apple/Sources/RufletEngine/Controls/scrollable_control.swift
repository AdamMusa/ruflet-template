import RufletProtocol
import SwiftUI

enum RufletScrollMode: String, CaseIterable, RufletStringEnum {
  case none, auto, adaptive, always, hidden
}

/// Apple-native port of pinned Flet's shared `ScrollableControl`.
@MainActor
struct ScrollableControl<Content: View>: View {
  @ObservedObject var control: RufletControl
  @StateObject private var viewport = RufletScrollViewport()
  @State private var invokeListener: UUID?
  @State private var updateListener: UUID?

  let child: Content
  let scrollDirection: Axis.Set
  let wrapIntoScrollableView: Bool

  init(
    control: RufletControl,
    scrollDirection: Axis.Set,
    wrapIntoScrollableView: Bool = false,
    @ViewBuilder child: () -> Content
  ) {
    self.control = control
    self.scrollDirection = scrollDirection
    self.wrapIntoScrollableView = wrapIntoScrollableView
    self.child = child()
  }

  var body: some View {
    rendered
      .environment(\.rufletScrollViewport, viewport)
      .onAppear {
        viewport.configure(horizontal: scrollDirection == .horizontal)
        installListeners()
        scheduleAutoScrollIfNeeded()
      }
      .onChange(of: autoScrollSignature) { _ in scheduleAutoScrollIfNeeded() }
      .onDisappear(perform: removeListeners)
  }

  @ViewBuilder
  private var rendered: some View {
    if wrapIntoScrollableView, mode != .none {
      ScrollView(scrollDirection, showsIndicators: mode != .hidden) {
        child.background(RufletScrollViewportAttachment())
      }
    } else {
      child
    }
  }

  private var mode: RufletScrollMode {
    parseEnum(RufletScrollMode.self, control.string("scroll"), RufletScrollMode.none)!
  }

  private var autoScrollSignature: String {
    guard control.boolean("auto_scroll", default: false) else { return "off" }
    return control.children("controls", visibleOnly: false).map(\.id)
      .map(String.init)
      .joined(separator: ",")
  }

  private func installListeners() {
    guard invokeListener == nil else { return }
    invokeListener = control.addInvokeMethodListener {
      [weak viewport, weak backend = control.backend] name, args in
      guard name == "scroll_to", let viewport else { return .null }
      let values = args.map ?? [:]
      let duration = parseRufletWireDuration(values["duration"], 0) ?? 0
      let curve = parseCurve(values["curve"]?.text, .ease)!
      if let scrollKey = parseKey(values["scroll_key"]),
        let target = backend?.scrollTarget(for: scrollKey.description)
      {
        target.reveal(duration: duration, curve: curve)
      } else {
        viewport.scroll(
          offset: values["offset"]?.number,
          delta: values["delta"]?.number,
          duration: duration,
          curve: curve)
      }
      return .null
    }
    updateListener = control.addListener { [weak viewport] in
      guard control.boolean("auto_scroll", default: false) else { return }
      Task { @MainActor in
        await Task.yield()
        viewport?.scrollToEnd(duration: 1, curve: .ease)
      }
    }
  }

  private func removeListeners() {
    if let invokeListener {
      control.removeInvokeMethodListener(invokeListener)
      self.invokeListener = nil
    }
    if let updateListener {
      control.removeListener(updateListener)
      self.updateListener = nil
    }
  }

  private func scheduleAutoScrollIfNeeded() {
    guard control.boolean("auto_scroll", default: false) else { return }
    Task { @MainActor in
      await Task.yield()
      viewport.scrollToEnd(duration: 1, curve: .ease)
    }
  }
}
