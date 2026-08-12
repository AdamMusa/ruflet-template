import XCTest
@testable import RufletEngine
import RufletProtocol

final class FilePickerPluginParityTests: XCTestCase {
  private func call(_ args: [String: RufletValue], name: String = "pick_files") -> RufletMethodCall {
    RufletMethodCall(controlID: 7, callID: "file-picker-test", name: name, args: .map(args))
  }

  func testPinnedFletDefaultsAndAllowedExtensionsForceCustomType() {
    let defaults = FilePickerConfiguration(call([:]))
    XCTAssertEqual(defaults.fileType, .any)
    XCTAssertFalse(defaults.allowMultiple)
    XCTAssertFalse(defaults.withData)
    XCTAssertNil(defaults.dialogTitle)
    XCTAssertNil(defaults.initialDirectory)
    XCTAssertEqual(defaults.allowedExtensions, [])

    let custom = FilePickerConfiguration(call([
      "file_type": .string("image"),
      "allowed_extensions": .array([.string(".rb"), .string("txt")]),
      "allow_multiple": .bool(true),
      "with_data": .bool(true),
    ]))
    XCTAssertEqual(custom.fileType, .custom)
    XCTAssertEqual(custom.allowedExtensions, ["rb", "txt"])
    XCTAssertTrue(custom.allowMultiple)
    XCTAssertTrue(custom.withData)
  }

  func testFileResultAlwaysCarriesAllPinnedFletKeysIncludingNulls() {
    let result = FilePickerFile(
      id: 3, name: "main.rb", path: "/tmp/main.rb", size: 42, bytes: nil
    ).wireValue
    XCTAssertEqual(Set(result.mapValue?.keys.map { $0 } ?? []),
      ["id", "name", "path", "size", "bytes"])
    XCTAssertEqual(result["id"], .int(3))
    XCTAssertEqual(result["name"], .string("main.rb"))
    XCTAssertEqual(result["path"], .string("/tmp/main.rb"))
    XCTAssertEqual(result["size"], .int(42))
    XCTAssertEqual(result["bytes"], .null)
  }

  func testSourceBytesAcceptBinaryAndByteArrays() {
    XCTAssertEqual(FilePickerConfiguration(call([
      "src_bytes": .binary([0, 127, 255])
    ], name: "save_file")).sourceBytes, [0, 127, 255])
    XCTAssertEqual(FilePickerConfiguration(call([
      "src_bytes": .array([.int(0), .int(127), .int(255)])
    ], name: "save_file")).sourceBytes, [0, 127, 255])
  }

  func testUploadDefaultsToPutAndResolvesLikeFletPageURI() {
    let upload = FilePickerUploadRequest(.map([
      "name": .string("main.rb"), "upload_url": .string("/upload?id=4")
    ]))
    XCTAssertEqual(upload?.method, "PUT")
    XCTAssertEqual(
      upload?.resolvedURL(relativeTo: URL(string: "https://ruflet.dev:8443/app/session"))?.absoluteString,
      "https://ruflet.dev:8443/upload?id=4")

    let absolute = FilePickerUploadRequest(.map([
      "upload_url": .string("https://uploads.example/file"), "method": .string("POST")
    ]))
    XCTAssertEqual(absolute?.method, "POST")
    XCTAssertEqual(absolute?.resolvedURL(relativeTo: nil)?.absoluteString,
      "https://uploads.example/file")
  }

  @MainActor
  func testUploadBeforePickingReturnsNullWithoutInventingFailureEvent() {
    let service = FilePickerService()
    let node = ControlNode(
      id: 7, type: "FilePicker", props: ["on_upload": .bool(true)])
    var events: [(String, RufletValue)] = []
    var reply: Result<RufletValue, Error>?

    service.invoke(call([
      "files": .array([.map([
        "name": .string("not-selected.txt"),
        "upload_url": .string("https://uploads.example/file"),
        "method": .string("PUT"),
      ])])
    ], name: "upload"), node: node,
      context: RufletServiceContext(
        store: ControlStore(), emitEvent: { _, name, value in events.append((name, value)) })
    ) { reply = $0 }

    XCTAssertEqual(try? reply?.get(), .null)
    XCTAssertTrue(events.isEmpty)
  }

  @MainActor
  func testUploadEventUsesExactPinnedFletFieldsAndNulls() {
    let value = FilePickerService.uploadEvent(
      name: "main.rb", progress: nil, error: "offline")
    XCTAssertEqual(Set(value.mapValue?.keys.map { $0 } ?? []),
      ["file_name", "progress", "error"])
    XCTAssertEqual(value["file_name"], .string("main.rb"))
    XCTAssertEqual(value["progress"], .null)
    XCTAssertEqual(value["error"], .string("offline"))
  }

  @MainActor
  func testHTTPFailureRetainsFletColonForEmptyResponseBody() {
    XCTAssertEqual(
      FilePickerService.uploadHTTPError(status: 413, body: Data()),
      "Upload endpoint returned code 413: ")
    XCTAssertEqual(
      FilePickerService.uploadHTTPError(status: 500, body: Data("failed".utf8)),
      "Upload endpoint returned code 500: failed")
  }
}
