import Foundation
import RufletProtocol
import Testing

@testable import RufletEngine

@MainActor
@Suite("Pinned Flet PageView contract")
struct PageViewControlTests {
  @Test("configuration consumes pinned defaults and controller rebuild fields")
  func configuration() {
    let defaults = RufletPageViewConfiguration(control: makePageView())
    #expect(defaults.horizontal)
    #expect(!defaults.reverse)
    #expect(defaults.clipBehavior == "hardedge")
    #expect(defaults.padEnds)
    #expect(!defaults.implicitScrolling)
    #expect(defaults.snap)
    #expect(defaults.keepPage)
    #expect(defaults.viewportFraction == 1)
    #expect(defaults.animationDuration == 1)
    #expect(defaults.animationCurve == .linear)

    let configured = RufletPageViewConfiguration(
      control: makePageView(properties: [
        "horizontal": false,
        "reverse": true,
        "clip_behavior": "none",
        "pad_ends": false,
        "implicit_scrolling": true,
        "snap": false,
        "keep_page": false,
        "viewport_fraction": 0.75,
        "animation_duration": 250,
        "animation_curve": "easeInOut",
      ]))
    #expect(!configured.horizontal)
    #expect(configured.reverse)
    #expect(configured.clipBehavior == "none")
    #expect(!configured.padEnds)
    #expect(configured.implicitScrolling)
    #expect(!configured.snap)
    #expect(!configured.keepPage)
    #expect(configured.viewportFraction == 0.75)
    #expect(configured.animationDuration == 0.25)
    #expect(configured.animationCurve == .easeinout)
  }

  @Test("selection updates before change and repeated page does not emit")
  func selectionOrdering() {
    let backend = PageViewTestBackend()
    let control = makePageView(backend: backend)
    let coordinator = RufletPageViewCoordinator(selectedIndex: 0)
    coordinator.mount(
      control: control,
      pageCount: 3,
      configuration: RufletPageViewConfiguration(control: control))

    #expect(coordinator.commitPage(2, animated: false, notify: true))
    #expect(!coordinator.commitPage(2, animated: false, notify: true))
    #expect(backend.calls == [
      .update(["selected_index": 2]),
      .event("change", 2),
    ])
    coordinator.unmount()
  }

  @Test("invoke listener mounts once, parses string numerics, and unmounts exactly")
  func invokeLifecycle() async throws {
    let backend = PageViewTestBackend()
    let control = makePageView(backend: backend)
    let coordinator = RufletPageViewCoordinator(selectedIndex: 0)
    let configuration = RufletPageViewConfiguration(control: control)
    coordinator.mount(control: control, pageCount: 4, configuration: configuration)
    coordinator.mount(control: control, pageCount: 4, configuration: configuration)

    #expect(
      try await control.invokeMethod(
        "jump_to_page",
        arguments: ["index": "2"]) == .null)
    coordinator.setPageLength(100)
    #expect(
      try await control.invokeMethod(
        "jump_to",
        arguments: ["value": "350"]) == .null)
    #expect(coordinator.selectedIndex == 3)

    coordinator.unmount()
    let fallback = control.addInvokeMethodListener { _, _ in "fallback" }
    #expect(try await control.invokeMethod("anything", arguments: .null) == "fallback")
    control.removeInvokeMethodListener(fallback)
  }

  @Test("server updates do not emit and keep-page restores across native remount")
  func synchronizationAndKeepPage() {
    let backend = PageViewTestBackend()
    let control = makePageView(backend: backend)
    let configuration = RufletPageViewConfiguration(control: control)
    let first = RufletPageViewCoordinator(selectedIndex: 0)
    first.mount(control: control, pageCount: 3, configuration: configuration)
    first.commitPage(2, animated: false, notify: false)
    first.unmount()

    let restored = RufletPageViewCoordinator(selectedIndex: 0)
    restored.mount(control: control, pageCount: 3, configuration: configuration)
    #expect(restored.selectedIndex == 2)
    backend.calls.removeAll()
    control.update(["selected_index": 1], notify: true)
    restored.synchronize(pageCount: 3, configuration: configuration)
    #expect(restored.selectedIndex == 1)
    #expect(backend.calls.isEmpty)
    restored.unmount()
  }

  private func makePageView(
    properties: [String: RufletValue] = [:],
    backend: PageViewTestBackend? = nil
  ) -> RufletControl {
    var wire = properties
    wire["selected_index"] = wire["selected_index"] ?? 0
    return RufletControl(
      id: 71,
      type: "PageView",
      properties: wire,
      backend: backend ?? PageViewTestBackend())
  }
}

@MainActor
private final class PageViewTestBackend: RufletBackendProtocol {
  enum Call: Equatable {
    case update([String: RufletValue])
    case event(String, RufletValue)
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var calls: [Call] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    calls.append(.event(name, data))
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    calls.append(.update(properties))
  }
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
