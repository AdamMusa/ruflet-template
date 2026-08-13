import Foundation
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class RufletCaptureWindowInvariantTests: XCTestCase {
  func testScreenshotCaptureRequestUsesPinnedDefaults() throws {
    let request = try RufletScreenshotCaptureRequest(arguments: [:])

    XCTAssertEqual(request.delay, 0.02, accuracy: 0.000_001)
    XCTAssertNil(request.pixelRatio)
  }

  func testScreenshotCaptureRequestPreservesTemporalDelayAndPixelRatio() throws {
    let request = try RufletScreenshotCaptureRequest(
      arguments: [
        "delay": rufletDurationValue(0.035),
        "pixel_ratio": 2.5,
      ])

    XCTAssertEqual(request.delay, 0.035, accuracy: 0.000_001)
    XCTAssertEqual(request.pixelRatio, 2.5)
  }

  func testScreenshotCaptureRejectsNonPositivePixelRatio() {
    XCTAssertThrowsError(
      try RufletScreenshotCaptureRequest(arguments: ["pixel_ratio": 0]))
  }

  func testScreenshotCaptureCoordinatorReturnsExactPNGBytesAtRequestedScale() {
    let coordinator = RufletScreenshotCaptureCoordinator()
    let expected = Data([0x89, 0x50, 0x4E, 0x47])
    var capturedRatio: CGFloat?
    coordinator.install { ratio in
      capturedRatio = ratio
      return expected
    }

    XCTAssertEqual(coordinator.capture(pixelRatio: 3), expected)
    XCTAssertEqual(capturedRatio, 3)
  }

  func testWindowDoubleTapActionNamesMatchPinnedContract() {
    XCTAssertEqual(rufletWindowToggleAction(wasMaximized: false), "maximize")
    XCTAssertEqual(rufletWindowToggleAction(wasMaximized: true), "unmaximize")
  }
}
