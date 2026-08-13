import RufletProtocol
import SwiftUI
import XCTest

@testable import RufletEngine

/// Literal Apple counterparts for the constructor branches in pinned
/// `grid_view.dart`, `list_view.dart`, `navigation_rail.dart`, and
/// `cupertino_checkbox.dart` that are not covered by upstream unit tests.
@MainActor
final class FletCollectionRendererParityTests: XCTestCase {
  func testListViewUsesPinnedConstructionCacheAndSemanticFields() {
    let lazy = configuration(
      type: "ListView",
      properties: [
        "build_controls_on_demand": true,
        "cache_extent": 220.0,
        "semantic_child_count": 7,
      ])

    XCTAssertTrue(lazy.buildsOnDemand)
    XCTAssertEqual(lazy.cacheExtent, 220)
    XCTAssertEqual(lazy.prefetchGroupSize(estimatedItemExtent: 44), 6)
    XCTAssertEqual(lazy.resolvedSemanticChildCount(actualCount: 3), 7)

    let eager = configuration(
      type: "ListView",
      properties: ["build_controls_on_demand": false])
    XCTAssertFalse(eager.buildsOnDemand)
    XCTAssertEqual(eager.prefetchGroupSize(estimatedItemExtent: 44), 1)
    XCTAssertEqual(eager.resolvedSemanticChildCount(actualCount: 3), 3)
  }

  func testGridViewUsesTheSamePinnedViewportContract() {
    let grid = configuration(
      type: "GridView",
      properties: [
        "build_controls_on_demand": true,
        "cache_extent": 101.0,
        "semantic_child_count": 9,
      ])

    XCTAssertTrue(grid.buildsOnDemand)
    XCTAssertEqual(grid.prefetchGroupSize(estimatedItemExtent: 50), 4)
    XCTAssertEqual(grid.resolvedSemanticChildCount(actualCount: 8), 9)

    let plan = RufletGridPlan(
      itemCount: 10,
      availableCrossExtent: 210,
      runsCount: 2,
      maxExtent: nil,
      spacing: 10,
      runSpacing: 10,
      childAspectRatio: 2,
      configuration: grid)
    XCTAssertEqual(plan.trackCount, 2)
    XCTAssertEqual(plan.itemCrossExtent, 100)
    XCTAssertEqual(plan.itemMainExtent, 50)
    XCTAssertEqual(plan.primaryGroups.count, 5)
    XCTAssertEqual(plan.cacheGroups.map(\.count), [3, 2])
    XCTAssertEqual(plan.contentMainExtent, 290)
  }

  func testGridMaxExtentMatchesPinnedAdaptiveCrossAxisDelegate() {
    let config = configuration(
      type: "GridView",
      properties: ["build_controls_on_demand": false])
    let plan = RufletGridPlan(
      itemCount: 5,
      availableCrossExtent: 500,
      runsCount: 99,
      maxExtent: 150,
      spacing: 8,
      runSpacing: 0,
      childAspectRatio: 1,
      configuration: config)

    // This is the worked example in Flutter's
    // SliverGridDelegateWithMaxCrossAxisExtent documentation.
    XCTAssertEqual(plan.trackCount, 4)
    XCTAssertEqual(plan.itemCrossExtent, 125)
    XCTAssertEqual(plan.primaryGroups.map(\.count), [4, 1])
    XCTAssertEqual(plan.cacheGroups.count, 2)
  }

  func testInvalidViewportValuesFollowNativeSafeBounds() {
    let config = configuration(
      type: "ListView",
      properties: ["cache_extent": -10.0, "semantic_child_count": -2])

    XCTAssertEqual(config.cacheExtent, 0)
    XCTAssertEqual(config.semanticChildCount, 0)
    XCTAssertEqual(config.prefetchGroupSize(estimatedItemExtent: 44), 1)
  }

  func testCupertinoCheckboxReadsPinnedTriStateValueAtItsRendererBoundary() {
    let backend = CollectionParityBackend()
    let control = RufletControl(
      id: 4,
      type: "CupertinoCheckbox",
      properties: ["value": .null, "tristate": true],
      backend: backend)

    XCTAssertNil(rufletCheckboxValue(control: control))
    _ = CupertinoCheckboxControl(control: control)
  }

  func testNavigationRailUsesVisibleDestinationsAndNotifiesItsParent() {
    let backend = CollectionParityBackend()
    let control = RufletControl(
      id: 1,
      type: "NavigationRail",
      properties: [
        "destinations": .array([
          wireControl(id: 2, type: "NavigationRailDestination"),
          wireControl(
            id: 3,
            type: "NavigationRailDestination",
            properties: ["visible": false]),
          wireControl(id: 4, type: "NavigationRailDestination"),
        ])
      ],
      backend: backend)

    let destinations = rufletNavigationChildren(control, property: "destinations")
    XCTAssertEqual(destinations.map(\.id), [2, 4])
    XCTAssertTrue(destinations.allSatisfy(\.notifyParent))
  }

  private func configuration(
    type: String,
    properties: [String: RufletValue]
  ) -> RufletCollectionViewportConfiguration {
    RufletCollectionViewportConfiguration(
      control: RufletControl(
        id: 1,
        type: type,
        properties: properties,
        backend: CollectionParityBackend()))
  }
}

private func wireControl(
  id: Int,
  type: String,
  properties: [String: RufletValue] = [:]
) -> RufletValue {
  .map(
    properties.merging([
      "_i": .int(Int64(id)),
      "_c": .string(type),
    ]) { current, _ in current })
}

@MainActor
private final class CollectionParityBackend: RufletBackendProtocol {
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
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
