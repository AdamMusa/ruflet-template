@testable import RufletUI
import RufletEngine
import RufletProtocol
import XCTest

final class CollectionScrollToCommandParityTests: XCTestCase {
  private func command(_ args: [String: RufletValue]) -> CollectionScrollToCommand {
    CollectionScrollToCommand(RufletMethodCall(
      controlID: 10, callID: "scroll", name: "scroll_to", args: .map(args)))
  }

  func testListAndGridAdvertiseTheirMountedScrollCommand() throws {
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "ListView")).supportedMethods,
      ["scroll_to"])
    XCTAssertEqual(
      try XCTUnwrap(ControlRegistry.builtInDescriptor(for: "GridView")).supportedMethods,
      ["scroll_to"])
  }

  func testNumericArgumentsAndDefaultsMatchScrollableControl() {
    let value = command([
      "offset": .double(120.5), "delta": .double(8),
      "duration": .double(499.9), "curve": .string("easeOutCubic"),
    ])
    XCTAssertEqual(value.offset, 120.5)
    XCTAssertEqual(value.delta, 8)
    XCTAssertNil(value.scrollKey)
    // Dart parseDuration first parses a numeric duration as an integer.
    XCTAssertEqual(value.durationMilliseconds, 499)
    XCTAssertEqual(value.curve, "easeOutCubic")

    let defaults = command([:])
    XCTAssertNil(defaults.offset)
    XCTAssertNil(defaults.delta)
    XCTAssertNil(defaults.scrollKey)
    XCTAssertEqual(defaults.durationMilliseconds, 0)
    XCTAssertEqual(defaults.curve, "ease")
  }

  func testStructuredDurationUsesEveryPinnedFletUnit() {
    let value = command([
      "duration": .map([
        "days": .int(1), "hours": .int(2), "minutes": .int(3),
        "seconds": .int(4), "milliseconds": .int(5),
        "microseconds": .int(6_999),
      ])
    ])
    XCTAssertEqual(value.durationMilliseconds, 93_784_011)
  }

  func testNegativeOffsetsAreRelativeToEndThenClamped() {
    XCTAssertEqual(
      command(["offset": .double(-1)]).resolvedOffset(current: 20, maximum: 500),
      500)
    XCTAssertEqual(
      command(["offset": .double(-20)]).resolvedOffset(current: 20, maximum: 500),
      481)
    XCTAssertEqual(
      command(["offset": .double(-1_000)]).resolvedOffset(current: 20, maximum: 500),
      0)
    XCTAssertEqual(
      command(["offset": .double(900)]).resolvedOffset(current: 20, maximum: 500),
      500)
  }

  func testDeltaIsRelativeToCurrentOffsetAndClamped() {
    XCTAssertEqual(
      command(["delta": .double(35)]).resolvedOffset(current: 100, maximum: 500),
      135)
    XCTAssertEqual(
      command(["delta": .double(-150)]).resolvedOffset(current: 100, maximum: 500),
      0)
    XCTAssertNil(command([:]).resolvedOffset(current: 100, maximum: 500))
  }

  func testScrollKeyUnwrapsFletKeyObjectsAndMatchesChildKeys() {
    let children = [
      ControlNode(id: 20, type: "Text", props: ["key": .string("first")]),
      ControlNode(id: 21, type: "Text", props: [
        "key": .map(["_type": .string("scroll"), "value": .int(42)])
      ]),
      ControlNode(id: 22, type: "Text", props: ["key": .bool(true)]),
    ]

    XCTAssertEqual(
      command(["scroll_key": .string("first")]).targetID(in: children), 20)
    XCTAssertEqual(
      command(["scroll_key": .map([
        "_type": .string("scroll"), "value": .int(42),
      ])]).targetID(in: children), 21)
    XCTAssertEqual(
      command(["scroll_key": .bool(true)]).targetID(in: children), 22)
    XCTAssertNil(command(["scroll_key": .string("missing")]).targetID(in: children))
  }

  func testResolvedScrollKeyTakesPriorityButUnresolvedKeyFallsBackToOffset() {
    let child = ControlNode(
      id: 30, type: "Text", props: ["key": .string("target")])
    let resolved = command([
      "scroll_key": .string("target"), "offset": .double(70),
    ])
    XCTAssertEqual(resolved.targetID(in: [child]), 30)
    XCTAssertEqual(resolved.resolvedOffset(current: 0, maximum: 100), 70)

    let unresolved = command([
      "scroll_key": .string("missing"), "offset": .double(70),
    ])
    XCTAssertNil(unresolved.targetID(in: [child]))
    XCTAssertEqual(unresolved.resolvedOffset(current: 0, maximum: 100), 70)
  }
}
