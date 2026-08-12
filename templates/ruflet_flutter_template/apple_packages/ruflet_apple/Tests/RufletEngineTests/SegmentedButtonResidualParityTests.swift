import RufletEngine
@testable import RufletUI
import XCTest

final class SegmentedButtonResidualParityTests: XCTestCase {
  func testStructuralSegmentVisibilityMatchesPinnedChildrenSelection() {
    let visible = ControlNode(id: 2, type: "Segment", props: [
      "value": .string("visible"), "label": .string("Visible"),
    ])
    let explicitlyVisible = ControlNode(id: 3, type: "Segment", props: [
      "value": .string("also-visible"), "visible": .bool(true),
    ])
    let hidden = ControlNode(id: 4, type: "Segment", props: [
      "value": .string("hidden"), "visible": .bool(false),
    ])

    XCTAssertEqual(
      SegmentedButtonPresentation.visibleSegments([visible, hidden, explicitlyVisible]).map(\.id),
      [2, 3])
  }

  func testValidationCountsOnlyVisibleSegments() {
    let button = ControlNode(id: 1, type: "SegmentedButton", props: [
      "selected": .array([.string("hidden")]),
    ])
    let hidden = ControlNode(id: 2, type: "Segment", props: [
      "value": .string("hidden"), "visible": .bool(false),
    ])
    let count = SegmentedButtonPresentation.visibleSegments([hidden]).count

    XCTAssertEqual(
      SegmentedButtonPresentation.validationMessage(
        segmentCount: count, selected: ["hidden"], node: button),
      "SegmentedButton.segments must be contain at least one visible segment")
  }

  func testDisabledSegmentSuppressesTooltipInBothNativeRoutes() {
    let enabled = ControlNode(id: 2, type: "Segment", props: [
      "tooltip": .string("Choose this"),
    ])
    let disabled = ControlNode(id: 3, type: "Segment", props: [
      "tooltip": .string("Unavailable"), "disabled": .bool(true),
    ])

    XCTAssertEqual(SegmentedButtonPresentation.tooltip(enabled), "Choose this")
    XCTAssertNil(SegmentedButtonPresentation.tooltip(disabled))
    XCTAssertNil(SegmentedButtonPresentation.tooltip(
      ControlNode(id: 4, type: "Segment")))
  }
}
