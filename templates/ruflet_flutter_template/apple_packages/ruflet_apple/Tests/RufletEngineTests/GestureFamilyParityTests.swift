@testable import RufletUI
import CoreGraphics
import RufletEngine
import RufletProtocol
import XCTest

final class GestureFamilyParityTests: XCTestCase {
  func testPinnedFletGestureDefaults() {
    XCTAssertEqual(RufletGestureParity.dragGroup, "default")
    XCTAssertEqual(RufletGestureParity.dismissThreshold, 0.4)
    XCTAssertEqual(RufletGestureParity.interactionUpdateInterval, 200)
    XCTAssertEqual(RufletGestureParity.interactiveMinScale, 0.8)
    XCTAssertEqual(RufletGestureParity.interactiveMaxScale, 2.5)
    XCTAssertEqual(RufletGestureParity.interactiveFriction, 0.0000135)
    XCTAssertEqual(RufletGestureParity.interactiveScaleFactor, 200)
  }

  func testDismissibleUsesPinnedFletDurationsAndRufletAliases() {
    let omitted = ControlNode(id: 1, type: "Dismissible")
    XCTAssertEqual(RufletDismissibleDefaults.movementDuration(omitted), 200)
    XCTAssertEqual(RufletDismissibleDefaults.resizeDuration(omitted), 300)

    let generatedNames = ControlNode(
      id: 2, type: "Dismissible",
      props: ["movement_duration": .double(125), "resize_duration": .double(450)])
    XCTAssertEqual(RufletDismissibleDefaults.movementDuration(generatedNames), 125)
    XCTAssertEqual(RufletDismissibleDefaults.resizeDuration(generatedNames), 450)

    // Exact pinned Flet wire semantics win when both representations arrive.
    let pinnedWire = ControlNode(
      id: 3, type: "Dismissible",
      props: [
        "duration": .double(80),
        "movement_duration": .double(125),
        "resize_duration": .double(450),
      ])
    XCTAssertEqual(RufletDismissibleDefaults.movementDuration(pinnedWire), 80)
    XCTAssertEqual(RufletDismissibleDefaults.resizeDuration(pinnedWire), 80)
  }

  func testDismissibleThresholdsPreferPinnedNamesAndAcceptRubySymbolAliases() {
    let node = ControlNode(
      id: 4, type: "Dismissible",
      props: ["dismiss_thresholds": .map([
        "endToStart": .double(0.25),
        "end_to_start": .double(0.75),
        "up": .double(0.6),
      ])])

    XCTAssertEqual(RufletDismissibleDefaults.threshold(node, direction: "endToStart"), 0.25)
    XCTAssertEqual(RufletDismissibleDefaults.threshold(node, direction: "up"), 0.6)
    XCTAssertEqual(RufletDismissibleDefaults.threshold(node, direction: "down"), 0.4)

    let aliasOnly = ControlNode(
      id: 5, type: "Dismissible",
      props: ["dismiss_thresholds": .map(["end_to_start": .double(0.7)])])
    XCTAssertEqual(
      RufletDismissibleDefaults.threshold(aliasOnly, direction: "endToStart"), 0.7)
  }

  func testDismissibleCompletionUsesMeasuredExtentAndCrossAxisFraction() {
    XCTAssertEqual(
      RufletDismissibleDefaults.dismissedOffset(
        size: CGSize(width: 320, height: 80), direction: "endToStart",
        layoutDirection: .leftToRight, crossAxisEndOffset: 0.25),
      CGSize(width: -320, height: 20))
    XCTAssertEqual(
      RufletDismissibleDefaults.dismissedOffset(
        size: CGSize(width: 320, height: 80), direction: "startToEnd",
        layoutDirection: .rightToLeft, crossAxisEndOffset: -0.5),
      CGSize(width: -320, height: -40))
    XCTAssertEqual(
      RufletDismissibleDefaults.dismissedOffset(
        size: CGSize(width: 320, height: 80), direction: "up",
        layoutDirection: .leftToRight, crossAxisEndOffset: 0.1),
      CGSize(width: 32, height: -80))
  }

  func testDismissibleRequiredContentErrorMatchesPinnedClient() {
    XCTAssertEqual(
      RufletDismissibleDefaults.missingContentError,
      "Dismissible.content must be visible")
  }

