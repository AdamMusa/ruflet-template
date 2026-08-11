import RufletEngine
@testable import RufletUI
import XCTest

final class RufletFocusContractTests: XCTestCase {
  func testImperativeFocusInstallsSharedNativeCapability() {
    for type in ["TextField", "Dropdown", "DropdownM2", "IconButton",
                 "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertTrue(RufletFocusContract.requiresNativeFocus(for: node), type)
      XCTAssertTrue(RufletFocusContract.methods(for: node).contains("focus"), type)
    }
  }

  func testFocusEventsInstallCapabilityWithoutImperativeMethod() {
    let node = ControlNode(id: 1, type: "Switch", props: ["on_focus": .bool(true)])
    XCTAssertTrue(RufletFocusContract.requiresNativeFocus(for: node))
    XCTAssertTrue(RufletFocusContract.methods(for: node).isEmpty)
  }

  func testUnfocusedDisplayControlDoesNotInstallCapability() {
    XCTAssertFalse(
      RufletFocusContract.requiresNativeFocus(for: ControlNode(id: 1, type: "Text")))
  }
}
