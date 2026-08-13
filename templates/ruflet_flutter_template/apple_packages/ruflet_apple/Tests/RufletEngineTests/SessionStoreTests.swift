import XCTest
@testable import RufletEngine

final class SessionStoreTests: XCTestCase {
  func testPinnedNonWebSessionStoreNeverPersistsValues() {
    XCTAssertNil(RufletSessionStore.getSessionID())
    XCTAssertNil(RufletSessionStore.get("custom"))

    RufletSessionStore.setSessionID("session-1")
    RufletSessionStore.set("custom", "value")

    XCTAssertNil(RufletSessionStore.getSessionID())
    XCTAssertNil(RufletSessionStore.get("custom"))
  }

  func testNilSessionWriteMatchesPinnedEmptyStringNoOp() {
    RufletSessionStore.setSessionID(nil)
    XCTAssertNil(RufletSessionStore.getSessionID())
  }
}