  func testDragTargetPayloadMatchesFletDragTargetEvent() {
    XCTAssertEqual(
      RufletGestureParity.dragPayload(
        sourceID: 42, location: CGPoint(x: 12.5, y: 27)),
      .map([
        "src_id": .int(42), "x": .double(12.5), "y": .double(27),
      ]))
  }

  func testDragTargetRequiresVisibleContent() {
    XCTAssertEqual(
      RufletDragTargetSemantics.validationError(contentID: nil, content: nil),
      "DragTarget.content must be visible")
    XCTAssertEqual(
      RufletDragTargetSemantics.validationError(
        contentID: 5,
        content: ControlNode(
          id: 5, type: "Container", props: ["visible": .bool(false)])),
      RufletDragTargetSemantics.missingContentError)
    XCTAssertNil(RufletDragTargetSemantics.validationError(
      contentID: 5, content: ControlNode(id: 5, type: "Container")))
  }

  func testInteractiveViewerUsesFletScaleDetailKeys() throws {
    let update = try XCTUnwrap(
      RufletInteractionParity.scaleUpdate(
        scale: 1.25, local: CGPoint(x: 8, y: 12), global: CGPoint(x: 18, y: 22),
        previousLocal: CGPoint(x: 5, y: 9), timestamp: 100).mapValue)
    XCTAssertEqual(
      Set(update.keys), ["gfp", "fpd", "lfp", "pc", "hs", "vs", "s", "rot", "ts"])
    XCTAssertEqual(update["s"], .double(1.25))
    XCTAssertEqual(update["pc"], .int(2))
  }

  func testInteractiveViewerRequiresVisibleContent() {
    XCTAssertEqual(
      RufletInteractiveViewerSemantics.validationError(contentID: 4, content: nil),
      "InteractiveViewer.content must be provided and visible")
    XCTAssertEqual(
      RufletInteractiveViewerSemantics.validationError(
        contentID: 4,
        content: ControlNode(
          id: 4, type: "Container", props: ["visible": .bool(false)])),
      RufletInteractiveViewerSemantics.missingContentError)
    XCTAssertNil(RufletInteractiveViewerSemantics.validationError(
      contentID: 4, content: ControlNode(id: 4, type: "Container")))
  }

  func testGestureFamilyDeclaresFletLifecycleAndCommands() throws {
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "Draggable")).supportedEvents,
      ["drag_complete", "drag_start"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "DragTarget")).supportedEvents,
      ["accept", "leave", "move", "will_accept"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "Dismissible")).supportedMethods,
      ["confirm_dismiss"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "InteractiveViewer")).supportedMethods,
      ["pan", "reset", "restore_state", "save_state", "zoom"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.descriptor(for: "KeyboardListener")).supportedMethods,
      ["focus"])
  }

  func testKeyboardListenerKeepsPinnedDefaultsValidationAndPayload() {
    let defaults = KeyboardListenerPresentation(node: ControlNode(
      id: 1, type: "KeyboardListener"))
    XCTAssertFalse(defaults.autofocus)
    XCTAssertTrue(defaults.includeSemantics)
    XCTAssertEqual(
      KeyboardListenerPresentation.missingContentError,
      "KeyboardListener control has no content.")
    XCTAssertEqual(
      RufletInteractionParity.key("Enter"),
      .map(["key": .string("Enter")]))

    let explicit = KeyboardListenerPresentation(node: ControlNode(
      id: 2, type: "KeyboardListener", props: [
        "autofocus": .bool(true), "include_semantics": .bool(false),
      ]))
    XCTAssertTrue(explicit.autofocus)
    XCTAssertFalse(explicit.includeSemantics)
  }

  func testKeyboardListenerRejectsUnresolvedAndInvisibleContent() {
    let presentation = KeyboardListenerPresentation(node: ControlNode(
      id: 2, type: "KeyboardListener", props: ["content": .controlRef(3)]))

    XCTAssertEqual(
      presentation.validationError(content: nil),
      KeyboardListenerPresentation.missingContentError)
    XCTAssertEqual(
      presentation.validationError(content: ControlNode(
        id: 3, type: "Container", props: ["visible": .bool(false)])),
      KeyboardListenerPresentation.missingContentError)
    XCTAssertNil(
      presentation.validationError(content: ControlNode(id: 3, type: "Container")))
  }
}
