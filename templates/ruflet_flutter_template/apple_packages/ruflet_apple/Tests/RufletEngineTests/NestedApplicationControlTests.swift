import RufletProtocol
import XCTest
@testable import RufletEngine

@MainActor
final class NestedApplicationControlTests: XCTestCase {
  func testNestedAppAndPageletResolveThroughCoreExtension() {
    let backend = NestedControlBackend()
    let extensionUnderTest = RufletCoreExtension()
    for (id, type) in [(1, "FletApp"), (2, "Pagelet")] {
      let control = RufletControl(id: id, type: type, properties: [:], backend: backend)
      XCTAssertNotNil(extensionUnderTest.createView(for: control))
      XCTAssertTrue(extensionUnderTest.renderedControlTypes.contains(type))
    }
  }

  func testNestedAppArgumentsRemainWireValues() {
    let backend = NestedControlBackend()
    let control = RufletControl(
      id: 1,
      type: "FletApp",
      properties: ["args": .map(["token": .string("native"), "count": .int(3)])],
      backend: backend)
    XCTAssertEqual(control.value("args")?.map?["token"], .string("native"))
    XCTAssertEqual(control.value("args")?.map?["count"], .int(3))
  }
}

@MainActor
private final class NestedControlBackend: RufletBackendProtocol {
  let pageURI: URL? = URL(string: "http://127.0.0.1:8550")
  let extensionRegistry = RufletExtensionRegistry([])
  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(_ id: Int, properties: [String: RufletValue], client: Bool, server: Bool, notify: Bool) {}
  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
