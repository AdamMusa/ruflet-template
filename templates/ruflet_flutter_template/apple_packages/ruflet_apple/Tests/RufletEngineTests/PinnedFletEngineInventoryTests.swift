import Foundation
import XCTest

final class PinnedFletEngineInventoryTests: XCTestCase {
  func testEveryPinnedEngineSourceHasAnExplicitAppleDisposition() throws {
    let entries = try loadInventory()
    XCTAssertEqual(entries.count, 262, "Pinned Flet 0.80.5 engine source count changed")
    XCTAssertEqual(Set(entries.map(\.source)).count, entries.count, "Every source must be accounted once")

    let skipped = entries.filter { $0.disposition == "apple-skip" }
    XCTAssertEqual(
      Set(skipped.map(\.source)),
      [
        "transport/flet_backend_channel_javascript_io.dart",
        "transport/flet_backend_channel_javascript_web.dart",
        "transport/flet_backend_channel_mock.dart",
        "transport/js_interop.dart",
        "transport/js_interop_stub.dart",
        "utils/images_web.dart",
        "utils/platform_utils_web.dart",
        "utils/session_store_web.dart",
        "utils/user_fonts_web.dart",
      ],
      "Only pinned web, JavaScript, and mock transport files may be excluded from Apple")

    let eligible = entries.filter { $0.disposition != "apple-skip" }
    XCTAssertEqual(eligible.count, 253)
    XCTAssertTrue(eligible.allSatisfy { !$0.destination.isEmpty && $0.destination != "-" })
    XCTAssertTrue(eligible.allSatisfy { $0.destination.hasSuffix(".swift") })
    XCTAssertTrue(entries.allSatisfy {
      ["direct", "combined", "apple-skip"].contains($0.disposition)
    })
  }

  func testStructuralPortCoverageIsReportedFromThePinnedLedger() throws {
    let root = packageRoot()
    let eligible = try loadInventory().filter { $0.disposition != "apple-skip" }
    let present = eligible.filter {
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent($0.destination).path)
    }
    let missing = eligible.filter {
      !FileManager.default.fileExists(
        atPath: root.appendingPathComponent($0.destination).path)
    }

    print(
      "Pinned Flet 0.80.5 structural accounting: " +
      "\(present.count)/\(eligible.count) source entries have Swift destinations; " +
      "\(missing.count) remain structurally pending; 9 web/JS/mock files are Apple-excluded.")
    if !missing.isEmpty {
      let groups = Dictionary(grouping: missing, by: structuralGroup)
      let groupSummary = ["Controls", "Widgets", "Utils", "Extensions", "Other"]
        .map { "\($0) \(groups[$0, default: []].count)" }
        .joined(separator: ", ")
      print("Structurally pending groups: \(groupSummary).")
      print("Structurally pending pinned sources:\n" + missing.map {
        "  \($0.source) -> \($0.destination)"
      }.joined(separator: "\n"))
    }

    XCTAssertEqual(present.count + missing.count, eligible.count)
  }

  private func loadInventory() throws -> [PinnedFletEngineSource] {
    PinnedFletEngineInventory.entries
  }

  private func packageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func structuralGroup(_ entry: PinnedFletEngineSource) -> String {
    if entry.source.hasPrefix("controls/") { return "Controls" }
    if entry.source.hasPrefix("widgets/") { return "Widgets" }
    if entry.source == "utils.dart" || entry.source.hasPrefix("utils/") { return "Utils" }
    if entry.source.hasPrefix("extensions/") { return "Extensions" }
    return "Other"
  }
}
