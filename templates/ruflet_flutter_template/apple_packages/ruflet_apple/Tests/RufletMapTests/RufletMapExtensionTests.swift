import RufletEngine
@testable import RufletMap
@testable import RufletUI
import XCTest

@MainActor
final class RufletMapExtensionTests: XCTestCase {
  func testManifestReportsFletMapAsAvailable() throws {
    let package = try XCTUnwrap(
      RufletExtensionManifest.packages.first { $0.fletPackage == "flet_map" })
    XCTAssertEqual(package.swiftProduct, "RufletMap")
    XCTAssertEqual(package.status, .available)
  }

  func testMapFallbackIsReplacedOnlyWhenExtensionRegisters() {
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "Map")?.rendering,
      .optionalBundle("RufletMap"))

    let registry = ServiceRegistry()
    registry.register(extension: RufletMap.self)

    XCTAssertTrue(registry.hasExtension("RufletMap"))
    XCTAssertEqual(ControlRegistry.descriptor(for: "Map")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Map")?.implementation,
      "RufletMap.MapControlView")
    XCTAssertFalse(registry.handles("Map"), "Map is a visual control, not a service")
  }

  func testEveryFletMapWidgetIsOwnedByTheOptionalProduct() {
    let wireTypes = [
      "Map", "CircleLayer", "MarkerLayer", "PolygonLayer", "PolylineLayer",
      "RichAttribution", "SimpleAttribution", "TileLayer",
    ]

    for wireType in wireTypes {
      XCTAssertEqual(
        ControlRegistry.builtInDescriptor(for: wireType)?.rendering,
        .optionalBundle("RufletMap"),
        "Core must retain only missing-product metadata for \(wireType)")
    }

    let registry = ServiceRegistry()
    registry.register(extension: RufletMap.self)

    XCTAssertEqual(ControlRegistry.descriptor(for: "Map")?.rendering, .nativeView)
    for wireType in wireTypes.dropFirst() {
      XCTAssertEqual(
        ControlRegistry.descriptor(for: wireType)?.rendering,
        .metadataOnly,
        "RufletMap must claim Flet's \(wireType) widget")
    }
  }
}
