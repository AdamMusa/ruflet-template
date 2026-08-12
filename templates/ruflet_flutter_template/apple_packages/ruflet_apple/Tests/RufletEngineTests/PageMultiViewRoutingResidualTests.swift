import Foundation
import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

private final class PageResidualRecordingTransport: RufletTransport {
  weak var delegate: RufletTransportDelegate?
  private(set) var sent: [Data] = []

  func connect() { delegate?.transportDidOpen(self) }
  func send(_ data: Data) { sent.append(data) }
  func disconnect() { delegate?.transport(self, didCloseWith: nil) }
}

@MainActor
final class PageMultiViewRoutingResidualTests: XCTestCase {
  func testDeepLinkNormalizationPreservesEncodedRouteComponents() throws {
    let url = try XCTUnwrap(
      URL(string: "ruflet://application/store/red%20shoe?q=red%20blue#size%20guide"))

    XCTAssertEqual(
      PageRouteSemantics.normalizeExternalURL(url),
      "/store/red%20shoe?q=red%20blue#size%20guide")
  }

  func testBasePageSelectionUsesRootOnlyInSingleViewMode() {
    let store = ControlStore()
    store.applyPageProperties([
      "multi_views": .array([
        .map([
          RufletControlKey.id: .int(30),
          RufletControlKey.type: .string("MultiView"),
          "view_id": .int(7),
        ]),
        .map([
          RufletControlKey.id: .int(31),
          RufletControlKey.type: .string("MultiView"),
          "view_id": .int(9),
        ]),
      ])
    ])
    let page = try! XCTUnwrap(store.page)

    XCTAssertEqual(
      PagePresentationSemantics.basePage(root: page, nativeSceneID: nil, store: store)?.id,
      RufletWireID.page)
    XCTAssertEqual(
      PagePresentationSemantics.basePage(root: page, nativeSceneID: 9, store: store)?.id,
      31)
    XCTAssertNil(
      PagePresentationSemantics.basePage(root: page, nativeSceneID: 11, store: store))
  }

  func testMultiViewLifecycleIsAnnouncedOnceAndCarriesInitialData() throws {
    let transport = PageResidualRecordingTransport()
    let session = RufletSession(transport: transport)
    let registry = RufletNativeSceneRegistry()
    registry.bind(to: session)

    let scene = registry.connect(
      sessionIdentifier: "window-1",
      initialData: ["route": .string("/details"), "restored": .bool(true)])
    _ = registry.connect(sessionIdentifier: "window-1", initialData: ["ignored": .bool(true)])
    registry.bind(to: session)

    let messages = try transport.sent.map(RufletMessage.decode)
    XCTAssertEqual(messages.count, 1)
    XCTAssertEqual(messages[0].payload["name"], .string("multi_view_add"))
    XCTAssertEqual(messages[0].payload["target"], .int(Int64(RufletWireID.page)))
    XCTAssertEqual(messages[0].payload["data"]?["view_id"], .int(Int64(scene.id)))
    XCTAssertEqual(messages[0].payload["data"]?["initial_data"]?["route"], .string("/details"))
    XCTAssertEqual(messages[0].payload["data"]?["initial_data"]?["restored"], .bool(true))
  }

  func testViewPopBelongsToNativePopRequestAndUsesPageAsEventTarget() {
    let page = ControlNode(id: RufletWireID.page, type: "Page")
    let view = ControlNode(id: 45, type: "View", props: ["route": .string("/orders/45")])
    var events: [(Int, String, RufletValue)] = []
    let sink = RufletEventSink(send: { events.append(($0, $1, $2)) })

    RufletPageNavigation.commitPop(page: page, view: view, events: sink)

    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].0, RufletWireID.page)
    XCTAssertEqual(events[0].1, "view_pop")
    XCTAssertEqual(events[0].2, .map(["route": .string("/orders/45")]))
  }
}
