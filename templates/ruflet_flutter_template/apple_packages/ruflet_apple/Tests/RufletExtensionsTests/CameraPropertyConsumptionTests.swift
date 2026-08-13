import XCTest

@testable import RufletCamera

final class CameraPropertyConsumptionTests: XCTestCase {
  func testPreviewConsumesPinnedContentInsideLayoutControl() throws {
    let source = try String(contentsOf: sourceURL(), encoding: .utf8)

    XCTAssertTrue(source.contains("LayoutControl(control: control)"))
    XCTAssertTrue(source.contains("control.buildWidget(\"content\", notifyParent: true)"))
    XCTAssertTrue(source.contains("control.boolean(\"preview_enabled\", default: true)"))
  }

  private func sourceURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletExtensions/RufletCamera/Sources/Extension.swift")
  }
}
