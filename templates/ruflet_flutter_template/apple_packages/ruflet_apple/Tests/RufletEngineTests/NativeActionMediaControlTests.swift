import RufletProtocol
import SwiftUI
import XCTest
@testable import RufletEngine

@MainActor
final class NativeActionMediaControlTests: XCTestCase {
  func testActionAndMediaWireTypesResolveThroughCoreExtension() {
    let backend = ActionMediaBackend()
    for type in [
      "IconButton", "FilledIconButton", "FilledTonalIconButton", "OutlinedIconButton",
      "FloatingActionButton", "Image", "KeyboardListener",
    ] {
      let control = RufletControl(id: type.hashValue, type: type, properties: [:], backend: backend)
      XCTAssertNotNil(backend.extensionRegistry.view(for: control), type)
    }
  }

  func testImageSourceResolutionPreservesPinnedBytesAndAssetRules() {
    let backend = ActionMediaBackend()
    XCTAssertEqual(parseImageSource(Data([1, 2, 3]), backend: backend), .data(Data([1, 2, 3])))
    XCTAssertEqual(parseImageSource([1, 2, 3], backend: backend), .data(Data([1, 2, 3])))
    XCTAssertEqual(parseImageSource("AQID", backend: backend), .data(Data([1, 2, 3])))
    XCTAssertEqual(
      parseImageSource("photo.png", backend: backend),
      .url(URL(fileURLWithPath: "/assets/photo.png")))
  }

  func testImageEnumsMatchPinnedFletVocabulary() {
    XCTAssertEqual(parseEnum(RufletImageFit.self, "fitWidth"), .fitWidth)
    XCTAssertEqual(parseEnum(RufletImageRepeat.self, "repeatX"), .repeatX)
    XCTAssertEqual(parseEnum(RufletFilterQuality.self, "high"), .high)
  }
}

@MainActor
private final class ActionMediaBackend: RufletBackendProtocol {
  var pageURI: URL?
  lazy var extensionRegistry = RufletExtensionRegistry([RufletCoreExtension()])
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
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? {
    guard let text = source.text else { return nil }
    return RufletAssetSource(path: "/assets/\(text)", isFile: true)
  }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
