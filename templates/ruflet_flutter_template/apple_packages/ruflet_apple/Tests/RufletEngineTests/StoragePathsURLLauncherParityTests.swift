import RufletEngine
import RufletProtocol
import XCTest

final class StoragePathsURLLauncherParityTests: XCTestCase {
  @MainActor
  private func invoke(
    _ service: RufletService,
    method: String,
    args: RufletValue = .map([:])
  ) -> Result<RufletValue, Error>? {
    var result: Result<RufletValue, Error>?
    let context = RufletServiceContext(store: ControlStore()) { _, _, _ in }
    service.invoke(
      RufletMethodCall(controlID: 1, callID: "test", name: method, args: args),
      node: nil,
      context: context
    ) { result = $0 }
    return result
  }

  func testStorageDirectoryMappingMatchesPathProviderFoundation() {
    let cache = FletStoragePathsSemantics.path(
      for: .applicationCache, bundleIdentifier: "dev.ruflet.tests")
    let baseCache = FletStoragePathsSemantics.path(
      for: .applicationCache, bundleIdentifier: nil)
    let temporary = FletStoragePathsSemantics.path(
      for: .temporary, bundleIdentifier: "dev.ruflet.tests")
    XCTAssertNotNil(cache)
    XCTAssertEqual(temporary, baseCache)
    XCTAssertTrue(FletStoragePathsSemantics.createsDirectory(.applicationCache))
    XCTAssertTrue(FletStoragePathsSemantics.createsDirectory(.applicationSupport))
    XCTAssertFalse(FletStoragePathsSemantics.createsDirectory(.applicationDocuments))
    XCTAssertFalse(FletStoragePathsSemantics.createsDirectory(.downloads))

    #if os(macOS)
      XCTAssertTrue(cache?.path.hasSuffix("/dev.ruflet.tests") == true)
      XCTAssertTrue(
        FletStoragePathsSemantics.path(
          for: .applicationSupport, bundleIdentifier: "dev.ruflet.tests")?
          .path.hasSuffix("/dev.ruflet.tests") == true)
      XCTAssertFalse(
        FletStoragePathsSemantics.path(
          for: .applicationDocuments, bundleIdentifier: "dev.ruflet.tests")?
          .path.hasSuffix("/dev.ruflet.tests") == true)
    #endif
  }

  @MainActor
  func testStorageServiceUsesCacheForTemporaryAndNullForAndroidOnlyPaths() throws {
    let service = StoragePathsService()
    let cache = try XCTUnwrap(
      invoke(
        service, method: "get_application_cache_directory")?.get().stringValue)
    let temporary = try XCTUnwrap(
      invoke(
        service, method: "get_temporary_directory")?.get().stringValue)
    #if os(macOS)
      XCTAssertEqual(URL(fileURLWithPath: cache).deletingLastPathComponent().path, temporary)
    #else
      XCTAssertEqual(temporary, cache)
    #endif

    for method in [
      "get_external_cache_directories",
      "get_external_storage_directories",
      "get_external_storage_directory",
    ] {
      XCTAssertEqual(try invoke(service, method: method)?.get(), .null, method)
    }

    let console = try XCTUnwrap(
      invoke(
        service, method: "get_console_log_filename")?.get().stringValue)
    XCTAssertEqual(
      console,
      URL(fileURLWithPath: cache)
        .appendingPathComponent("console.log").path)
  }

  func testLaunchModesAcceptCanonicalFletValuesAndLegacyAliases() {
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "platformDefault"), .platformDefault)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "inAppWebView"), .inAppWebView)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "inAppBrowserView"), .inAppBrowserView)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "externalApplication"),
      .externalApplication)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "externalNonBrowserApplication"),
      .externalNonBrowserApplication)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "in_app_web_view"), .inAppWebView)
    XCTAssertEqual(
      FletURLLauncherSemantics.Mode(wireValue: "unknown"), .platformDefault)
  }

  func testURLTargetsModesAndAppleCapabilitiesMatchPinnedLauncher() throws {
    let url = try XCTUnwrap(
      FletURLLauncherSemantics.parseURL(
        .map([
          "url": .string("https://flet.dev"),
          "target": .string("_blank"),
        ])))
    XCTAssertEqual(
      FletURLLauncherSemantics.resolvedMode(.platformDefault, target: url.target),
      .externalApplication)
    XCTAssertEqual(
      FletURLLauncherSemantics.nativeMode(
        .platformDefault, url: url.url, platform: .iOS),
      .inAppBrowserView)
    XCTAssertEqual(
      FletURLLauncherSemantics.nativeMode(
        .platformDefault, url: URL(string: "mailto:hello@flet.dev")!, platform: .iOS),
      .externalApplication)

    for mode in FletURLLauncherSemantics.Mode.allCases {
      XCTAssertTrue(FletURLLauncherSemantics.supportsLaunch(mode, platform: .iOS))
      // url_launcher 6.3.2 routes the close query through supportsMode.
      XCTAssertTrue(FletURLLauncherSemantics.supportsClose(mode, platform: .iOS))
    }
    XCTAssertTrue(
      FletURLLauncherSemantics.supportsLaunch(
        .platformDefault, platform: .macOS))
    XCTAssertTrue(
      FletURLLauncherSemantics.supportsLaunch(
        .externalApplication, platform: .macOS))
    XCTAssertFalse(
      FletURLLauncherSemantics.supportsLaunch(
        .inAppBrowserView, platform: .macOS))
    XCTAssertFalse(
      FletURLLauncherSemantics.supportsLaunch(
        .externalNonBrowserApplication, platform: .macOS))
    XCTAssertEqual(
      FletURLLauncherSemantics.supportsClose(.externalApplication, platform: .macOS),
      FletURLLauncherSemantics.supportsLaunch(.externalApplication, platform: .macOS))
  }

  @MainActor
  func testURLServiceUsesWebWindowFallbackAndRejectsNonHTTPInAppURLs() {
    let targetMode = FletURLLauncherSemantics.resolvedMode(
      .platformDefault, target: "_blank")
    XCTAssertEqual(targetMode, .externalApplication)

    let result = invoke(
      UrlLauncherService(),
      method: "launch_url",
      args: .map([
        "url": .string("mailto:hello@flet.dev"),
        "mode": .string("inAppWebView"),
        "web_only_window_name": .string("_blank"),
      ]))
    guard case .failure(let error)? = result else {
      return XCTFail("non-http in-app launches must fail before native presentation")
    }
    guard case .invalidArguments = error as? RufletServiceError else {
      return XCTFail("unexpected error: \(error)")
    }
  }
}
