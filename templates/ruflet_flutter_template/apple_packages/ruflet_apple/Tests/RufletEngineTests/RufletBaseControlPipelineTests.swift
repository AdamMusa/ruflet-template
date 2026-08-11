import XCTest
@testable import RufletUI

final class RufletBaseControlPipelineTests: XCTestCase {
  func testNativeLayoutWrapperOrderMatchesPinnedFletLayoutControl() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletUI/Support/CommonModifiers.swift")
    let source = try String(contentsOf: sourceURL)
    let bodyStart = try XCTUnwrap(source.range(of: "func body(content: Content) -> some View {"))
    let bodyEnd = try XCTUnwrap(
      source.range(of: "\n  }\n}\n\n/// Constructor defaults", range: bodyStart.upperBound..<source.endIndex))
    let body = String(source[bodyStart.lowerBound..<bodyEnd.lowerBound])

    let wrappers = [
      "RufletOpacityModifier", "RufletTooltipModifier", "RufletDirectionalityModifier",
      "RufletFixedSizeModifier", "RufletRotationModifier", "RufletScaleModifier",
      "RufletOffsetModifier", "RufletAspectRatioModifier", "RufletAlignmentModifier",
      "RufletMarginModifier", "RufletSizeChangeModifier", "RufletExpandModifier",
    ]

    var cursor = body.startIndex
    for wrapper in wrappers {
      let range = try XCTUnwrap(body.range(of: wrapper, range: cursor..<body.endIndex))
      cursor = range.upperBound
    }
  }

  func testSizeChangeIntervalMatchesFletLayoutControlDefault() {
    XCTAssertEqual(RufletBaseControlDefaults.sizeChangeIntervalMilliseconds, 10)
  }

  func testAnimationDurationUsesTheSameMillisecondsAsFlet() {
    XCTAssertEqual(ControlProps.animationDurationSeconds(.int(250)), 0.25)
    XCTAssertEqual(
      ControlProps.animationDurationSeconds(.map(["duration": .double(400)])), 0.4)
    XCTAssertNil(ControlProps.animationDurationSeconds(nil))
  }

  func testNativePipelineDoesNotForceLTRWhenRtlIsAbsent() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletUI/Support/CommonModifiers.swift")
    let source = try String(contentsOf: sourceURL)

    XCTAssertFalse(source.contains("false) ? .rightToLeft : .leftToRight"))
  }
}
