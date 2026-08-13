import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class SwitchPropertyConsumptionTests: XCTestCase {
  func testSwitchConsumesPinnedWidgetStateAppearanceContract() {
    let source = sourceText("Sources/RufletEngine/Controls/switch.swift")
    for property in [
      "autofocus", "focus_color", "hover_color", "inactive_thumb_color",
      "inactive_track_color", "mouse_cursor", "overlay_color", "splash_radius",
      "thumb_color", "thumb_icon", "track_color", "track_outline_color",
      "track_outline_width",
    ] {
      XCTAssertTrue(source.contains("\"\(property)\""), property)
    }
  }

  func testCupertinoSwitchConsumesPinnedImageAndAppearanceContract() {
    let source = sourceText("Sources/RufletEngine/Controls/cupertino_switch.swift")
    for property in [
      "active_thumb_image", "active_thumb_image_src", "autofocus", "focus_color",
      "inactive_thumb_color", "inactive_thumb_image", "inactive_thumb_image_src",
      "inactive_track_color", "off_label_color", "on_label_color", "thumb_color",
      "thumb_icon", "track_outline_color", "track_outline_width",
    ] {
      XCTAssertTrue(source.contains("\"\(property)\""), property)
    }
    XCTAssertTrue(source.contains("\"image_error\""))
  }

  func testPinnedChangePayloadDifferenceIsPreserved() {
    let material = sourceText("Sources/RufletEngine/Controls/switch.swift")
    let cupertino = sourceText("Sources/RufletEngine/Controls/cupertino_switch.swift")
    XCTAssertTrue(material.contains("triggerEvent(\"change\", data: .bool(next))"))
    XCTAssertTrue(cupertino.contains("triggerEvent(\"change\")"))
  }

  private func sourceText(_ relative: String) -> String {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try! String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
  }
}
