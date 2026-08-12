import Foundation
import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class ScreenshotParityTests: XCTestCase {
  private func call(_ args: [String: RufletValue] = [:], name: String = "capture")
    -> RufletMethodCall
  {
    RufletMethodCall(controlID: 7, callID: "shot", name: name, args: .map(args))
  }

  func testContentIsRequiredAndMustResolveToAVisibleControl() {
    XCTAssertEqual(
      RufletScreenshotSemantics.validationError(contentID: nil, contentIsVisible: false),
      "Screenshot.content must be provided and visible")
    XCTAssertEqual(
      RufletScreenshotSemantics.validationError(contentID: 2, contentIsVisible: false),
      "Screenshot.content must be provided and visible")
    XCTAssertNil(RufletScreenshotSemantics.validationError(
      contentID: 2, contentIsVisible: true))
  }

  func testCaptureDefaultsToFletsTwentyMillisecondDelayAndDeviceScale() {
    let request = RufletScreenshotCaptureRequest(call: call([
      "delay": .null, "pixel_ratio": .null,
    ]))
    XCTAssertEqual(request.delayMilliseconds, 20)
    XCTAssertNil(request.pixelRatio)
  }

  func testCaptureAcceptsScalarAndComponentDurationArguments() {
    XCTAssertEqual(
      RufletScreenshotCaptureRequest(call: call(["delay": .int(125)])).delayMilliseconds,
      125)
    XCTAssertEqual(
      RufletScreenshotCaptureRequest(call: call(["delay": .double(12.9)]))
        .delayMilliseconds,
      0)
    XCTAssertEqual(
      RufletScreenshotCaptureRequest(call: call(["delay": .map([
        "seconds": .int(1),
        "milliseconds": .int(250),
        "microseconds": .int(500),
      ])])).delayMilliseconds,
      1_250.5)
    XCTAssertEqual(
      RufletScreenshotCaptureRequest(call: call([
        "delay": .extended(type: 3, string: "250000"),
      ])).delayMilliseconds,
      250)
  }

  func testCapturePreservesExplicitPixelRatio() {
    let request = RufletScreenshotCaptureRequest(call: call(["pixel_ratio": .double(2.5)]))
    XCTAssertEqual(request.pixelRatio, 2.5)
  }

  func testCaptureReturnsRawPNGAsBinaryWireValue() throws {
    let png = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    let result = RufletScreenshotSemantics.captureResult(pngData: png)
    XCTAssertEqual(try result.get(), .binary([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  }

  func testOnlyCaptureIsAValidScreenshotCommand() {
    XCTAssertNil(RufletScreenshotSemantics.commandError("capture"))
    XCTAssertEqual(
      RufletScreenshotSemantics.commandError("clear"),
      .unsupportedMethod(type: "Screenshot", method: "clear"))
  }

  func testRasterizationFailureCompletesWithTheNativeCaptureError() {
    let result = RufletScreenshotSemantics.captureResult(pngData: nil)
    guard case .failure(let error) = result,
      let serviceError = error as? RufletServiceError
    else { return XCTFail("Expected a RufletServiceError") }
    XCTAssertEqual(serviceError, .failed("The view could not be rasterised"))
  }

  func testAvailabilityErrorRemainsSpecificToImageRenderer() {
    XCTAssertEqual(
      RufletScreenshotSemantics.availabilityError,
      "Screenshot capture needs iOS 16 / macOS 13")
  }
}
