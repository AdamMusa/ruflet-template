@testable import RufletUI
import XCTest

final class RufletInteractionContractTests: XCTestCase {
  func testContextMenuDeclaresFletBehavior() throws {
    let descriptor = try XCTUnwrap(ControlRegistry.descriptor(for: "ContextMenu"))
    XCTAssertEqual(descriptor.supportedEvents, ["dismiss", "select"])
    XCTAssertEqual(descriptor.supportedMethods, ["open"])
  }

  func testPopupMenuDeclaresLifecycleEvents() throws {
    let descriptor = try XCTUnwrap(ControlRegistry.descriptor(for: "PopupMenuButton"))
    XCTAssertEqual(descriptor.supportedEvents, ["cancel", "open", "select"])
  }

  func testEveryFletImperativeFocusControlDeclaresMethod() throws {
    for type in ["Dropdown", "DropdownM2", "IconButton", "FilledIconButton",
                 "FilledTonalIconButton", "OutlinedIconButton"] {
      XCTAssertTrue(
        try XCTUnwrap(ControlRegistry.descriptor(for: type)).supportedMethods.contains("focus"),
        type)
    }
  }
}
