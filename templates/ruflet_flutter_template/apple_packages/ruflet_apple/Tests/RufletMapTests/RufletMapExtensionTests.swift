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
}
