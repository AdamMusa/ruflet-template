import CoreGraphics
import Foundation
import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class ServicePortTests: XCTestCase {
  func testCoreFactoryContainsAllPinnedServicesIncludingBrowserContextMenuNoOp() {
    let backend = ServiceTestBackend()
    let factory = RufletCoreServiceExtension()
    XCTAssertTrue(factory.createService(for: backend.control(type: "Accelerometer")) is AccelerometerService)
    XCTAssertTrue(factory.createService(for: backend.control(type: "FilePicker")) is FilePickerService)
    XCTAssertTrue(factory.createService(for: backend.control(type: "Window")) is WindowService)
    XCTAssertTrue(
      factory.createService(for: backend.control(type: "BrowserContextMenu"))
        is BrowserContextMenuService)
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

  func testStoragePathsContainsApplePathsAndReturnsNullForAndroidOnlyMethods() async throws {
    let backend = ServiceTestBackend()
    let service = StoragePaths(control: backend.control(type: "StoragePaths"))
    let library = try await service.invoke("get_library_directory", arguments: [:])
    XCTAssertFalse(library?.text?.isEmpty ?? true)
    let externalCaches = try await service.invoke("get_external_cache_directories", arguments: [:])
    let externalDirectories = try await service.invoke(
      "get_external_storage_directories", arguments: [:])
    let externalDirectory = try await service.invoke(
      "get_external_storage_directory", arguments: [:])
    XCTAssertEqual(externalCaches, .null)
    XCTAssertEqual(externalDirectories, .null)
    XCTAssertEqual(externalDirectory, .null)
  }

  func testBrowserContextMenuRecognizesPinnedCommandsAsAppleNoOps() async throws {
    let backend = ServiceTestBackend()
    let service = BrowserContextMenuService(
      control: backend.control(type: "BrowserContextMenu"))
    let disabled = try await service.invoke("disable_menu", arguments: [:])
    let enabled = try await service.invoke("enable_menu", arguments: [:])
    XCTAssertNil(disabled)
    XCTAssertNil(enabled)
    do {
      _ = try await service.invoke("unknown", arguments: [:])
      XCTFail("Unknown BrowserContextMenu methods must fail")
    } catch let error as RufletServiceError {
      XCTAssertEqual(
        error, .unknownMethod(service: "BrowserContextMenu", method: "unknown"))
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

  func testHiddenServicesAreDisposedAndRecreatedWhenShown() throws {
    VisibilityLifecycleService.initializeCount = 0
    VisibilityLifecycleService.disposeCount = 0
    let backend = ServiceTestBackend(extensions: [VisibilityLifecycleExtension()])
    let host = backend.control(
      type: "ServiceHost",
      properties: [
        "services": .array([
          .map([
            "_c": .string("VisibilityLifecycle"),
            "_i": .int(100),
            "visible": .bool(true),
          ])
        ])
      ])
    let registry = try ServiceRegistry(
      control: host,
      propertyName: "services",
      backend: backend)
    let serviceControl = try XCTUnwrap(host.children("services", visibleOnly: false).first)

    XCTAssertEqual(VisibilityLifecycleService.initializeCount, 1)
    XCTAssertEqual(VisibilityLifecycleService.disposeCount, 0)

    serviceControl.update(["visible": .bool(false)], notify: false)
    XCTAssertEqual(VisibilityLifecycleService.initializeCount, 1)
    XCTAssertEqual(VisibilityLifecycleService.disposeCount, 1)

    serviceControl.update(["visible": .bool(true)], notify: false)
    XCTAssertEqual(VisibilityLifecycleService.initializeCount, 2)
    XCTAssertEqual(VisibilityLifecycleService.disposeCount, 1)

    registry.dispose()
    XCTAssertEqual(VisibilityLifecycleService.disposeCount, 2)
  }
}

@MainActor
private final class ServiceTestBackend: RufletTestingBackend {
  var pageURI: URL? = URL(string: "https://example.test/app")
  private let extensions: [any RufletExtension]
  lazy var extensionRegistry = RufletExtensionRegistry(extensions)
  var tester: RufletTester?
  private var nextID = 1

  init() {
    extensions = [RufletCoreServiceExtension()]
  }

  init(extensions: [any RufletExtension]) {
    self.extensions = extensions
  }

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
private struct VisibilityLifecycleExtension: RufletExtension {
  let serviceControlTypes: Set<String> = ["VisibilityLifecycle"]

  func createService(for control: RufletControl) -> RufletService? {
    guard control.type == "VisibilityLifecycle" else { return nil }
    return VisibilityLifecycleService(control: control)
  }
}

@MainActor
private final class VisibilityLifecycleService: RufletService {
  static var initializeCount = 0
  static var disposeCount = 0

  override func initialize() {
    Self.initializeCount += 1
  }

  override func dispose() {
    Self.disposeCount += 1
  }
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
