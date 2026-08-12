import XCTest
import RufletEngine
import RufletProtocol
@testable import RufletUI

final class PageletParityTests: XCTestCase {
  func testPageletRequiresVisibleContentWithPinnedMessage() {
    let presentation = PageletPresentation(node: ControlNode(id: 1, type: "Pagelet"))
    XCTAssertNil(presentation.contentID)
    XCTAssertEqual(
      PageletPresentation.missingContentError,
      "Pagelet.content must be provided and visible")
  }

  func testPageletDeclaresExactFletDrawerCommands() throws {
    XCTAssertEqual(
      PageletPresentation.methods,
      ["close_drawer", "close_end_drawer", "show_drawer", "show_end_drawer"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "Pagelet")).supportedMethods,
      PageletPresentation.methods)
  }

  func testPageletResolvesContentSlot() {
    let presentation = PageletPresentation(
      node: ControlNode(
        id: 1, type: "Pagelet", props: ["content": .controlRef(22)]))
    XCTAssertEqual(presentation.contentID, 22)
  }

  func testPageletRejectsUnresolvedAndInvisibleContentLikeFletBuildWidget() {
    let presentation = PageletPresentation(
      node: ControlNode(
        id: 1, type: "Pagelet", props: ["content": .controlRef(22)]))

    XCTAssertEqual(
      presentation.validationError(content: nil),
      PageletPresentation.missingContentError)
    XCTAssertEqual(
      presentation.validationError(
        content: ControlNode(
          id: 22, type: "Container", props: ["visible": .bool(false)])),
      PageletPresentation.missingContentError)
    XCTAssertNil(
      presentation.validationError(content: ControlNode(id: 22, type: "Container")))
  }
}
