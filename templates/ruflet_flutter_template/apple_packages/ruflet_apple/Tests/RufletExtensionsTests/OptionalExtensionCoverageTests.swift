import RufletAds
import RufletAudio
import RufletAudioRecorder
import RufletCamera
import RufletCharts
import RufletCodeEditor
import RufletColorPickers
import RufletDataTable2
import RufletEngine
import RufletFlashlight
import RufletGeolocator
import RufletLottie
import RufletMap
import RufletPermissionHandler
import RufletRive
import RufletSecureStorage
import RufletSpinKit
import RufletVideo
import RufletWebView
import XCTest

@MainActor
final class OptionalExtensionCoverageTests: XCTestCase {
  func testEveryOptionalExtensionDeclaresExactNativeControlCoverage() {
    assertCoverage(
      RufletAds.Extension(),
      views: adsViewTypes,
      services: adsServiceTypes)
    assertCoverage(
      RufletAudioExtension(), views: [], services: RufletAudio.controlTypes)
    assertCoverage(
      RufletAudioRecorderExtension(), views: [], services: RufletAudioRecorder.controlTypes)
    assertCoverage(
      RufletCameraExtension(), views: RufletCamera.controlTypes, services: [])
    assertCoverage(
      RufletChartsExtension(), views: RufletCharts.controlTypes, services: [])
    assertCoverage(
      RufletCodeEditorExtension(), views: RufletCodeEditor.controlTypes, services: [])
    assertCoverage(
      RufletColorPickersExtension(), views: RufletColorPickers.controlTypes, services: [])
    assertCoverage(
      RufletDataTable2Extension(), views: RufletDataTable2.controlTypes, services: [])
    assertCoverage(
      RufletFlashlightExtension(), views: [], services: RufletFlashlight.controlTypes)
    assertCoverage(
      RufletGeolocatorExtension(), views: [], services: RufletGeolocator.controlTypes)
    assertCoverage(
      RufletLottieExtension(), views: RufletLottie.controlTypes, services: [])
    assertCoverage(
      RufletMap.Extension(), views: RufletMapPackage.renderedControlTypes, services: [])
    assertCoverage(
      RufletPermissionHandlerExtension(), views: [], services: RufletPermissionHandler.controlTypes)
    assertCoverage(
      RufletRiveExtension(), views: RufletRive.controlTypes, services: [])
    assertCoverage(
      RufletSecureStorageExtension(), views: [], services: RufletSecureStorage.controlTypes)
    assertCoverage(
      RufletSpinKitExtension(), views: RufletSpinKit.controlTypes, services: [])
    assertCoverage(
      RufletVideoExtension(), views: RufletVideo.controlTypes, services: [])
    assertCoverage(
      RufletWebViewExtension(), views: RufletWebView.controlTypes, services: [])
  }

  func testOptionalExtensionCoverageHasNoViewServiceAmbiguity() {
    let extensions: [any RufletExtension] = [
      RufletAds.Extension(),
      RufletAudioExtension(),
      RufletAudioRecorderExtension(),
      RufletCameraExtension(),
      RufletChartsExtension(),
      RufletCodeEditorExtension(),
      RufletColorPickersExtension(),
      RufletDataTable2Extension(),
      RufletFlashlightExtension(),
      RufletGeolocatorExtension(),
      RufletLottieExtension(),
      RufletMap.Extension(),
      RufletPermissionHandlerExtension(),
      RufletRiveExtension(),
      RufletSecureStorageExtension(),
      RufletSpinKitExtension(),
      RufletVideoExtension(),
      RufletWebViewExtension(),
    ]
    let registry = RufletExtensionRegistry(extensions)
    XCTAssertTrue(registry.renderedControlTypes.isDisjoint(with: registry.serviceControlTypes))
    XCTAssertEqual(registry.renderedControlTypes.count, expectedViewCount)
    XCTAssertEqual(registry.serviceControlTypes.count, expectedServiceCount)
  }

  private func assertCoverage(
    _ item: any RufletExtension,
    views: Set<String>,
    services: Set<String>,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(item.renderedControlTypes, views, file: file, line: line)
    XCTAssertEqual(item.serviceControlTypes, services, file: file, line: line)
  }

  private var adsViewTypes: Set<String> {
    #if os(iOS)
    [RufletAdsPackage.bannerType]
    #else
    []
    #endif
  }

  private var adsServiceTypes: Set<String> {
    #if os(iOS)
    [RufletAdsPackage.interstitialType]
    #else
    []
    #endif
  }

  private var expectedViewCount: Int {
    #if os(iOS)
    58
    #else
    57
    #endif
  }

  private var expectedServiceCount: Int {
    #if os(iOS)
    7
    #else
    6
    #endif
  }
}
