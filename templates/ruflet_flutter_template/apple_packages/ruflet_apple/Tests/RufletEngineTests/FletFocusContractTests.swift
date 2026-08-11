import RufletEngine
@testable import RufletUI
import XCTest

final class FletFocusContractTests: XCTestCase {
  func testImperativeFocusInstallsSharedNativeCapability() {
    for type in ["TextField", "Dropdown", "DropdownM2", "IconButton",
                 "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton"] {
      let node = ControlNode(id: 1, type: type)
      XCTAssertTrue(FletFocusContract.requiresNativeFocus(for: node), type)
      XCTAssertTrue(FletFocusContract.methods(for: node).contains("focus"), type)
    }
  }

  func testFocusEventsInstallCapabilityWithoutImperativeMethod() {
    let node = ControlNode(id: 1, type: "Switch", props: ["on_focus": .bool(true)])
    XCTAssertTrue(FletFocusContract.requiresNativeFocus(for: node))
    XCTAssertTrue(FletFocusContract.methods(for: node).isEmpty)
  }

  func testUnfocusedDisplayControlDoesNotInstallCapability() {
    XCTAssertFalse(
      FletFocusContract.requiresNativeFocus(for: ControlNode(id: 1, type: "Text")))
  }
}
