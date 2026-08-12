import RufletEngine
import RufletAudio
import RufletAudioRecorder
import RufletCamera
import RufletFlashlight
import RufletGeolocator
import RufletPermissionHandler
import RufletProtocol
import RufletSecureStorage
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
    RufletAudio.register(in: registry)
    RufletAudioRecorder.register(in: registry)
    RufletCamera.register(in: registry)
    RufletFlashlight.register(in: registry)
    RufletGeolocator.register(in: registry)
    RufletPermissionHandler.register(in: registry)
    RufletSecureStorage.register(in: registry)

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
  func testViewConfirmPopCompletesThePendingDecisionWithFletRoutePayload() {
    let store = ControlStore()
    store.applyPageProperties([
      "views": .array([
        .map([
          RufletControlKey.id: .int(7),
          RufletControlKey.type: .string("View"),
          "route": .string("/details"),
        ])
      ])
    ])
    let view = store.node(7)!
    var observed: (Int, String, RufletValue)?
    let serviceContext = context(store: store) { observed = ($0, $1, $2) }

    let rejected = invoke(
      PageService(), type: "View", method: "confirm_pop",
      args: .map(["should_pop": .bool(false)]), node: view, context: serviceContext)
    XCTAssertEqual(try? rejected?.get(), .null)
    XCTAssertNil(observed)

    let accepted = invoke(
      PageService(), type: "View", method: "confirm_pop",
      args: .map(["should_pop": .bool(true)]), node: view, context: serviceContext)
    XCTAssertEqual(try? accepted?.get(), .null)
    XCTAssertEqual(observed?.0, RufletWireID.page)
    XCTAssertEqual(observed?.1, "view_pop")
    XCTAssertEqual(observed?.2, .map(["route": .string("/details")]))
  }

  @MainActor
  func testPageScrollToHandsTheExactFletCommandToTheMountedTopView() {
    let store = ControlStore()
    store.applyPageProperties([
      "views": .array([
        .map([RufletControlKey.id: .int(7), RufletControlKey.type: .string("View")])
      ])
    ])
    let serviceContext = context(store: store)
    let reply = invoke(
      PageService(), type: "Page", method: "scroll_to",
      args: .map([
        "offset": .double(-40), "delta": .null, "scroll_key": .null,
        "duration": .int(500), "curve": .string("ease_in"),
      ]),
      node: store.page,
      context: serviceContext)

    XCTAssertEqual(try? reply?.get(), .null)
    let command = store.page?.map("_scroll_command")
    XCTAssertEqual(command?["target_id"], .int(7))
    XCTAssertEqual(command?["offset"], .double(-40))
    XCTAssertEqual(command?["duration"], .int(500))
    XCTAssertEqual(command?["curve"], .string("ease_in"))
    XCTAssertFalse(command?["token"]?.stringValue?.isEmpty ?? true)
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

  }

  @MainActor
  func testFilePickerUploadExecutesAndReportsCanonicalFailureEvent() {
    var observed: (Int, String, RufletValue)?
    let node = ControlNode(
      id: 9, type: "FilePicker", props: ["on_upload": .bool(true)])
    let reply = invoke(
      FilePickerService(), type: "FilePicker", method: "upload",
      args: .map(["files": .array([
        .map([
          "name": .string("missing.txt"),
          "upload_url": .string("https://example.invalid/upload"),
          "method": .string("PUT")
        ])
      ])]),
      node: node,
      context: context { observed = ($0, $1, $2) })

    XCTAssertEqual(try? reply?.get(), .null)
    XCTAssertEqual(observed?.0, node.id)
    XCTAssertEqual(observed?.1, "upload")
    XCTAssertEqual(observed?.2["file_name"]?.stringValue, "missing.txt")
    XCTAssertNotNil(observed?.2["error"]?.stringValue)
  }

  @MainActor
  func testRemainingPushServicesAreActivatedByDefaultRegistry() {
    let registry = ServiceRegistry()
    registry.registerDefaults()
    registry.register(extension: RufletSecureStorage.self)
    let store = ControlStore()
    let nodes = [
      ControlNode(id: 1, type: "Page", props: ["on_locale_change": .bool(true)]),
      ControlNode(id: 2, type: "SecureStorage", props: ["on_change": .bool(true)]),
      ControlNode(
        id: 3, type: "ScreenBrightness",
        props: ["on_system_screen_brightness_change": .bool(true)])
    ]
    for node in nodes {
      let properties = node.props.map { ControlPatch.Operation.set(key: $0.key, value: $0.value) }
      store.apply(
        ControlPatch(
          controlID: node.id,
          operations: [.set(key: RufletControlKey.type, value: .string(node.type))] + properties))
    }

    registry.activateStreamingServices(in: store, context: context(store: store))

    XCTAssertTrue(registry.service(for: nodes[0]) is PageService)
    XCTAssertTrue(registry.service(for: nodes[1]) is SecureStorageService)
    XCTAssertTrue(registry.service(for: nodes[2]) is ScreenBrightnessService)
  }

  @MainActor
  func testConnectivityResultUsesFletListShape() {
    let reply = invoke(ConnectivityService(), type: "Connectivity", method: "get_connectivity")
    let values = try? reply?.get().arrayValue
    XCTAssertEqual(values?.count, 1)
    XCTAssertNotNil(values?.first?.stringValue)
  }

  func testDeviceServiceWireSemanticsMatchVendoredFletAdapters() {
    XCTAssertEqual(
      FletDeviceServiceSemantics.connectivityNames(
        wifi: true, mobile: true, ethernet: false, vpn: false, satisfied: true),
      ["wifi", "mobile"])
    XCTAssertEqual(
      FletDeviceServiceSemantics.connectivityNames(
        wifi: false, mobile: false, ethernet: false, vpn: false, satisfied: false),
      ["none"])
    XCTAssertEqual(
      FletDeviceServiceSemantics.connectivityNames(
        wifi: false, mobile: false, ethernet: false, vpn: false, satisfied: true),
      ["other"])

    XCTAssertEqual(
      try? FletDeviceServiceSemantics.requiredBool(.bool(false), name: "value"), false)
    XCTAssertThrowsError(try FletDeviceServiceSemantics.requiredBool(nil, name: "value"))
    XCTAssertEqual(try? FletDeviceServiceSemantics.validatedBrightness(.double(0.5)), 0.5)
    XCTAssertThrowsError(try FletDeviceServiceSemantics.validatedBrightness(.double(-0.1)))
    XCTAssertThrowsError(try FletDeviceServiceSemantics.validatedBrightness(.double(1.1)))
  }

  @MainActor
  func testCoreServiceWireShapesMatchVendoredFletAdapters() {
    XCTAssertEqual(FletCoreServiceSemantics.nullableString(nil), .null)
    XCTAssertEqual(FletCoreServiceSemantics.nullableString(""), .string(""))
    XCTAssertThrowsError(try FletCoreServiceSemantics.sharedPreferenceString(.int(1)))
    XCTAssertEqual(
      try? FletCoreServiceSemantics.sharedPreferenceString(.string("ruflet")), "ruflet")
    XCTAssertEqual(FletCoreServiceSemantics.imageBytes(.binary([0, 127, 255])), [0, 127, 255])
    XCTAssertEqual(FletCoreServiceSemantics.imageBytes(.array([.int(0), .int(255)])), [0, 255])
    XCTAssertNil(FletCoreServiceSemantics.imageBytes(.array([.int(256)])))
    XCTAssertNil(FletCoreServiceSemantics.imageBytes(.array([.string("1")])))
    XCTAssertTrue(
      FletCoreServiceSemantics.consoleLogPath()?.hasSuffix("/console.log") == true)

    let storage = StoragePathsService()
    for method in ["get_external_cache_directories", "get_external_storage_directories"] {
      let reply = invoke(storage, type: "StoragePaths", method: method)
      XCTAssertEqual(try? reply?.get(), .null, method)
    }
    let console = invoke(storage, type: "StoragePaths", method: "get_console_log_filename")
    XCTAssertTrue((try? console?.get().stringValue?.hasSuffix("/console.log")) == true)
  }

  @MainActor
  func testSharedPreferencesAcceptsOnlyFletStringValues() {
    let service = SharedPreferencesService()
    let key = "ruflet-parity-\(UUID().uuidString)"
    defer {
      _ = invoke(
        service, type: "SharedPreferences", method: "remove",
        args: .map(["key": .string(key)]))
    }

    let invalid = invoke(
      service, type: "SharedPreferences", method: "set",
      args: .map(["key": .string(key), "value": .int(7)]))
    guard case .failure(let error)? = invalid else {
      return XCTFail("non-string values must be rejected")
    }
    guard case .invalidArguments = error as? RufletServiceError else {
      return XCTFail("unexpected error: \(error)")
    }

    let set = invoke(
      service, type: "SharedPreferences", method: "set",
      args: .map(["key": .string(key), "value": .string("value")]))
    XCTAssertEqual(try? set?.get(), .bool(true))
    let get = invoke(
      service, type: "SharedPreferences", method: "get",
      args: .map(["key": .string(key)]))
    XCTAssertEqual(try? get?.get(), .string("value"))
  }

  @MainActor
  func testURLLauncherMatchesFletURLAndNativePopupSemantics() {
    XCTAssertEqual(
      FletURLLauncherSemantics.parseURL(.string("https://flet.dev"))?.url.absoluteString,
      "https://flet.dev")
    let parsed = FletURLLauncherSemantics.parseURL(.map([
      "url": .string("https://flet.dev/docs"), "target": .string("_blank")
    ]))
    XCTAssertEqual(parsed?.target, "_blank")
    XCTAssertEqual(
      FletURLLauncherSemantics.resolvedMode(.platformDefault, target: parsed?.target),
      .externalApplication)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "in_app_web_view"), .inAppWebView)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "not-a-mode"), .platformDefault)
    XCTAssertNil(FletURLLauncherSemantics.parseURL(.int(1)))

    // Flet's non-web platform adapter intentionally implements popup windows
    // as a no-op and returns void, rather than launching another browser.
    let popup = invoke(
      UrlLauncherService(), type: "UrlLauncher", method: "open_window",
      args: .map([
        "url": .string("https://flet.dev"), "title": .string("Flet popup"),
        "width": .int(480), "height": .int(640)
      ]))
    XCTAssertEqual(try? popup?.get(), .null)
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
