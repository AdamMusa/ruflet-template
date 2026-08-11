import RufletEngine
import RufletMedia
import RufletProtocol
import XCTest

/// Behavioral service contracts mirrored from vendored Flet.
///
/// These assertions call the command boundary and inspect replies/state. A
/// factory registration alone is not service support.
final class ServiceCommandConformanceTests: XCTestCase {
  @MainActor
  private func context(
    store: ControlStore = ControlStore(),
    events: @escaping (Int, String, RufletValue) -> Void = { _, _, _ in }
  ) -> RufletServiceContext {
    RufletServiceContext(store: store, emitEvent: events)
  }

  @MainActor
  private func invoke(
    _ service: RufletService,
    type: String,
    method: String,
    args: RufletValue = .map([:]),
    node: ControlNode? = nil,
    context: RufletServiceContext? = nil
  ) -> Result<RufletValue, Error>? {
    var reply: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: node?.id ?? 1, callID: "test", name: method, args: args),
      node: node,
      context: context ?? self.context()
    ) { reply = $0 }
    return reply
  }

  @MainActor
  func testCoreAndOptionalBundlesCoverAdvertisedServiceAndHostTypes() {
    let registry = ServiceRegistry()
    registry.registerDefaults()
    RufletMedia.register(in: registry)

    for type in [
      "Page", "View", "BasePage", "Pagelet", "BrowserContextMenu", "Battery",
      "Clipboard", "Connectivity", "FilePicker", "HapticFeedback", "PermissionHandler",
      "ScreenBrightness", "SecureStorage", "SemanticsService", "Share",
      "SharedPreferences", "StoragePaths", "UrlLauncher", "Wakelock", "Audio",
      "AudioRecorder", "Camera", "Flashlight"
    ] {
      XCTAssertTrue(registry.handles(type), type)
    }
  }

  @MainActor
  func testPagePushRouteMutatesHostStateAndDeviceInfoHasCanonicalFields() {
    let store = ControlStore()
    store.applyPageProperties([:])
    let node = store.page!
    let service = PageService()
    let serviceContext = context(store: store)

    let routeReply = invoke(
      service, type: "Page", method: "push_route",
      args: .map(["route": .string("/settings")]), node: node, context: serviceContext)
    XCTAssertEqual(try? routeReply?.get(), .null)
    XCTAssertEqual(store.page?.string("route"), "/settings")

    let infoReply = invoke(
      service, type: "Page", method: "get_device_info", node: store.page,
      context: serviceContext)
    let info = try? infoReply?.get().mapValue
    XCTAssertFalse(info?["os"]?.stringValue?.isEmpty ?? true)
    XCTAssertFalse(info?["os_version"]?.stringValue?.isEmpty ?? true)
    XCTAssertFalse(info?["locale"]?.stringValue?.isEmpty ?? true)
  }

  @MainActor
  func testUnsupportedPlatformCommandsAreClassifiedRatherThanUnknown() {
    let browserReply = invoke(
      BrowserContextMenuService(), type: "BrowserContextMenu", method: "disable_menu")
    guard case .failure(let browserError)? = browserReply else {
      return XCTFail("browser context menu must return a classified failure")
    }
    guard case .platformUnsupported(let type, let method, _) = browserError as? RufletServiceError else {
      return XCTFail("unexpected error: \(browserError)")
    }
    XCTAssertEqual(type, "BrowserContextMenu")
    XCTAssertEqual(method, "disable_menu")

    let uploadReply = invoke(FilePickerService(), type: "FilePicker", method: "upload")
    guard case .failure(let uploadError)? = uploadReply,
      case .platformUnsupported("FilePicker", "upload", _) = uploadError as? RufletServiceError
    else { return XCTFail("upload must be explicitly platform unsupported") }
  }

  @MainActor
  func testConnectivityResultUsesFletListShape() {
    let reply = invoke(ConnectivityService(), type: "Connectivity", method: "get_connectivity")
    let values = try? reply?.get().arrayValue
    XCTAssertEqual(values?.count, 1)
    XCTAssertNotNil(values?.first?.stringValue)
  }

  @MainActor
  func testSemanticsFeaturesUseTheCompleteFletResultShape() {
    let reply = invoke(
      SemanticsAnnouncementService(), type: "SemanticsService",
      method: "get_accessibility_features")
    let features = try? reply?.get().mapValue
    XCTAssertEqual(Set(features.map { Array($0.keys) } ?? []), [
      "accessible_navigation", "bold_text", "disable_animations", "high_contrast",
      "invert_colors", "reduce_motion", "on_off_switch_labels", "supports_announcements"
    ])
  }

  @MainActor
  func testRecorderStateQueriesAndCameraUnsupportedCaptureAreExecutable() {
    let paused = invoke(AudioRecorderService(), type: "AudioRecorder", method: "is_paused")
    XCTAssertEqual(try? paused?.get(), .bool(false))

    let camera = CameraService()
    let streaming = invoke(camera, type: "Camera", method: "supports_image_streaming")
    XCTAssertEqual(try? streaming?.get(), .bool(false))

    let capture = invoke(camera, type: "Camera", method: "take_picture")
    guard case .failure(let error)? = capture,
      case .platformUnsupported("Camera", "take_picture", _) = error as? RufletServiceError
    else { return XCTFail("service-mode capture must be explicitly classified") }
  }
}
