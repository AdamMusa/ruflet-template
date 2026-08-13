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
