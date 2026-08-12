import XCTest
@testable import RufletUI

final class ScrollContractParityTests: XCTestCase {
  private let metrics = RufletScrollMetrics(
    pixels: 20,
    minScrollExtent: 0,
    maxScrollExtent: 80,
    viewportDimension: 40)

  func testAllFletNotificationKindsCarryExactConditionalFields() {
    let start = RufletScrollContract.payload(kind: .start, metrics: metrics).mapValue
    XCTAssertEqual(start?["event_type"], .string("start"))
    XCTAssertEqual(start?["pixels"], .double(20))
    XCTAssertEqual(start?["min_scroll_extent"], .double(0))
    XCTAssertEqual(start?["max_scroll_extent"], .double(80))
    XCTAssertEqual(start?["viewport_dimension"], .double(40))
    XCTAssertNil(start?["scroll_delta"])

    let update = RufletScrollContract.payload(
      kind: .update, metrics: metrics, scrollDelta: -3).mapValue
    XCTAssertEqual(update?["event_type"], .string("update"))
    XCTAssertEqual(update?["scroll_delta"], .double(-3))

    let user = RufletScrollContract.payload(
      kind: .user, metrics: metrics, direction: .forward).mapValue
    XCTAssertEqual(user?["event_type"], .string("user"))
    XCTAssertEqual(user?["direction"], .string("forward"))

    let overscroll = RufletScrollContract.payload(
      kind: .overscroll, metrics: metrics, overscroll: 4, velocity: 125).mapValue
    XCTAssertEqual(overscroll?["event_type"], .string("overscroll"))
    XCTAssertEqual(overscroll?["overscroll"], .double(4))
    XCTAssertEqual(overscroll?["velocity"], .double(125))

    let end = RufletScrollContract.payload(kind: .end, metrics: metrics).mapValue
    XCTAssertEqual(end?["event_type"], .string("end"))
    XCTAssertNil(end?["direction"])
  }

  func testUpdateIncludesNullDeltaLikeFletWhenNativeDeltaIsUnavailable() {
    XCTAssertEqual(
      RufletScrollContract.payload(kind: .update, metrics: metrics)
        .mapValue?["scroll_delta"],
      .null)
  }

  func testSampleResolutionKeepsMetricsBoundedAndExposesSignedOverscroll() {
    let leading = RufletScrollSampleContract.resolve(
      rawPixels: -6, contentExtent: 120, viewportDimension: 40)
    XCTAssertEqual(leading.metrics.pixels, 0)
    XCTAssertEqual(leading.metrics.maxScrollExtent, 80)
    XCTAssertEqual(leading.overscroll, -6)

    let trailing = RufletScrollSampleContract.resolve(
      rawPixels: 87, contentExtent: 120, viewportDimension: 40)
    XCTAssertEqual(trailing.metrics.pixels, 80)
    XCTAssertEqual(trailing.overscroll, 7)
  }

  func testDirectionNamesMatchFlutterScrollDirection() {
    XCTAssertEqual(RufletScrollContract.direction(for: -1), .forward)
    XCTAssertEqual(RufletScrollContract.direction(for: 1), .reverse)
    XCTAssertEqual(RufletScrollContract.direction(for: 0), .idle)
  }

  func testThrottleUsesFletInclusiveIntervalPerNotificationKind() {
    let previous = Date(timeIntervalSince1970: 100)
    XCTAssertFalse(RufletScrollContract.shouldEmit(
      previous: previous,
      now: previous.addingTimeInterval(0.010),
      intervalMilliseconds: 10))
    XCTAssertTrue(RufletScrollContract.shouldEmit(
      previous: previous,
      now: previous.addingTimeInterval(0.011),
      intervalMilliseconds: 10))
    XCTAssertTrue(RufletScrollContract.shouldEmit(
      previous: nil,
      now: previous,
      intervalMilliseconds: 10))
  }

  func testDefaultIntervalAndVelocityMatchFletUnits() {
    XCTAssertEqual(RufletScrollContract.defaultIntervalMilliseconds, 10)
    XCTAssertEqual(RufletScrollContract.velocity(delta: 5, elapsed: 0.02), 250)
    XCTAssertEqual(RufletScrollContract.velocity(delta: 5, elapsed: 0), 0)
  }
}
