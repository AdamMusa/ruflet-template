import RufletProtocol
import XCTest

@testable import RufletEngine
@testable import RufletMedia

#if canImport(CoreLocation)
  import CoreLocation

  @testable import RufletLocation
#endif

/// Parity for the service controls' own properties, against the behaviour in
/// the vendored Flet Dart sources.
@MainActor
final class ServicePropertyParityTests: XCTestCase {

  // MARK: - Audio.on_position_change

  /// audio.dart reports whole seconds: `(position.inMilliseconds / 1000).round() * 1000`.
  func testPositionRoundsToWholeSeconds() {
    let report = AudioService.positionReport(
      rawMilliseconds: 1_600, lastReported: nil, durationMilliseconds: nil)
    XCTAssertEqual(report?.milliseconds, 2_000)
  }

  /// Flet starts from -1, so a first tick at zero still reports.
  func testFirstZeroPositionReports() {
    let report = AudioService.positionReport(
      rawMilliseconds: 0, lastReported: nil, durationMilliseconds: nil)
    XCTAssertEqual(report?.milliseconds, 0)
    XCTAssertEqual(report?.retained, 0)
  }

  /// A tick landing in a second already reported is dropped.
  func testRepeatedSecondIsSuppressed() {
    XCTAssertNil(
      AudioService.positionReport(
        rawMilliseconds: 2_100, lastReported: 2_000, durationMilliseconds: nil))
  }

  /// Flet lets the final tick through when the raw position has reached the
  /// duration exactly, even though it repeats the reported second.
  func testFinalTickAtExactDurationReports() {
    let report = AudioService.positionReport(
      rawMilliseconds: 2_100, lastReported: 2_000, durationMilliseconds: 2_100)
    XCTAssertEqual(report?.milliseconds, 2_000, "Flet reports the rounded second, not the duration")
    XCTAssertEqual(report?.retained, 2_100, "but remembers the exact duration")
  }

  /// A duration that does not match the raw position leaves the tick dropped.
  func testDurationMismatchStaysSuppressed() {
    XCTAssertNil(
      AudioService.positionReport(
        rawMilliseconds: 2_100, lastReported: 2_000, durationMilliseconds: 9_000))
  }

  // MARK: - Audio.release_mode

  /// audioplayers' AudioPlayer defaults to ReleaseMode.release, and Flet leaves
  /// that default in place when the control does not set the property.
  func testReleaseModeDefaultsToRelease() {
    XCTAssertEqual(AudioService.releaseMode(nil), .release)
    XCTAssertEqual(AudioService.releaseMode("nonsense"), .release)
  }

  func testReleaseModeParsesCaseInsensitively() {
    XCTAssertEqual(AudioService.releaseMode("loop"), .loop)
    XCTAssertEqual(AudioService.releaseMode("LOOP"), .loop)
    XCTAssertEqual(AudioService.releaseMode("Stop"), .stop)
  }

  // MARK: - SecureStorage.ios_options / macos_options

  /// flutter_secure_storage's KeychainAccessibility defaults to `unlocked`.
  func testKeychainAccessibilityDefaults() {
    XCTAssertEqual(
      SecureStorageService.accessibility(nil), kSecAttrAccessibleWhenUnlocked)
    XCTAssertEqual(
      SecureStorageService.accessibility("unlocked"), kSecAttrAccessibleWhenUnlocked)
  }

  func testKeychainAccessibilityMapsEveryFletName() {
    XCTAssertEqual(
      SecureStorageService.accessibility("passcode"),
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
    XCTAssertEqual(
      SecureStorageService.accessibility("unlocked_this_device"),
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    XCTAssertEqual(
      SecureStorageService.accessibility("first_unlock"),
      kSecAttrAccessibleAfterFirstUnlock)
    XCTAssertEqual(
      SecureStorageService.accessibility("first_unlock_this_device"),
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
  }

  // MARK: - Geolocator.configuration

  #if canImport(CoreLocation)
    /// geolocator's LocationAccuracy defaults to `best`.
    func testLocationAccuracyDefaultsToBest() {
      XCTAssertEqual(GeolocatorService.accuracy(nil), kCLLocationAccuracyBest)
      XCTAssertEqual(GeolocatorService.accuracy("unknown"), kCLLocationAccuracyBest)
    }

    func testLocationAccuracyMapsFletNames() {
      XCTAssertEqual(GeolocatorService.accuracy("lowest"), kCLLocationAccuracyThreeKilometers)
      XCTAssertEqual(GeolocatorService.accuracy("low"), kCLLocationAccuracyKilometer)
      XCTAssertEqual(GeolocatorService.accuracy("medium"), kCLLocationAccuracyHundredMeters)
      XCTAssertEqual(GeolocatorService.accuracy("high"), kCLLocationAccuracyNearestTenMeters)
      XCTAssertEqual(
        GeolocatorService.accuracy("best_for_navigation"), kCLLocationAccuracyBestForNavigation)
      XCTAssertEqual(GeolocatorService.accuracy("reduced"), kCLLocationAccuracyReduced)
    }
  #endif
}
