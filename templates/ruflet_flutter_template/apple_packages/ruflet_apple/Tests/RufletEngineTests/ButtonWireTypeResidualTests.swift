import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class ButtonWireTypeResidualTests: XCTestCase {
  func testIconButtonRejectsNonFletScalarContent() {
    for value: RufletValue in [.bool(true), .int(12), .double(2.5)] {
      let button = ControlNode(id: 1, type: "IconButton", props: ["content": value])
      XCTAssertEqual(
        ButtonPresentation.validationMessage(button, variant: .icon),
        "IconButton must have either icon or a visible content specified.")
    }
  }

  func testIntegerIconAndStringContentRemainValidIncludingEmptyString() {
    XCTAssertNil(ButtonPresentation.validationMessage(
      ControlNode(id: 1, type: "IconButton", props: ["icon": .int(1)]), variant: .icon))
    XCTAssertNil(ButtonPresentation.validationMessage(
      ControlNode(id: 2, type: "IconButton", props: ["content": .string("")]), variant: .icon))
  }

}
