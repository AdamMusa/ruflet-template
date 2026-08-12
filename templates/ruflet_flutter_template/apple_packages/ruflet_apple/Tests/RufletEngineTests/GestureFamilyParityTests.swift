@testable import RufletUI
import CoreGraphics
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

  func testDragTargetPayloadMatchesFletDragTargetEvent() {
    XCTAssertEqual(
      RufletGestureParity.dragPayload(
        sourceID: 42, location: CGPoint(x: 12.5, y: 27)),
      .map([
        "src_id": .int(42), "x": .double(12.5), "y": .double(27),
      ]))
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
}
