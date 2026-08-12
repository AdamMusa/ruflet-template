import XCTest

import RufletEngine
import RufletProtocol

@MainActor
final class TesterServiceParityTests: XCTestCase {
  private final class Driver: RufletTesterDriver {
    var queries: [RufletTesterQuery] = []
    var actions: [String] = []
    var screenshot = [UInt8]([1, 2, 3])

    func pump(durationMilliseconds: Double?, settle: Bool) async throws {
      actions.append("pump:\(durationMilliseconds.map { String($0) } ?? "nil"):\(settle)")
    }
    func find(_ query: RufletTesterQuery, in store: ControlStore) throws -> [Int] {
      queries.append(query)
      return [10, 20]
    }
    func takeScreenshot(name: String) async throws -> [UInt8] {
      actions.append("screenshot:\(name)")
      return screenshot
    }
    func tap(controlID: Int, context: RufletServiceContext) async throws {
      actions.append("tap:\(controlID)")
    }
    func tap(at offset: RufletTesterOffset, context: RufletServiceContext) async throws {
      actions.append("tap_at:\(offset.x):\(offset.y)")
    }
    func longPress(controlID: Int, context: RufletServiceContext) async throws {
      actions.append("long:\(controlID)")
    }
    func enterText(controlID: Int, text: String, context: RufletServiceContext) async throws {
      actions.append("text:\(controlID):\(text)")
    }
    func mouseHover(controlID: Int, context: RufletServiceContext) async throws {
      actions.append("hover:\(controlID)")
    }
    func teardown() { actions.append("teardown") }
  }

  private func invoke(
    _ service: TesterService, _ name: String, args: RufletValue = .map([:])
  ) async -> Result<RufletValue, Error> {
    await withCheckedContinuation { continuation in
      service.invoke(
        RufletMethodCall(controlID: 1, callID: "test", name: name, args: args),
        node: ControlNode(id: 1, type: "Tester"),
        context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
      ) { continuation.resume(returning: $0) }
    }
  }

  func testDurationOffsetKeyAndFinderWireSemantics() throws {
    XCTAssertEqual(FletTesterSemantics.durationMilliseconds(.double(16.9)), 16)
    XCTAssertEqual(
      FletTesterSemantics.durationMilliseconds(.extended(type: 3, string: "16500")), 16.5)
    XCTAssertEqual(
      FletTesterSemantics.offset(.array([.int(3), .double(4.5)])),
      RufletTesterOffset(x: 3, y: 4.5))
    XCTAssertEqual(
      try FletTesterSemantics.parsedKey(.map([
        "_type": .string("scroll"), "value": .string("items"),
      ])), .scroll(.string("items")))
    XCTAssertEqual(
      FletTesterSemantics.finderResult(id: 4, count: 2),
      .map(["id": .int(4), "count": .int(2)]))
    XCTAssertThrowsError(try FletTesterSemantics.parsedKey(.map([
      "_type": .string("future"), "value": .string("items"),
    ])))
    XCTAssertThrowsError(try FletTesterSemantics.parsedKey(.array([.int(1)])))
  }

  func testFindersAreStoredAndActionsUseFinderIndex() async throws {
    let driver = Driver()
    let service = TesterService(driver: driver)
    let finderResult = await invoke(
      service, "find_by_text", args: .map(["text": .string("Hello")]))
    let finder = try finderResult.get()
    let finderID = finder.mapValue!["id"]!.intValue!
    XCTAssertEqual(finder.mapValue?["count"], .int(2))
    XCTAssertEqual(driver.queries, [.text("Hello")])

    let tapResult = await invoke(
      service, "tap",
      args: .map(["finder_id": .int(Int64(finderID)), "finder_index": .int(1)]))
    XCTAssertEqual(try tapResult.get(), .null)
    XCTAssertEqual(driver.actions, ["tap:20"])
  }

  func testMissingFinderAndInvalidOffsetAreSilentLikeFlet() async throws {
    let driver = Driver()
    let service = TesterService(driver: driver)
    let missingFinder = await invoke(
      service, "tap", args: .map(["finder_id": .int(404)]))
    XCTAssertEqual(try missingFinder.get(), .null)
    let missingOffset = await invoke(service, "tap_at")
    XCTAssertEqual(try missingOffset.get(), .null)
    XCTAssertTrue(driver.actions.isEmpty)
  }

  func testPumpScreenshotAndTeardownUseNativeDriverSeam() async throws {
    let driver = Driver()
    let service = TesterService(driver: driver)
    let pumpResult = await invoke(
      service, "pump_and_settle",
      args: .map(["duration": .map(["milliseconds": .int(25)])]))
    XCTAssertEqual(try pumpResult.get(), .null)
    let screenshotResult = await invoke(
      service, "take_screenshot", args: .map(["name": .string("home")]))
    XCTAssertEqual(try screenshotResult.get(), .binary([1, 2, 3]))
    let teardownResult = await invoke(service, "teardown")
    XCTAssertEqual(try teardownResult.get(), .null)
    XCTAssertEqual(driver.actions, ["pump:25.0:true", "screenshot:home", "teardown"])
  }

  func testUnknownMethodsAndInvalidFinderIndexFailStrictly() async throws {
    let driver = Driver()
    let service = TesterService(driver: driver)
    do {
      let result = await invoke(service, "future_method")
      _ = try result.get()
      XCTFail("unknown Tester method must fail")
    } catch {}

    let finderResult = await invoke(
      service, "find_by_icon", args: .map(["icon": .string("home")]))
    let finder = try finderResult.get()
    let finderID = finder.mapValue!["id"]!.intValue!
    do {
      let result = await invoke(
        service, "long_press",
        args: .map(["finder_id": .int(Int64(finderID)), "finder_index": .int(2)]))
      _ = try result.get()
      XCTFail("out-of-range finder index must fail")
    } catch {}
  }

  func testMalformedArgumentsFailInsteadOfInvokingTheDriver() async throws {
    let driver = Driver()
    let service = TesterService(driver: driver)

    let textResult = await invoke(
      service, "find_by_text", args: .map(["text": .int(5)]))
    XCTAssertThrowsError(try textResult.get())
    let offsetResult = await invoke(
      service, "tap_at", args: .map(["offset": .string("bad")]))
    XCTAssertThrowsError(try offsetResult.get())
    let durationResult = await invoke(
      service, "pump", args: .map(["duration": .string("bad")]))
    XCTAssertThrowsError(try durationResult.get())
    XCTAssertTrue(driver.queries.isEmpty)
    XCTAssertTrue(driver.actions.isEmpty)
  }

  func testDefaultRegistryIncludesCoreTester() {
    let registry = ServiceRegistry()
    registry.registerDefaults()
    XCTAssertTrue(registry.handles("Tester"))
  }
}
