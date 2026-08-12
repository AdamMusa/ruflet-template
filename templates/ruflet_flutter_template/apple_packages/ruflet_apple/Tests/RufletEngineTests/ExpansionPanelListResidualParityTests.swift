import RufletEngine
@testable import RufletUI
import XCTest

final class ExpansionPanelListResidualParityTests: XCTestCase {
  func testStructuralPanelVisibilityMatchesPinnedChildrenControls() {
    let first = ControlNode(id: 2, type: "ExpansionPanel")
    let hidden = ControlNode(id: 3, type: "ExpansionPanel", props: [
      "visible": .bool(false),
    ])
    let last = ControlNode(id: 4, type: "ExpansionPanel", props: [
      "visible": .bool(true),
    ])

    XCTAssertEqual(
      ExpansionPanelListPresentation.visiblePanels([first, hidden, last]).map(\.id),
      [2, 4])
  }

  func testChangeIndexUsesVisiblePanelOrder() {
    let hidden = ControlNode(id: 2, type: "ExpansionPanel", props: [
      "visible": .bool(false),
    ])
    let firstVisible = ControlNode(id: 3, type: "ExpansionPanel")
    let secondVisible = ControlNode(id: 4, type: "ExpansionPanel")

    let visible = ExpansionPanelListPresentation.visiblePanels([
      hidden, firstVisible, secondVisible,
    ])

    XCTAssertEqual(visible.firstIndex(where: { $0.id == firstVisible.id }), 0)
    XCTAssertEqual(visible.firstIndex(where: { $0.id == secondVisible.id }), 1)
  }
}
