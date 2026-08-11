import XCTest
@testable import RufletUI

final class FletLayoutEventParityTests: XCTestCase {
  func testScrollableFlexControlsDeclareFletScrollEvent() {
    XCTAssertEqual(ControlRegistry.descriptor(for: "Row")?.supportedEvents, ["scroll"])
    XCTAssertEqual(ControlRegistry.descriptor(for: "Column")?.supportedEvents, ["scroll"])
  }

  func testContainerDeclaresSharedAnimationAndPointerEvents() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Container")?.supportedEvents,
      ["animation_end", "click", "hover", "long_press", "tap_down"])
  }

  func testCupertinoValueControlsDeclareSpecializedEvents() {
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "CupertinoSlider")?.supportedEvents,
      ["change", "change_end", "change_start"])
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "CupertinoSwitch")?.supportedEvents,
      ["change", "image_error"])
  }
}
