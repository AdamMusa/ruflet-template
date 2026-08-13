import RufletProtocol
import SwiftUI
import Testing

@testable import RufletEngine

@MainActor
@Suite("Pinned Flet scrollable contract")
struct ScrollableControlContractTests {
  @Test("offset, negative offset, and delta resolve against native metrics")
  func offsets() {
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: 25,
        delta: nil,
        current: 10,
        maximum: 100) == 25)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: -1,
        delta: nil,
        current: 10,
        maximum: 100) == 100)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: -10,
        delta: nil,
        current: 10,
        maximum: 100) == 91)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: nil,
        delta: 15,
        current: 10,
        maximum: 100) == 25)
    #expect(
      RufletScrollViewport.resolveOffset(
        offset: nil,
        delta: -50,
        current: 10,
        maximum: 100) == 0)
  }

  @Test("all Flet key scalar types retain the same scroll registry identity")
  func keys() {
    #expect(parseKey(["_type": "scroll", "value": 7])?.description == "7")
    #expect(parseKey(["_type": "scroll", "value": "hero"])?.description == "hero")
    #expect(parseKey(["_type": "scroll", "value": true])?.description == "true")
    #expect(parseKey(["_type": "scroll", "value": 2.5])?.description == "2.5")
  }

  @Test("every native list family mounts the shared ScrollableControl")
  func listFamiliesUseSharedContract() throws {
    let sources = [
      "list_view.swift",
      "grid_view.swift",
      "reorderable_list_view.swift",
    ]
    let root = packageRoot.appendingPathComponent("Sources/RufletEngine/Controls")
    for source in sources {
      let text = try String(contentsOf: root.appendingPathComponent(source), encoding: .utf8)
      #expect(text.contains("ScrollableControl("), Comment(rawValue: source))
      #expect(text.contains("RufletScrollViewportAttachment"), Comment(rawValue: source))
    }
  }

  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
