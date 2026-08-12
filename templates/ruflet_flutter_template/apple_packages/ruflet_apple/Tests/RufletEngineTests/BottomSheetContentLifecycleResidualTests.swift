import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletUI

final class BottomSheetContentLifecycleResidualTests: XCTestCase {
  func testMaterialBottomSheetRequiresPresentAndVisibleContent() {
    let missing = BottomSheetPresentation(node: ControlNode(id: 1, type: "BottomSheet"))
    XCTAssertEqual(
      missing.validationError(content: nil),
      "BottomSheet.content must be visible")

    let node = ControlNode(
      id: 2, type: "BottomSheet", props: ["content": .controlRef(10)])
    let presentation = BottomSheetPresentation(node: node)
    XCTAssertEqual(
      presentation.validationError(content: ControlNode(
        id: 10, type: "Column", props: ["visible": .bool(false)])),
      "BottomSheet.content must be visible")
    XCTAssertNil(presentation.validationError(
      content: ControlNode(id: 10, type: "Column")))
  }

  func testPinnedBehaviorDefaultsArePreserved() {
    let presentation = BottomSheetPresentation(node: ControlNode(
      id: 3, type: "BottomSheet"))

    XCTAssertFalse(presentation.fullscreen)
    XCTAssertFalse(presentation.scrollable)
    XCTAssertFalse(presentation.draggable)
    XCTAssertTrue(presentation.maintainBottomViewInsetsPadding)
    XCTAssertNil(presentation.effectiveSizeConstraints)
  }

  func testFullscreenForcesScrollControlAndSuppressesExplicitConstraints() {
    let presentation = BottomSheetPresentation(node: ControlNode(
      id: 4, type: "BottomSheet",
      props: [
        "fullscreen": .bool(true),
        "scrollable": .bool(false),
        "size_constraints": .map([
          "min_width": .double(200), "max_height": .double(500),
        ]),
      ]))

    XCTAssertTrue(presentation.fullscreen)
    XCTAssertTrue(presentation.scrollable)
    XCTAssertNil(presentation.effectiveSizeConstraints)
  }

  func testNonFullscreenPreservesConstraintsAndKeyboardInsetOverride() {
    let constraints: RufletValue = .map([
      "min_width": .double(200), "max_height": .double(500),
    ])
    let presentation = BottomSheetPresentation(node: ControlNode(
      id: 5, type: "BottomSheet",
      props: [
        "scrollable": .bool(true),
        "draggable": .bool(true),
        "maintain_bottom_view_insets_padding": .bool(false),
        "size_constraints": constraints,
      ]))

    XCTAssertFalse(presentation.fullscreen)
    XCTAssertTrue(presentation.scrollable)
    XCTAssertTrue(presentation.draggable)
    XCTAssertFalse(presentation.maintainBottomViewInsetsPadding)
    XCTAssertEqual(presentation.effectiveSizeConstraints, constraints)
  }

  func testDismissUpdatesOpenBeforeSendingEvent() {
    let node = ControlNode(
      id: 6, type: "BottomSheet", props: ["on_dismiss": .bool(true)])
    var calls: [String] = []
    let sink = RufletEventSink(
      send: { _, name, _ in calls.append("event:\(name)") },
      setLocal: { _, key, value in calls.append("local:\(key)=\(value.boolValue ?? true)") },
      update: { _, props in calls.append("update:\(props["open"]?.boolValue ?? true)") })

    RufletOverlaySemantics.dismiss(node, through: sink)

    XCTAssertEqual(calls, ["local:open=false", "update:false", "event:dismiss"])
  }
}
