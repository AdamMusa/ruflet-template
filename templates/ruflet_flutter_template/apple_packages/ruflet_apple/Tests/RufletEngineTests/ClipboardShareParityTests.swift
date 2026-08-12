import Foundation
import RufletEngine
import RufletProtocol
import XCTest

final class ClipboardShareParityTests: XCTestCase {
  private func call(_ method: String, _ args: [String: RufletValue]) -> RufletMethodCall {
    RufletMethodCall(controlID: 1, callID: "test", name: method, args: .map(args))
  }

  func testClipboardPreservesEmptyTextAndRejectsNonStrings() throws {
    XCTAssertEqual(try FletCoreServiceSemantics.clipboardText(.string("")), "")
    XCTAssertThrowsError(try FletCoreServiceSemantics.clipboardText(nil))
    XCTAssertThrowsError(try FletCoreServiceSemantics.clipboardText(.int(1)))
  }

  func testClipboardFileArgumentsKeepOrderAndRequirePaths() throws {
    XCTAssertEqual(
      try FletCoreServiceSemantics.clipboardFiles(.array([.string("/a"), .string("/b")])),
      ["/a", "/b"])
    XCTAssertEqual(try FletCoreServiceSemantics.clipboardFiles(.array([])), [])
    XCTAssertThrowsError(try FletCoreServiceSemantics.clipboardFiles(nil))
    XCTAssertThrowsError(try FletCoreServiceSemantics.clipboardFiles(.array([.int(1)])))
  }

  func testShareTextKeepsMetadataDefaultsAndEmptyText() throws {
    let request = try FletShareSemantics.request(call("share_text", [
      "text": .string(""), "title": .string("Title"), "subject": .string("Subject"),
    ]))
    XCTAssertEqual(request.text, "")
    XCTAssertEqual(request.title, "Title")
    XCTAssertEqual(request.subject, "Subject")
    XCTAssertTrue(request.downloadFallbackEnabled)
    XCTAssertTrue(request.mailToFallbackEnabled)
    XCTAssertEqual(request.files, [])
  }

  func testShareURIAndPopoverPositionRemainTyped() throws {
    let request = try FletShareSemantics.request(call("share_uri", [
      "uri": .string("https://flet.dev"),
      "share_position_origin": .map(["x": .double(4), "y": .double(5)]),
      "excluded_cupertino_activities": .array([.string("mail"), .string("airDrop")]),
    ]))
    XCTAssertEqual(request.uri, "https://flet.dev")
    XCTAssertEqual(request.position, CGRect(x: 4, y: 5, width: 0, height: 0))
    XCTAssertEqual(request.excludedCupertinoActivities, ["mail", "airDrop"])
  }

  func testShareFilesAcceptPathsAndBinaryDataWithFletNamesAndMIME() throws {
    let request = try FletShareSemantics.request(call("share_files", [
      "files": .array([
        .map(["path": .string("/tmp/photo.png")]),
        .map([
          "data": .binary([1, 2, 3]), "mime_type": .string("image/png"),
          "name": .string("preview.png"),
        ]),
      ]),
      "text": .string("Attached"),
      "preview_thumbnail": .map([
        "data": .array([.int(9), .int(8)]), "name": .string("thumb.png"),
      ]),
    ]))
    XCTAssertEqual(request.text, "Attached")
    XCTAssertEqual(request.files[0].name, "photo.png")
    XCTAssertEqual(request.files[1].name, "preview.png")
    XCTAssertEqual(request.files[1].data, [1, 2, 3])
    XCTAssertEqual(request.files[1].mimeType, "image/png")
    XCTAssertEqual(request.files[1].fileNameOverride, "preview.png")
    XCTAssertEqual(request.previewThumbnail?.data, [9, 8])
  }

  func testShareFileNamingMatchesPinnedDartFallbacks() throws {
    let request = try FletShareSemantics.request(call("share_files", [
      "files": .array([
        .map(["path": .string("/tmp/a.txt"), "name": .string("   ")]),
        .map(["data": .binary([]), "name": .string("")]),
      ])
    ]))
    XCTAssertEqual(request.files.map(\.name), ["shared_file", "shared_file"])
    XCTAssertEqual(request.files.map(\.fileNameOverride), ["a.txt", "shared_file"])
  }

  func testShareRejectsMissingAndMalformedPayloads() {
    XCTAssertThrowsError(try FletShareSemantics.request(call("share_text", [:])))
    XCTAssertThrowsError(try FletShareSemantics.request(call("share_uri", [:])))
    XCTAssertThrowsError(try FletShareSemantics.request(call("share_files", [
      "files": .array([]),
    ])))
    XCTAssertThrowsError(try FletShareSemantics.request(call("share_files", [
      "files": .array([.map(["data": .array([.int(256)])])]),
    ])))
  }

  func testShareResultUsesFletsExactMapShape() {
    XCTAssertEqual(
      FletShareSemantics.result(status: "dismissed", raw: ""),
      .map(["status": .string("dismissed"), "raw": .string("")]))
  }
}
