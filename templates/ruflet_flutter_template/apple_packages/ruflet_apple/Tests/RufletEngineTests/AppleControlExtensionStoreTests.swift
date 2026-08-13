import CoreGraphics
import Foundation
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class AppleControlExtensionStoreTests: XCTestCase {
  func testControlExtensionClassifiesPinnedContentFormsAndInternals() {
    let backend = RufletBackend(pageURL: URL(string: "ws://127.0.0.1:8550")!, assetsDirectory: "")
    let control = RufletControl(
      id: 20,
      type: "Test",
      properties: [
        "label": "Ruflet",
        "icon": 42,
        "content": ["_c": "Text", "_i": 21, "value": "Child"],
        "_internals": ["skip_properties": ["color"]],
      ],
      backend: backend)

    XCTAssertEqual(control.propertyContent("label"), .text("Ruflet"))
    XCTAssertEqual(control.propertyContent("icon"), .icon(42))
    XCTAssertEqual(control.propertyContent("content"), .control)
    XCTAssertEqual(control.propertyContent("missing"), .unsupported)
    XCTAssertEqual(
      control.internalConfiguration?["skip_properties"]?.array,
      [.string("color")])
  }

  func testPageSizeStoreSelectionMatchesPinnedSelectorShape() {
    let selected = RufletPageSizeStoreView<EmptyView>.selection(
      size: CGSize(width: 834, height: 1194),
      breakpoints: ["sm": 576, "md": 768])
    XCTAssertEqual(selected.size, CGSize(width: 834, height: 1194))
    XCTAssertEqual(selected.breakpoints["sm"], 576)
    XCTAssertEqual(selected.breakpoints["md"], 768)
  }

  func testStorePlatformIsAppleOnly() {
    #if os(macOS)
    XCTAssertEqual(RufletPagePlatform.current, .macOS)
    #elseif os(iOS)
    XCTAssertEqual(RufletPagePlatform.current, .iOS)
    #endif
  }
}
