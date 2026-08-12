import XCTest

import RufletEngine
@testable import RufletMotion
import RufletProtocol

final class ShakeDetectorParityTests: XCTestCase {
  func testPinnedFletDefaultsAndSamplingInterval() {
    XCTAssertEqual(
      FletShakeDetectorSemantics.Configuration.defaults,
      .init(
        minimumCount: 1, slopMilliseconds: 500, resetMilliseconds: 3_000,
        threshold: 2.7))
    XCTAssertEqual(FletShakeDetectorSemantics.samplingIntervalSeconds, 0.2)
  }

  func testThresholdIsStrictAndUsesSensorsPlusGravityConversion() {
    let configuration = FletShakeDetectorSemantics.Configuration.defaults
    var below = FletShakeDetectorSemantics.State(timestampMilliseconds: 0, count: 0)
    XCTAssertFalse(FletShakeDetectorSemantics.consume(
      x: 2.69, y: 0, z: 0, nowMilliseconds: 500,
      configuration: configuration, state: &below))

    var above = FletShakeDetectorSemantics.State(timestampMilliseconds: 0, count: 0)
    XCTAssertTrue(FletShakeDetectorSemantics.consume(
      x: 2.7, y: 0, z: 0, nowMilliseconds: 500,
      configuration: configuration, state: &above))
  }

  func testSlopBoundaryIsAcceptedButEarlierSampleIsRejected() {
    let configuration = FletShakeDetectorSemantics.Configuration.defaults
    var state = FletShakeDetectorSemantics.State(timestampMilliseconds: 1_000, count: 0)
    XCTAssertFalse(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 1_499,
      configuration: configuration, state: &state))
    XCTAssertTrue(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 1_500,
      configuration: configuration, state: &state))
  }

  func testCountResetsOnlyAfterStrictResetWindow() {
    let configuration = FletShakeDetectorSemantics.Configuration(
      minimumCount: 2, slopMilliseconds: 500, resetMilliseconds: 3_000, threshold: 2.7)
    var state = FletShakeDetectorSemantics.State(timestampMilliseconds: 0, count: 1)
    XCTAssertTrue(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 3_000,
      configuration: configuration, state: &state))
    XCTAssertEqual(state.count, 2)

    XCTAssertFalse(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 6_001,
      configuration: configuration, state: &state))
    XCTAssertEqual(state.count, 1)
  }

  func testCountRemainsAccumulatedAfterEvent() {
    let configuration = FletShakeDetectorSemantics.Configuration(
      minimumCount: 2, slopMilliseconds: 0, resetMilliseconds: 3_000, threshold: 2.7)
    var state = FletShakeDetectorSemantics.State(timestampMilliseconds: 0, count: 0)
    XCTAssertFalse(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 1,
      configuration: configuration, state: &state))
    XCTAssertTrue(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 2,
      configuration: configuration, state: &state))
    XCTAssertTrue(FletShakeDetectorSemantics.consume(
      x: 3, y: 0, z: 0, nowMilliseconds: 3,
      configuration: configuration, state: &state))
    XCTAssertEqual(state.count, 3)
  }

  func testFletDoesNotClampUnusualConfigurationValues() {
    let configuration = FletShakeDetectorSemantics.Configuration(
      minimumCount: 0, slopMilliseconds: -1, resetMilliseconds: -1, threshold: -1)
    var state = FletShakeDetectorSemantics.State(timestampMilliseconds: 100, count: 4)
    XCTAssertTrue(FletShakeDetectorSemantics.consume(
      x: 0, y: 0, z: 0, nowMilliseconds: 100,
      configuration: configuration, state: &state))
    XCTAssertEqual(state.count, 1)
  }

  @MainActor
  func testServiceIsStreamingAndHasNoImperativeCommands() {
    let service: any RufletStreamingService = ShakeDetectorService()
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 1, callID: "test", name: "reset", args: .map([:])),
      node: ControlNode(id: 1, type: "ShakeDetector"),
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { result = $0 }
    XCTAssertThrowsError(try result?.get())
  }
}
