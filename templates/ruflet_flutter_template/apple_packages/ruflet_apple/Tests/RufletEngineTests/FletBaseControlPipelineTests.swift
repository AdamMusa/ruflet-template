import XCTest
@testable import RufletUI

final class FletBaseControlPipelineTests: XCTestCase {
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
      "FletOpacityModifier", "FletTooltipModifier", "FletDirectionalityModifier",
      "FletFixedSizeModifier", "FletRotationModifier", "FletScaleModifier",
      "FletOffsetModifier", "FletAspectRatioModifier", "FletAlignmentModifier",
      "FletMarginModifier", "FletSizeChangeModifier", "FletExpandModifier",
    ]

    var cursor = body.startIndex
    for wrapper in wrappers {
      let range = try XCTUnwrap(body.range(of: wrapper, range: cursor..<body.endIndex))
      cursor = range.upperBound
    }
  }

  func testSizeChangeIntervalMatchesFletLayoutControlDefault() {
    XCTAssertEqual(FletBaseControlDefaults.sizeChangeIntervalMilliseconds, 10)
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
