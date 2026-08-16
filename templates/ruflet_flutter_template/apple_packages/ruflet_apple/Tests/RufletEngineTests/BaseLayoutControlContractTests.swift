import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class BaseLayoutControlContractTests: XCTestCase {
  func testExpandIsHostedOnlyByFletExpandedParentsAndKeepsFlexAndLoose() {
    let backend = BaseLayoutBackend()
    let hosted = parent(
      id: 1,
      type: "Row",
      internals: ["host_expanded": .bool(true)],
      backend: backend)
    let child = RufletControl(
      id: 2,
      type: "Container",
      properties: ["expand": .int(3), "expand_loose": .bool(true)],
      backend: backend,
      parent: hosted)

    XCTAssertEqual(
      rufletExpansionContract(for: child),
      RufletExpansionContract(flex: 3, loose: true, axis: .horizontal))

    let unhosted = parent(id: 3, type: "Stack", internals: [:], backend: backend)
    let rejected = RufletControl(
      id: 4,
      type: "Container",
      properties: ["expand": .bool(true)],
      backend: backend,
      parent: unhosted)
    XCTAssertNil(rufletExpansionContract(for: rejected))
  }

  func testBooleanExpandAndVerticalHostMatchPinnedParser() {
    let backend = BaseLayoutBackend()
    let hosted = parent(
      id: 1,
      type: "Column",
      internals: ["host_expanded": .bool(true)],
      backend: backend)
    let child = RufletControl(
      id: 2,
      type: "Text",
      properties: ["expand": .bool(true)],
      backend: backend,
      parent: hosted)

    XCTAssertEqual(
      rufletExpansionContract(for: child),
      RufletExpansionContract(flex: 1, loose: false, axis: .vertical))
  }

  func testSizeSkipPropertiesSuppressesWidthAndHeightTogether() {
    let backend = BaseLayoutBackend()
    let control = RufletControl(
      id: 1,
      type: "Container",
      properties: [
        "width": .double(120),
        "height": .double(80),
        "_internals": .map(["skip_properties": .array([.string("width")])]),
      ],
      backend: backend)

    XCTAssertEqual(rufletSizeContract(for: control), RufletSizeContract(width: nil, height: nil))
  }

  func testExplicitSizeClampsToBoundedParentButSurvivesUnboundedFlexAxis() {
    XCTAssertEqual(
      rufletConstrainedExtent(
        requested: 560,
        proposed: 353,
        measured: 560,
        fillsAvailableSpace: false),
      353)
    XCTAssertEqual(
      rufletConstrainedExtent(
        requested: 300,
        proposed: nil,
        measured: 300,
        fillsAvailableSpace: false),
      300)
  }

  func testAlignedContainerFillsOnlyFiniteAvailableExtent() {
    XCTAssertEqual(
      rufletConstrainedExtent(
        requested: nil,
        proposed: 393,
        measured: 120,
        fillsAvailableSpace: true),
      393)
    XCTAssertEqual(
      rufletConstrainedExtent(
        requested: nil,
        proposed: nil,
        measured: 120,
        fillsAvailableSpace: true),
      120)
  }

  func testPositionRequiresStackHostAndAnimatedDefaultStartsAtOrigin() {
    let backend = BaseLayoutBackend()
    let hosted = parent(
      id: 1,
      type: "Stack",
      internals: ["host_positioned": .bool(true)],
      backend: backend)
    let child = RufletControl(
      id: 2,
      type: "Container",
      properties: ["animate_position": .int(250)],
      backend: backend,
      parent: hosted)

    let position = rufletPositionContract(for: child)
    XCTAssertTrue(position.hosted)
    XCTAssertTrue(position.isPositioned)
    XCTAssertEqual(position.resolvedLeft, 0)
    XCTAssertEqual(position.resolvedTop, 0)
    XCTAssertEqual(position.animation?.duration, 0.25)

    let outside = RufletControl(
      id: 3,
      type: "Container",
      properties: ["left": .double(12)],
      backend: backend)
    XCTAssertFalse(rufletPositionContract(for: outside).hosted)
    XCTAssertTrue(rufletPositionContract(for: outside).isPositioned)
  }

  func testFlexAllocatorDividesOnlyRemainingExtentByFlexWeight() {
    let one = rufletFlexAllocation(
      availableExtent: 600,
      fixedExtent: 120,
      spacing: 10,
      childCount: 3,
      flex: 1,
      totalFlex: 3)
    let two = rufletFlexAllocation(
      availableExtent: 600,
      fixedExtent: 120,
      spacing: 10,
      childCount: 3,
      flex: 2,
      totalFlex: 3)

    XCTAssertNotNil(one)
    XCTAssertNotNil(two)
    XCTAssertEqual(one!, CGFloat(460) / 3, accuracy: 0.001)
    XCTAssertEqual(two!, CGFloat(920) / 3, accuracy: 0.001)
  }

  func testMainAxisFreeSpaceMatchesPinnedSpaceModes() {
    XCTAssertEqual(
      rufletMainAxisDistribution(
        alignment: .end,
        availableExtent: 500,
        occupiedExtent: 200,
        childCount: 3),
      RufletMainAxisDistribution(edgeInset: 300, additionalGap: 0))
    XCTAssertEqual(
      rufletMainAxisDistribution(
        alignment: .center,
        availableExtent: 500,
        occupiedExtent: 200,
        childCount: 3),
      RufletMainAxisDistribution(edgeInset: 150, additionalGap: 0))
    XCTAssertEqual(
      rufletMainAxisDistribution(
        alignment: .spaceBetween,
        availableExtent: 500,
        occupiedExtent: 200,
        childCount: 3),
      RufletMainAxisDistribution(edgeInset: 0, additionalGap: 150))
    XCTAssertEqual(
      rufletMainAxisDistribution(
        alignment: .spaceAround,
        availableExtent: 500,
        occupiedExtent: 200,
        childCount: 3),
      RufletMainAxisDistribution(edgeInset: 50, additionalGap: 100))
    XCTAssertEqual(
      rufletMainAxisDistribution(
        alignment: .spaceEvenly,
        availableExtent: 500,
        occupiedExtent: 200,
        childCount: 3),
      RufletMainAxisDistribution(edgeInset: 75, additionalGap: 75))
  }

  func testHorizontalWrapPlacesRunsAndItemsWithPinnedAlignments() {
    let plan = rufletFlowPlan(
      axis: .horizontal,
      availableMainExtent: 100,
      availableCrossExtent: 80,
      spacing: 10,
      runSpacing: 5,
      alignment: .spaceBetween,
      runAlignment: .spaceEvenly,
      crossAlignment: .end,
      itemSizes: [
        CGSize(width: 30, height: 10),
        CGSize(width: 30, height: 20),
        CGSize(width: 60, height: 15),
      ])

    XCTAssertEqual(plan.positions[0].x, 0, accuracy: 0.001)
    XCTAssertEqual(plan.positions[1].x, 70, accuracy: 0.001)
    XCTAssertEqual(plan.positions[0].y, CGFloat(70) / 3, accuracy: 0.001)
    XCTAssertEqual(plan.positions[1].y, CGFloat(40) / 3, accuracy: 0.001)
    XCTAssertEqual(plan.positions[2].x, 0, accuracy: 0.001)
    XCTAssertEqual(plan.positions[2].y, CGFloat(155) / 3, accuracy: 0.001)
    XCTAssertEqual(plan.contentSize, CGSize(width: 70, height: 80))
  }

  func testVerticalWrapUsesColumnCrossAlignment() {
    let plan = rufletFlowPlan(
      axis: .vertical,
      availableMainExtent: 55,
      availableCrossExtent: nil,
      spacing: 5,
      runSpacing: 8,
      alignment: .start,
      runAlignment: .start,
      crossAlignment: .center,
      itemSizes: [
        CGSize(width: 20, height: 20),
        CGSize(width: 40, height: 30),
        CGSize(width: 30, height: 30),
      ])

    XCTAssertEqual(plan.positions[0], CGPoint(x: 10, y: 0))
    XCTAssertEqual(plan.positions[1], CGPoint(x: 0, y: 25))
    XCTAssertEqual(plan.positions[2], CGPoint(x: 48, y: 0))
    XCTAssertEqual(plan.contentSize, CGSize(width: 78, height: 55))
  }

  private func parent(
    id: Int,
    type: String,
    internals: [String: RufletValue],
    backend: BaseLayoutBackend
  ) -> RufletControl {
    RufletControl(
      id: id,
      type: type,
      properties: ["_internals": .map(internals)],
      backend: backend)
  }
}

@MainActor
private final class BaseLayoutBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
