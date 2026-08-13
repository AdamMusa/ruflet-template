import Foundation
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class AppleImageSourceUtilityTests: XCTestCase {
  private let svg =
    #"<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="red"/></svg>"#

  func testInlineSVGIsDataAndNeverSentThroughAssetResolution() {
    let backend = ImageSourceTestBackend()

    XCTAssertEqual(parseImageSource(svg, backend: backend), .data(Data(svg.utf8)))
    XCTAssertTrue(backend.resolvedSources.isEmpty)
  }

  func testPinnedSVGNamespaceDetectionWorksForBytesAndBase64() {
    let backend = ImageSourceTestBackend()
    let bytes = Data(svg.utf8)

    XCTAssertTrue(rufletIsSVGData(bytes))
    XCTAssertEqual(
      parseImageSource(bytes.base64EncodedString(), backend: backend),
      .data(bytes))
  }

  func testSVGFormatCoversBytesPathsAndResponseMIMEType() {
    let bytes = Data(svg.utf8)

    XCTAssertEqual(rufletImageFormat(source: .data(bytes), data: bytes), .svg)
    XCTAssertEqual(
      rufletImageFormat(
        source: .url(URL(string: "https://example.test/vector.svg?version=1")!),
        data: Data()),
      .svg)
    XCTAssertEqual(
      rufletImageFormat(
        source: .url(URL(string: "https://example.test/vector")!),
        data: Data(), mimeType: "image/svg+xml"),
      .svg)
  }

  func testSVGDocumentAppliesPinnedFitWithoutEnablingScripts() throws {
    let document = try XCTUnwrap(rufletSVGDocument(data: Data(svg.utf8), fit: .cover))

    XCTAssertTrue(document.contains(#"preserveAspectRatio="xMidYMid slice""#))
    XCTAssertTrue(document.contains("width:100%;height:100%;"))
  }
}

@MainActor
private final class ImageSourceTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var resolvedSources: [RufletValue] = []

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int, properties: [String: RufletValue], client: Bool, server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? {
    resolvedSources.append(source)
    return RufletAssetSource(path: "/assets/" + (source.text ?? ""), isFile: true)
  }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
