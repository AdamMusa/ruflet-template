@testable import RufletEngine
import RufletProtocol
import XCTest

final class WindowServiceParityTests: XCTestCase {
  @MainActor
  private final class RecordingWindowHost: RufletWindowHost {
    var actions: [RufletWindowAction] = []
    var error: Error?

    func perform(
      _ action: RufletWindowAction,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
      actions.append(action)
      if let error { completion(.failure(error)) } else { completion(.success(())) }
    }
  }

  @MainActor
  private func invoke(
    _ service: WindowService,
    method: String,
    args: RufletValue = .map([:])
  ) -> Result<RufletValue, Error>? {
    var reply: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 1, callID: "test", name: method, args: args),
      node: ControlNode(id: 1, type: "Window"),
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { reply = $0 }
    return reply
  }

  @MainActor
  func testEveryFletWindowMethodReachesTheNativeHost() throws {
    let host = RecordingWindowHost()
    let service = WindowService(host: host)

    for method in [
      "center", "close", "destroy", "start_dragging", "to_front",
      "wait_until_ready_to_show"
    ] {
      XCTAssertEqual(try invoke(service, method: method)?.get(), .null, method)
    }
    XCTAssertEqual(
      try invoke(
        service, method: "start_resizing",
        args: .map(["edge": .string("bottom_right")]))?.get(),
      .null)

    XCTAssertEqual(host.actions, [
      .center, .close, .destroy, .startDragging, .toFront,
      .waitUntilReadyToShow, .startResizing(edge: "bottom_right")
    ])
  }

  @MainActor
  func testUnknownResizeEdgeMatchesFletNoOp() throws {
    let host = RecordingWindowHost()
    let service = WindowService(host: host)
    XCTAssertEqual(
      try invoke(
        service, method: "start_resizing",
        args: .map(["edge": .string("diagonal")]))?.get(),
      .null)
    XCTAssertTrue(host.actions.isEmpty)
  }

  @MainActor
  func testHostFailuresRemainClassifiedAtCommandBoundary() {
    let host = RecordingWindowHost()
    host.error = RufletServiceError.platformUnsupported(
      type: "Window", method: "center", platform: "iOS")
    let reply = invoke(WindowService(host: host), method: "center")
    guard case .failure(let error)? = reply,
      case .platformUnsupported("Window", "center", "iOS") = error as? RufletServiceError
    else { return XCTFail("expected the native platform classification") }
  }

  @MainActor
  func testDefaultRegistryMountsWindowService() {
    let registry = ServiceRegistry()
    registry.registerDefaults()
    XCTAssertTrue(registry.handles("Window"))
    XCTAssertTrue(registry.service(for: ControlNode(id: 44, type: "Window")) is WindowService)
  }
}
