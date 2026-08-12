import RufletEngine
@testable import RufletUI
import XCTest

final class OptionalDisplayExtensionBoundaryTests: XCTestCase {
  func testCoreDeclaresCodeEditorAsOptionalWithoutBuiltInFamilyDispatch() throws {
    let descriptor = ControlRegistry.builtInDescriptor(for: "CodeEditor")
    XCTAssertEqual(descriptor?.rendering, .optionalBundle("RufletCodeEditor"))
    XCTAssertFalse(try coreFamilySource("InteractiveFamilies.swift").contains("case \"CodeEditor\""))
  }

  func testCoreDeclaresEverySpinKitWireTypeAsOptionalWithoutBuiltInFamilyDispatch() throws {
    for type in ["RufletSpinKit", "SpinKitWave", "SpinKitPumpingHeart"] {
      XCTAssertEqual(
        ControlRegistry.builtInDescriptor(for: type)?.rendering,
        .optionalBundle("RufletSpinKit"))
    }
    XCTAssertFalse(try coreFamilySource("DisplayFamily.swift").contains("SpinKitControlView"))
  }

  func testProductsAreAvailableInSourceDrivenExtensionManifest() {
    let entries = Dictionary(uniqueKeysWithValues: RufletExtensionManifest.packages.map {
      ($0.swiftProduct, $0.status)
    })
    XCTAssertEqual(entries["RufletCodeEditor"], .available)
    XCTAssertEqual(entries["RufletSpinKit"], .available)
  }

  private func coreFamilySource(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/RufletUI/Families")
      .appendingPathComponent(name)
    return try String(contentsOf: url)
  }
}
