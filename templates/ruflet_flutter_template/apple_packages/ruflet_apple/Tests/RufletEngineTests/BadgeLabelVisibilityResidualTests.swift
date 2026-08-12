import RufletEngine
@testable import RufletUI
import XCTest

final class BadgeLabelVisibilityResidualTests: XCTestCase {
  func testHiddenControlLabelUsesDotBadgeSemantics() {
    let badge = ControlNode(id: 1, type: "Badge", props: [
      "label": .controlRef(2),
    ])
    let nodes = [
      2: ControlNode(id: 2, type: "Text", props: [
        "value": .string("9"), "visible": .bool(false),
      ]),
    ]

    XCTAssertNil(RufletBadgeSemantics.visibleLabelID(badge, in: nodes))
    XCTAssertFalse(RufletBadgeSemantics.hasVisibleLabel(badge, in: nodes))
    XCTAssertEqual(
      RufletBadgeSemantics.markerOffset(
        badge, layoutDirection: .leftToRight,
        labelPresent: RufletBadgeSemantics.hasVisibleLabel(badge, in: nodes)),
      .zero)
  }

  func testVisibleControlLabelKeepsLabelledBadgeSemantics() {
    let badge = ControlNode(id: 1, type: "Badge", props: [
      "label": .controlRef(2),
    ])
    let nodes = [2: ControlNode(id: 2, type: "Text")]

    XCTAssertEqual(RufletBadgeSemantics.visibleLabelID(badge, in: nodes), 2)
    XCTAssertTrue(RufletBadgeSemantics.hasVisibleLabel(badge, in: nodes))
  }

  func testStringLabelDoesNotDependOnStructuralVisibility() {
    let badge = ControlNode(id: 1, type: "Badge", props: [
      "label": .string("New"),
    ])

    XCTAssertTrue(RufletBadgeSemantics.hasVisibleLabel(badge, in: [:]))
  }
}
