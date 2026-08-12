import XCTest

final class SemanticsContentResidualTests: XCTestCase {
  private func source(_ relativePath: String) throws -> String {
    let package = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return try String(contentsOf: package.appendingPathComponent(relativePath))
  }

  func testPinnedFletSemanticsDoesNotBuildAContentSlot() throws {
    let source = try source(
      "../../flet_packages/flet/lib/src/controls/semantics.dart")
    XCTAssertFalse(source.contains("buildWidget(\"content\")"))
  }

  func testNativeSemanticsDoesNotRenderAnInventedContentSlot() throws {
    let source = try source("Sources/RufletUI/Controls/WrapperControls.swift")
    let start = try XCTUnwrap(source.range(of: "struct SemanticsControlView"))
    let end = try XCTUnwrap(
      source.range(of: "/// `MergeSemantics`", range: start.upperBound..<source.endIndex))
    let semantics = source[start.lowerBound..<end.lowerBound]

    XCTAssertFalse(semantics.contains("controlID(forKey: \"content\")"))
    XCTAssertFalse(semantics.contains("ControlView(id:"))
    XCTAssertTrue(semantics.contains("EmptyView()"))
  }
}
