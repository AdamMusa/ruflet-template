import RufletProtocol
import SwiftUI
import Testing

@testable import RufletEngine

@MainActor
@Suite("Pinned Flet scrollable contract")
struct ScrollableControlContractTests {
  @Test("scroll_to parses pinned string numerics, duration, curve, and scroll key")
  func arguments() throws {
    let arguments = try RufletScrollToArguments(.map([
      "offset": "-10.5",
      "delta": "3.25",
      "scroll_key": .map(["_type": "scroll", "value": "hero"]),
      "duration": 250,
      "curve": "linear",
    ]))

    #expect(arguments.offset == -10.5)
    #expect(arguments.delta == 3.25)
    #expect(arguments.scrollKey == .scroll(.string("hero")))
    #expect(arguments.duration == 0.25)
    #expect(arguments.curve == .linear)
  }

  @Test("invoke listener mounts once, returns null, dispatches, and unmounts exactly")
  func lifecycle() async throws {
    let backend = ScrollableTestBackend()
    let control = RufletControl(id: 1, type: "Column", properties: [:], backend: backend)
    let viewport = ScrollableViewportSpy()
    let coordinator = RufletScrollableCoordinator()

    coordinator.mount(control: control, viewport: viewport)
    coordinator.mount(control: control, viewport: viewport)
    #expect(try await control.invokeMethod("unknown", arguments: .null) == .null)
    #expect(
      try await control.invokeMethod(
        "scroll_to",
        arguments: .map(["offset": "24", "duration": 0, "curve": "easeout"])) == .null)
    #expect(viewport.scrolls == [
      .init(offset: 24, delta: nil, duration: 0, curve: .easeout)
    ])

    coordinator.unmount()
    let fallback = control.addInvokeMethodListener { _, _ in "fallback" }
    defer { control.removeInvokeMethodListener(fallback) }
    #expect(try await control.invokeMethod("scroll_to", arguments: .null) == "fallback")
  }

  @Test("missing scroll key falls through to offset and auto-scroll follows native updates")
  func scrollKeyAndAutoScroll() async throws {
    let backend = ScrollableTestBackend()
    let control = RufletControl(
      id: 1,
      type: "ListView",
      properties: ["auto_scroll": true],
      backend: backend)
    let viewport = ScrollableViewportSpy()
    let coordinator = RufletScrollableCoordinator()

    coordinator.mount(control: control, viewport: viewport)
    await settle()
    #expect(viewport.endScrolls == [.init(duration: 1, curve: .ease)])

    _ = try await control.invokeMethod(
      "scroll_to",
      arguments: .map([
        "scroll_key": .map(["_type": "scroll", "value": "missing"]),
        "offset": 18,
      ]))
    #expect(viewport.scrolls.last == .init(offset: 18, delta: nil, duration: 0, curve: .ease))

    control.update(["controls_revision": 1], notify: true)
    await settle()
    #expect(viewport.endScrolls.count == 2)

    coordinator.unmount()
    control.update(["controls_revision": 2], notify: true)
    await settle()
    #expect(viewport.endScrolls.count == 2)
  }

  @Test("offset, negative offset, and delta resolve against native metrics")
  func offsets() {
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: 25,
        delta: nil,
        current: 10,
        maximum: 100) == 25)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: -1,
        delta: nil,
        current: 10,
        maximum: 100) == 100)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: -10,
        delta: nil,
        current: 10,
        maximum: 100) == 91)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: nil,
        delta: 15,
        current: 10,
        maximum: 100) == 25)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: nil,
        delta: -50,
        current: 10,
        maximum: 100) == 0)
  }

  @Test("all Flet key scalar types retain the same scroll registry identity")
  func keys() {
    #expect(parseKey(["_type": "scroll", "value": 7])?.description == "7")
    #expect(parseKey(["_type": "scroll", "value": "hero"])?.description == "hero")
    #expect(parseKey(["_type": "scroll", "value": true])?.description == "true")
    #expect(parseKey(["_type": "scroll", "value": 2.5])?.description == "2.5")
  }

  @Test("every native list family mounts the shared ScrollableControl")
  func listFamiliesUseSharedContract() throws {
    let sources = [
      "list_view.swift",
      "grid_view.swift",
      "reorderable_list_view.swift",
    ]
    let root = packageRoot.appendingPathComponent("Sources/RufletEngine/Controls")
    for source in sources {
      let text = try String(contentsOf: root.appendingPathComponent(source), encoding: .utf8)
      #expect(text.contains("ScrollableControl("), Comment(rawValue: source))
      #expect(text.contains("RufletScrollViewportAttachment"), Comment(rawValue: source))
    }
  }

  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func settle() async {
    await Task.yield()
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
}

@MainActor
private final class ScrollableViewportSpy: RufletScrollViewportDriving {
  struct Scroll: Equatable {
    let offset: Double?
    let delta: Double?
    let duration: TimeInterval
    let curve: RufletCurve
  }

  struct EndScroll: Equatable {
    let duration: TimeInterval
    let curve: RufletCurve
  }

  var scrolls: [Scroll] = []
  var endScrolls: [EndScroll] = []

  func scroll(
    offset: Double?,
    delta: Double?,
    duration: TimeInterval,
    curve: RufletCurve
  ) {
    scrolls.append(.init(offset: offset, delta: delta, duration: duration, curve: curve))
  }

  func scrollToEnd(duration: TimeInterval, curve: RufletCurve) {
    endScrolls.append(.init(duration: duration, curve: curve))
  }
}

@MainActor
private final class ScrollableTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
