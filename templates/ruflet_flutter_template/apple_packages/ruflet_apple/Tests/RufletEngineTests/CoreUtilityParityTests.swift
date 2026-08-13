import XCTest
@testable import RufletEngine

private actor UtilityCounter {
  private var stored = 0
  func increment() { stored += 1 }
  var value: Int { stored }
}

final class CoreUtilityParityTests: XCTestCase {
  func testLruCachePromotesReadsAndEvictsLeastRecentValue() {
    var cache = LruCache<String, Int>(2)
    cache.set("a", 1)
    cache.set("b", 2)
    XCTAssertEqual(cache.get("a"), 1)
    cache.set("c", 3)
    XCTAssertNil(cache.get("b"))
    XCTAssertEqual(cache.get("a"), 1)
    XCTAssertEqual(cache.get("c"), 3)
  }

  func testWeakValueMapDoesNotOwnValues() {
    final class Value {}
    let map = WeakValueMap<String, Value>()
    var value: Value? = Value()
    map.set("value", value!)
    XCTAssertEqual(map.length, 1)
    value = nil
    XCTAssertNil(map.get("value"))
    XCTAssertEqual(map.length, 0)
  }

  func testLockSerializesAcquisitionsInFIFOOrder() async {
    let lock = Lock()
    let counter = UtilityCounter()
    await lock.acquire()
    let task = Task {
      await lock.acquire()
      await counter.increment()
      await lock.release()
    }
    try? await Task<Never, Never>.sleep(nanoseconds: 20_000_000)
    let valueWhileLocked = await counter.value
    XCTAssertEqual(valueWhileLocked, 0)
    await lock.release()
    _ = await task.result
    let valueAfterRelease = await counter.value
    XCTAssertEqual(valueAfterRelease, 1)
  }

  @MainActor
  func testDebouncerRunsOnlyMostRecentAction() async {
    let debouncer = Debouncer(milliseconds: 5)
    var values: [Int] = []
    debouncer.run { values.append(1) }
    debouncer.run { values.append(2) }
    try? await Task<Never, Never>.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(values, [2])
    debouncer.dispose()
  }

  func testPrivateHostAndIPv4Conversion() async throws {
    XCTAssertEqual(try ipToInt("127.0.0.1"), 0x7F00_0001)
    XCTAssertEqual(try ipToInt("192.168.1.2"), 0xC0A8_0102)
    let loopbackIsPrivate = try await isPrivateHost("127.0.0.1")
    let publicResolverIsPrivate = try await isPrivateHost("8.8.8.8")
    XCTAssertTrue(loopbackIsPrivate)
    XCTAssertFalse(publicResolverIsPrivate)
  }

  func testWindowResizeEdgeParsingUsesPinnedWireNames() {
    XCTAssertEqual(parseWindowResizeEdge("topLeft"), .topLeft)
    XCTAssertEqual(parseWindowResizeEdge("BOTTOMRIGHT"), .bottomRight)
    XCTAssertNil(parseWindowResizeEdge("middle"))
  }
}
