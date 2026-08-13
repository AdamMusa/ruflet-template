import XCTest
@testable import RufletEngine
@testable import RufletProtocol

final class RufletPickerInvariantTests: XCTestCase {
  func testTemporalDateRoundTripsThroughPinnedExtensionType() throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000.125)
    let wire = rufletDateValue(date)
    guard case .extensionValue(let type, _) = wire else {
      return XCTFail("Date must use Flet MessagePack extension type")
    }
    XCTAssertEqual(type, 1)
    XCTAssertEqual(try XCTUnwrap(parseRufletDate(wire)).timeIntervalSince1970,
      date.timeIntervalSince1970, accuracy: 0.001)
  }

  func testTemporalTimeUsesPinnedHourMinutePayload() {
    let time = RufletTimeOfDay(hour: 23, minute: 7)
    let wire = rufletTimeValue(time)
    XCTAssertEqual(parseRufletTime(wire), time)
    XCTAssertNil(parseRufletTime(.extensionValue(type: 2, payload: Data("24:00".utf8))))
  }

  func testDurationParsesNumericSecondsAndTemporalMicroseconds() throws {
    XCTAssertEqual(parseRufletWireDuration(.int(12), numberUnit: .seconds), 12)
    let wire = rufletDurationValue(12.345678)
    XCTAssertEqual(try XCTUnwrap(parseRufletWireDuration(wire)), 12.345678, accuracy: 0.000001)
  }
}
