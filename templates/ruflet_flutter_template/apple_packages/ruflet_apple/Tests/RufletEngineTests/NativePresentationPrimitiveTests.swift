import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class NativePresentationPrimitiveTests: XCTestCase {
  func testPresentationPrimitiveWireTypesResolveThroughCoreExtension() {
    let backend = PresentationPrimitiveBackend()
    let extensionUnderTest = RufletCoreExtension()
    for (offset, type) in ["Banner", "CupertinoActivityIndicator", "ShaderMask", "Shimmer"].enumerated() {
      let control = RufletControl(
        id: offset + 1,
        type: type,
        properties: properties(for: type),
        backend: backend)
      XCTAssertNotNil(extensionUnderTest.createView(for: control), "Missing native \(type) view")
      XCTAssertTrue(extensionUnderTest.renderedControlTypes.contains(type))
    }
  }

  func testShimmerDirectionMatchesPinnedVocabulary() {
    XCTAssertEqual(RufletShimmerDirection.allCases.map(\.rawValue), ["ltr", "rtl", "ttb", "btt"])
  }

  func testEveryInitiallyHiddenModalHasANonInteractiveLifecycleAnchor() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    for file in [
      "alert_dialog.swift",
      "bottom_sheet.swift",
      "date_picker.swift",
      "time_picker.swift",
      "date_range_picker.swift",
    ] {
      let source = try String(
        contentsOf: packageRoot
          .appendingPathComponent("Sources/RufletEngine/Controls")
          .appendingPathComponent(file),
        encoding: .utf8)
      XCTAssertTrue(
        source.contains("RufletPresentationLifecycleAnchor()"),
        "\(file) can miss its opening edge when its initial body is empty")
    }
  }

  private func properties(for type: String) -> [String: RufletValue] {
    switch type {
    case "CupertinoActivityIndicator": return [:]
    case "Banner":
      return ["open": .bool(false)]
    case "ShaderMask":
      return ["shader": gradient]
    case "Shimmer":
      return ["gradient": gradient]
    default: return [:]
    }
  }

  private var gradient: RufletValue {
    .map([
      "_type": .string("linear"),
      "colors": .array([.string("#000000"), .string("#ffffff")]),
    ])
  }
}

@MainActor
private final class PresentationPrimitiveBackend: RufletBackendProtocol {
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
