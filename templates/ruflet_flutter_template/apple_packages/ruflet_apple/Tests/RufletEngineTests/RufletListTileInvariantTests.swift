import XCTest
@testable import RufletEngine

@MainActor
final class RufletListTileInvariantTests: XCTestCase {
  func testToggleInputListenersRunInRegistrationOrder() {
    let notifier = RufletListTileClickNotifier()
    var calls: [Int] = []
    notifier.addListener { calls.append(1) }
    notifier.addListener { calls.append(2) }

    notifier.onClick()

    XCTAssertEqual(calls, [1, 2])
  }

  func testRemovedToggleInputListenerDoesNotRun() {
    let notifier = RufletListTileClickNotifier()
    var calls = 0
    let listenerID = notifier.addListener { calls += 1 }
    notifier.removeListener(listenerID)

    notifier.onClick()

    XCTAssertEqual(calls, 0)
  }
}
