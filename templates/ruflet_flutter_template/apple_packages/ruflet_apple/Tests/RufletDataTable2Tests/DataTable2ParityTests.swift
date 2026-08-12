import RufletEngine
@testable import RufletDataTable2
@testable import RufletUI
import XCTest

@MainActor
final class DataTable2ParityTests: XCTestCase {
  func testManifestAndOptionalBoundaryMatchVendoredPackage() throws {
    let package = try XCTUnwrap(
      RufletExtensionManifest.packages.first { $0.fletPackage == "flet_datatable2" })
    XCTAssertEqual(package.swiftProduct, "RufletDataTable2")
    XCTAssertEqual(package.status, .available)
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "DataTable2")?.rendering,
      .optionalBundle("RufletDataTable2"))
  }

  func testExtensionReplacesFallbackWithoutRegisteringAService() {
    let registry = ServiceRegistry()
    registry.register(extension: RufletDataTable2.self)

    XCTAssertTrue(registry.hasExtension("RufletDataTable2"))
    XCTAssertFalse(registry.handles("DataTable2"))
    XCTAssertEqual(ControlRegistry.descriptor(for: "DataTable2")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "DataTable2")?.implementation,
      "RufletDataTable2.DataTable2ControlView")
  }

  func testDefaultsMatchFletDataTable2Adapter() {
    let value = DataTable2Semantics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(value.fixedLeftColumns, 0)
    XCTAssertEqual(value.fixedTopRows, 1)
    XCTAssertEqual(value.smallRatio, 0.67)
    XCTAssertEqual(value.largeRatio, 1.2)
    XCTAssertTrue(value.showHeadingCheckbox)
    XCTAssertFalse(value.showBottomBorder)
    XCTAssertFalse(value.showCheckboxColumn)
    XCTAssertFalse(value.sortAscending)
    XCTAssertEqual(value.checkboxAlignment, "center")
    XCTAssertEqual(value.clipBehavior, "none")
    XCTAssertNil(value.visibleHorizontalScrollbar)
    XCTAssertNil(value.visibleVerticalScrollbar)
  }

  func testExplicitDataTableAndColumnPropertiesArePreserved() {
    let value = DataTable2Semantics(ControlNode(
      id: 1, type: "DataTable2", props: [
        "fixed_left_columns": .int(2), "fixed_top_rows": .int(3),
        "sm_ratio": .double(0.5), "lm_ratio": .double(1.75),
        "show_heading_checkbox": .bool(false), "show_bottom_border": .bool(true),
        "show_checkbox_column": .bool(true), "sort_ascending": .bool(true),
        "checkbox_alignment": .string("bottom_right"),
        "visible_horizontal_scroll_bar": .bool(false),
        "visible_vertical_scroll_bar": .bool(true), "min_width": .double(640),
        "bottom_margin": .double(24), "clip_behavior": .string("anti_alias"),
      ]))
    XCTAssertEqual(value.fixedLeftColumns, 2)
    XCTAssertEqual(value.fixedTopRows, 3)
    XCTAssertEqual(value.smallRatio, 0.5)
    XCTAssertEqual(value.largeRatio, 1.75)
    XCTAssertFalse(value.showHeadingCheckbox)
    XCTAssertTrue(value.showBottomBorder)
    XCTAssertTrue(value.showCheckboxColumn)
    XCTAssertTrue(value.sortAscending)
    XCTAssertEqual(value.minWidth, 640)
    XCTAssertEqual(value.bottomMargin, 24)

    XCTAssertEqual(
      value.width(of: ControlNode(id: 2, type: "DataColumn", props: [
        "size": .string("S"),
      ]), mediumWidth: 100), 50)
    XCTAssertEqual(
      value.width(of: ControlNode(id: 3, type: "DataColumn", props: [
        "size": .string("M"),
      ]), mediumWidth: 100), 100)
    XCTAssertEqual(
      value.width(of: ControlNode(id: 4, type: "DataColumn", props: [
        "size": .string("L"),
      ]), mediumWidth: 100), 175)
    XCTAssertEqual(
      value.width(of: ControlNode(id: 5, type: "DataColumn", props: [
        "fixed_width": .double(88),
      ]), mediumWidth: 100), 88)
  }

  func testSpecificRowHeightOverridesTableHeight() {
    let value = DataTable2Semantics(ControlNode(id: 1, type: "DataTable2"))
    XCTAssertEqual(
      value.height(of: ControlNode(id: 2, type: "DataRow", props: [
        "specific_row_height": .double(72),
      ]), fallback: 48), 72)
    XCTAssertEqual(value.height(of: ControlNode(id: 3, type: "DataRow"), fallback: 48), 48)
  }

  func testDescriptorAdvertisesFletDataTable2RowAndCellEvents() throws {
    let descriptor = try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "DataTable2"))
    XCTAssertEqual(descriptor.supportedEvents, [
      "double_tap", "long_press", "secondary_tap", "secondary_tap_down",
      "select_all", "select_change", "sort", "tap", "tap_cancel", "tap_down",
    ])
  }
}
