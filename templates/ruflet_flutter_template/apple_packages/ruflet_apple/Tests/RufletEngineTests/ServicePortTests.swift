import CoreGraphics
import Foundation
import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class ServicePortTests: XCTestCase {
  func testCoreFactoryContainsAppleServicesAndSkipsWebContextMenu() {
    let backend = ServiceTestBackend()
    let factory = RufletCoreServiceExtension()
    XCTAssertTrue(factory.createService(for: backend.control(type: "Accelerometer")) is AccelerometerService)
    XCTAssertTrue(factory.createService(for: backend.control(type: "FilePicker")) is FilePickerService)
    XCTAssertTrue(factory.createService(for: backend.control(type: "Window")) is WindowService)
    XCTAssertNil(factory.createService(for: backend.control(type: "BrowserContextMenu")))
  }

  func testAccelerometerSerializationPreservesFletWireNames() {
    let backend = ServiceTestBackend()
    let service = AccelerometerService(control: backend.control(type: "Accelerometer"))
    let value = service.serializeEvent(.init(x: 1, y: 2, z: 3, timestamp: Date(timeIntervalSince1970: 1)))
    guard let map = value.map else { return XCTFail("sensor event must be a map") }
    XCTAssertEqual(map["x"], RufletValue.double(1))
    XCTAssertEqual(map["y"], RufletValue.double(2))
    XCTAssertEqual(map["z"], RufletValue.double(3))
    guard let timestamp = map["timestamp"], case .extensionValue(type: 1, _) = timestamp else {
      return XCTFail("timestamp must remain Flet's DateTime extension")
    }
  }

  func testStoragePathsContainsApplePathsAndRejectsNonAppleMethods() async throws {
    let backend = ServiceTestBackend()
    let service = StoragePaths(control: backend.control(type: "StoragePaths"))
    let library = try await service.invoke("get_library_directory", arguments: [:])
    XCTAssertFalse(library?.text?.isEmpty ?? true)
    do {
      _ = try await service.invoke("get_external_storage_directory", arguments: [:])
      XCTFail("Non-Apple storage methods must not exist")
    } catch let error as RufletServiceError {
      XCTAssertEqual(error, .unknownMethod(service: "StoragePaths", method: "get_external_storage_directory"))
    }
  }

  func testSharedPreferencesUsesPinnedValueAndMethodNames() async throws {
    let backend = ServiceTestBackend()
    let service = SharedPreferencesService(control: backend.control(type: "SharedPreferences"))
    let key = "ruflet.service.test.\(UUID().uuidString)"
    defer { UserDefaults.standard.removeObject(forKey: key) }
    _ = try await service.invoke("set", arguments: ["key": .string(key), "value": .array(["a", "b"])])
    let stored = try await service.invoke("get", arguments: ["key": .string(key)])
    XCTAssertEqual(stored, .array(["a", "b"]))
    let contains = try await service.invoke("contains_key", arguments: ["key": .string(key)])
    XCTAssertEqual(contains, .bool(true))
    let keys = try await service.invoke("get_keys", arguments: ["key_prefix": .string(key)])
    XCTAssertEqual(keys, .array([.string(key)]))
  }

  func testTesterServiceRemembersFinderAndDispatchesTap() async throws {
    let backend = ServiceTestBackend()
    let tester = ServiceTestTester()
    backend.tester = tester
    let service = TesterService(control: backend.control(type: "Tester"))
    let finder = try await service.invoke("find_by_text", arguments: ["text": "Hello"])
    XCTAssertEqual(finder, ["id": 7, "count": 2])
    _ = try await service.invoke("tap", arguments: ["finder_id": 7, "finder_index": 1])
    XCTAssertEqual(tester.lastTapIndex, 1)
  }
}

@MainActor
private final class ServiceTestBackend: RufletTestingBackend {
  var pageURI: URL? = URL(string: "https://example.test/app")
  lazy var extensionRegistry = RufletExtensionRegistry([RufletCoreServiceExtension()])
  var tester: RufletTester?
  private var nextID = 1

  func control(type: String, properties: [String: RufletValue] = [:]) -> RufletControl {
    defer { nextID += 1 }
    return RufletControl(id: nextID, type: type, properties: properties, backend: self)
  }

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int, properties: [String: RufletValue], client: Bool, server: Bool, notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}

@MainActor
private final class ServiceTestTester: RufletTester {
  var lastTapIndex: Int?
  func pump(duration: TimeInterval?) async throws {}
  func pumpAndSettle(duration: TimeInterval?) async throws {}
  func findByText(_ text: String) -> RufletTestFinder { .init(id: 7, count: 2, raw: text) }
  func findByTextContaining(_ pattern: String) -> RufletTestFinder { .init(id: 8, count: 0, raw: pattern) }
  func findByKey(_ key: RufletValue) throws -> RufletTestFinder { .init(id: 9, count: 0, raw: key) }
  func findByTooltip(_ value: String) -> RufletTestFinder { .init(id: 10, count: 0, raw: value) }
  func findByIcon(_ icon: RufletValue) throws -> RufletTestFinder { .init(id: 11, count: 0, raw: icon) }
  func takeScreenshot(_ name: String) async throws -> Data { Data(name.utf8) }
  func tapAt(_ point: CGPoint) async throws {}
  func tap(_ finder: RufletTestFinder, index: Int) async throws { lastTapIndex = index }
  func longPress(_ finder: RufletTestFinder, index: Int) async throws {}
  func enterText(_ finder: RufletTestFinder, index: Int, text: String) async throws {}
  func mouseHover(_ finder: RufletTestFinder, index: Int) async throws {}
  func teardown() {}
  func waitForTeardown() async {}
}
