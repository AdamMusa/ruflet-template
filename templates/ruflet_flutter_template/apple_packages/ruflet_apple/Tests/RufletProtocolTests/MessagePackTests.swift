import Foundation
import XCTest
@testable import RufletProtocol

final class MessagePackTests: XCTestCase {
  func testAllWireValueKindsRoundTrip() throws {
    let values: [RufletValue] = [
      .null,
      false,
      true,
      -33,
      -32,
      0,
      127,
      128,
      255,
      256,
      65_535,
      65_536,
      .int(Int64(Int32.max) + 1),
      .int(Int64.min),
      .int(Int64.max),
      1.25,
      "Ruflet \u{1F34E}",
      .binary(Data([0, 1, 2, 255])),
      [1, "two", false],
      ["nested": ["value": 7]],
      .extensionValue(type: 1, payload: Data("2026-08-15T12:00:00+00:00".utf8)),
    ]

    for value in values {
      XCTAssertEqual(
        try RufletMessagePack.decode(RufletMessagePack.encode(value)),
        value,
        "round trip failed for \(value)")
    }
  }

  func testIntegerEncodingUsesMessagePackBoundaryMarkers() {
    XCTAssertEqual(bytes(for: 127), [0x7f])
    XCTAssertEqual(bytes(for: -32), [0xe0])
    XCTAssertEqual(bytes(for: 128), [0xcc, 0x80])
    XCTAssertEqual(bytes(for: 256), [0xcd, 0x01, 0x00])
    XCTAssertEqual(bytes(for: -33), [0xd0, 0xdf])
    XCTAssertEqual(bytes(for: -129), [0xd1, 0xff, 0x7f])
  }

  func testIntegerMapKeysRoundTripWithoutStringCoercion() throws {
    let value = RufletValue.keyedMap([
      .string("children"): .array([1, 2]),
      .int(0): .array([3, 4]),
      .int(12): "position",
    ])

    let decoded = try RufletMessagePack.decode(RufletMessagePack.encode(value))
    XCTAssertEqual(decoded, value)
    XCTAssertEqual(decoded.keyedMap?[.int(0)], .array([3, 4]))
    XCTAssertNil(decoded.map)
  }

  func testStringOnlyMapsPreserveSourceCompatibleRepresentation() throws {
    let value: RufletValue = ["route": "/", "page": ["width": 390]]
    let decoded = try RufletMessagePack.decode(RufletMessagePack.encode(value))

    XCTAssertEqual(decoded, value)
    XCTAssertNotNil(decoded.map)
    XCTAssertEqual(decoded.keyedMap?[.string("route")], "/")
  }

  func testPatchTreeIndexRetainsPropertyAndPositionKeyTypes() throws {
    let tree = RufletValue.keyedMap([
      .string("data_series"): .array([
        1,
        .keyedMap([
          .int(0): .array([
            2,
            .map(["data_points": .array([3])]),
          ]),
        ]),
      ]),
    ])
    let patch: RufletValue = .array([
      .array([0, tree]),
      .array([2, 3, 1]),
    ])

    let decoded = try RufletMessagePack.decode(RufletMessagePack.encode(patch))
    guard let decodedTree = decoded.array?.first?.array?[1] else {
      return XCTFail("patch tree index must survive the wire round trip")
    }
    XCTAssertNotNil(decodedTree.keyedMap?[.string("data_series")])
    let positionMap = decodedTree.keyedMap?[.string("data_series")]?
      .array?[1].keyedMap
    XCTAssertNotNil(positionMap?[.int(0)])
    XCTAssertNil(positionMap?[.string("0")])
  }

  func testTemporalExtensionsMatchPinnedFletPayloads() {
    XCTAssertEqual(
      RufletMessagePack.temporalTime(hour: 9, minute: 5),
      .extensionValue(type: 2, payload: Data("9:5".utf8)))
    XCTAssertEqual(
      RufletMessagePack.temporalDuration(microseconds: 1_234_567),
      .extensionValue(type: 3, payload: Data("1234567".utf8)))

    let date = Date(timeIntervalSince1970: 0)
    guard case .extensionValue(let type, let payload) = RufletMessagePack.temporalDate(date) else {
      return XCTFail("Date must encode as a MessagePack extension")
    }
    XCTAssertEqual(type, 1)
    let text = String(decoding: payload, as: UTF8.self)
    XCTAssertTrue(text.hasSuffix("+00:00"))
    XCTAssertFalse(text.hasSuffix("Z"))
  }

  func testUnknownExtensionDecodesAsNullLikePinnedFletDecoder() throws {
    let encoded = RufletMessagePack.encode(
      .extensionValue(type: 7, payload: Data([1, 2, 3, 4])))
    XCTAssertEqual(try RufletMessagePack.decode(encoded), .null)
  }

  func testStreamingDecoderRetainsIncompleteTrailingValue() throws {
    let first: RufletValue = ["id": 1, "type": "Page"]
    let second: RufletValue = ["id": 2, "type": "View", "route": "/demo"]
    let firstData = RufletMessagePack.encode(first)
    let secondData = RufletMessagePack.encode(second)
    let split = secondData.count / 2

    var decoder = RufletStreamingMessagePackDecoder()
    decoder.append(firstData + secondData.prefix(split))
    XCTAssertEqual(try decoder.decodeAvailable(), [first])

    decoder.append(secondData.suffix(from: split))
    XCTAssertEqual(try decoder.decodeAvailable(), [second])
    XCTAssertEqual(try decoder.decodeAvailable(), [])
  }

  func testStreamingDecoderAcceptsSingleByteChunks() throws {
    let message = RufletMessage(
      action: .patchControl,
      payload: ["id": 1, "patch": []])
    let encoded = RufletMessagePack.encode(.array(message.list))
    var decoder = RufletStreamingMessagePackDecoder()
    var decoded: [RufletValue] = []

    for byte in encoded {
      decoder.append(Data([byte]))
      decoded += try decoder.decodeAvailable()
    }

    XCTAssertEqual(decoded, [.array(message.list)])
  }

  func testTruncatedAndInvalidDataFailWithProtocolErrors() {
    XCTAssertThrowsError(try RufletMessagePack.decode(Data([0xda, 0x00]))) {
      XCTAssertEqual($0 as? RufletProtocolError, .truncatedMessagePack)
    }
    XCTAssertThrowsError(try RufletMessagePack.decode(Data([0xc1]))) {
      XCTAssertEqual($0 as? RufletProtocolError, .unsupportedMessagePackMarker(0xc1))
    }
  }

  private func bytes(for value: Int64) -> [UInt8] {
    Array(RufletMessagePack.encode(.int(value)))
  }
}
