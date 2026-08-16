import Foundation
@testable import RufletLottie
import XCTest

final class LottiePropertyTests: XCTestCase {
  func testMergePathOptionPreservesOrDisablesMergeOperators() throws {
    let source = Data(#"{"layers":[{"shapes":[{"ty":"rc"},{"ty":"mm","mm":1}]}]}"#.utf8)

    XCTAssertEqual(rufletLottieData(source, enableMergePaths: true), source)

    let disabled = try XCTUnwrap(
      JSONSerialization.jsonObject(with: rufletLottieData(source, enableMergePaths: false))
        as? [String: Any])
    let layers = try XCTUnwrap(disabled["layers"] as? [[String: Any]])
    let shapes = try XCTUnwrap(layers.first?["shapes"] as? [[String: Any]])
    XCTAssertEqual(shapes.compactMap { $0["ty"] as? String }, ["rc"])
  }

  func testInvalidLottiePayloadIsLeftForDecoderToReport() {
    let source = Data([0x00, 0x01, 0x02])
    XCTAssertEqual(rufletLottieData(source, enableMergePaths: false), source)
  }
}
