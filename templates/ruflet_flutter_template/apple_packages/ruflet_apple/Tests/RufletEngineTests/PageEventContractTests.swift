import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class PageEventContractTests: XCTestCase {
  func testBackendOwnedPageEventsPreservePinnedPayloadsAndSubscriberPolicy() {
    let backend = PageEventBackend()
    let page = backend.page
    let view = RufletControl(
      id: 2,
      type: "View",
      properties: ["on_media_change": true],
      backend: backend)
    let media = RufletPageMediaData(
      padding: .zero,
      viewPadding: .zero,
      viewInsets: .zero,
      devicePixelRatio: 2,
      orientation: .portrait,
      alwaysUse24HourFormat: false)

    RufletPageEventContract.routeChanged(page, route: "/gallery")
    RufletPageEventContract.platformBrightnessChanged(page, brightness: "dark")
    RufletPageEventContract.mediaChanged(view, media: media)
    RufletPageEventContract.appLifecycleChanged(page, state: "resume")

    XCTAssertEqual(
      backend.events.map(\.name),
      [
        "route_change", "platform_brightness_change", "media_change",
        "app_lifecycle_state_change",
      ])
    XCTAssertEqual(backend.events[0].data, ["route": .string("/gallery")])
    XCTAssertEqual(backend.events[1].data, .string("dark"))
    XCTAssertEqual(backend.events[2].data, media.value)
    XCTAssertEqual(backend.events[2].controlID, view.id)
    XCTAssertEqual(backend.events[3].data, ["state": .string("resume")])
  }

  func testMultiViewEventsAndChildOwnershipMatchPinnedPageContract() {
    let backend = PageEventBackend()
    let page = backend.page
    let first = RufletControl(id: 3, type: "View", properties: [:], backend: backend)
    let second = RufletControl(id: 4, type: "View", properties: [:], backend: backend)
    page.update(["multi_views": .array([first.valueMap, second.valueMap])])

    RufletPageEventContract.multiViewAdded(
      page,
      view: RufletMultiView(viewID: 11, initialData: ["source": .string("native")]))
    RufletPageEventContract.multiViewRemoved(page, viewID: 11)

    XCTAssertEqual(RufletPageEventContract.multiViewControls(in: page).map(\.id), [3, 4])
    XCTAssertEqual(backend.events.map(\.name), ["multi_view_add", "multi_view_remove"])
    XCTAssertEqual(
      backend.events[0].data,
      ["view_id": .int(11), "initial_data": ["source": .string("native")]])
    XCTAssertEqual(backend.events[1].data, .int(11))
  }

  func testSemanticsDebuggerWalksTheLiveNativeControlGraph() {
    let backend = PageEventBackend()
    let child = RufletControl(
      id: 5,
      type: "Semantics",
      properties: ["label": .string("Submit")],
      backend: backend)
    backend.page.update(["views": .array([child.valueMap])])

    let entries = RufletPageSemanticsDebugger(page: backend.page).entries

    XCTAssertEqual(entries, ["Page#1", "  Semantics#5: Submit"])
  }
}

@MainActor
private final class PageEventBackend: RufletBackendProtocol {
  struct Event {
    let controlID: Int
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = URL(string: "http://127.0.0.1:8550")
  lazy var extensionRegistry = RufletExtensionRegistry([RufletCoreExtension()])
  lazy var page = RufletControl(id: 1, type: "Page", properties: [:], backend: self)
  var events: [Event] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    guard control.hasEventHandler(name) else { return }
    triggerControlEvent(controlID: control.id, name: name, data: data)
  }
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(controlID: controlID, name: name, data: data))
  }
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
