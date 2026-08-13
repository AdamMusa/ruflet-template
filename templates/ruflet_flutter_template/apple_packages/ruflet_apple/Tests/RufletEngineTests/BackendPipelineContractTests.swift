import CoreGraphics
import XCTest
@testable import RufletEngine
@testable import RufletProtocol

@MainActor
final class BackendPipelineContractTests: XCTestCase {
  func testRegistrationWaitsForFirstPageSize() async throws {
    let fixture = BackendPipelineFixture()
    let backend = fixture.makeBackend()

    backend.onRouteUpdated("/initial")
    await drainMainActor()

    XCTAssertEqual(fixture.channel?.connectCount ?? 0, 0)
    XCTAssertEqual(fixture.channel?.sentMessages ?? [], [])

    backend.updatePageSize(CGSize(width: 390, height: 844))
    try await waitUntil { fixture.channel?.sentMessages.count == 1 }

    let request = try XCTUnwrap(fixture.channel?.sentMessages.first)
    XCTAssertEqual(request.action, .registerClient)
    XCTAssertEqual(request.payload["page"]?["width"], .double(390))
    XCTAssertEqual(request.payload["page"]?["height"], .double(844))
  }

  func testRegistrationWindowContainsOnlyPinnedWindowProperties() async throws {
    let fixture = BackendPipelineFixture()
    let backend = fixture.makeBackend()

    backend.updatePageSize(CGSize(width: 320, height: 640))
    backend.onRouteUpdated("/")
    try await waitUntil { fixture.channel?.sentMessages.count == 1 }

    let request = try XCTUnwrap(fixture.channel?.sentMessages.first)
    XCTAssertEqual(request.payload["page"]?["window"], .map([:]))
  }

  func testRegistrationPatchIsAppliedBeforeQueuedEventIsDrained() async throws {
    var order: [String] = []
    let fixture = BackendPipelineFixture(onSend: { message in
      if message.action == .controlEvent { order.append("queued-event") }
    })
    let backend = fixture.makeBackend()
    let listener = backend.page.addListener {
      if backend.page.boolean("registered") == true {
        order.append("page-patch")
      }
    }
    defer { backend.page.removeListener(listener) }

    backend.updatePageSize(CGSize(width: 390, height: 844))
    backend.onRouteUpdated("/")
    try await waitUntil { fixture.channel?.sentMessages.first?.action == .registerClient }

    backend.triggerControlEvent(
      controlID: backend.page.id,
      name: "queued",
      data: "before-registration")
    XCTAssertEqual(fixture.channel?.sentMessages.map(\.action), [.registerClient])

    fixture.channel?.deliver(RufletMessage(
      action: .registerClient,
      payload: [
        "session_id": "session-1",
        "page_patch": ["registered": true],
        "error": nil,
      ]))

    XCTAssertEqual(order, ["page-patch", "queued-event"])
  }

  func testExistingRouteSendsUpdateBeforeRouteChangeEvent() async throws {
    let fixture = BackendPipelineFixture()
    let backend = fixture.makeBackend()
    backend.updatePageSize(CGSize(width: 390, height: 844))
    backend.onRouteUpdated("/initial")
    try await waitUntil { fixture.channel?.sentMessages.first?.action == .registerClient }
    fixture.channel?.deliver(RufletMessage(
      action: .registerClient,
      payload: ["page_patch": [:], "error": nil]))
    fixture.channel?.sentMessages.removeAll()

    backend.onRouteUpdated("/next")

    XCTAssertEqual(fixture.channel?.sentMessages.map(\.action), [
      .updateControl,
      .controlEvent,
    ])
    XCTAssertEqual(fixture.channel?.sentMessages[0].payload["props"]?["route"], "/next")
    XCTAssertEqual(fixture.channel?.sentMessages[1].payload["name"], "route_change")
    XCTAssertEqual(fixture.channel?.sentMessages[1].payload["data"]?["route"], "/next")
    XCTAssertEqual(backend.page.string("route"), "/next")
  }

  func testLaterPageSizeUpdatesDoNotOpenAnotherBackendSession() async throws {
    let fixture = BackendPipelineFixture()
    let backend = fixture.makeBackend()
    backend.updatePageSize(CGSize(width: 390, height: 844))
    backend.onRouteUpdated("/")
    try await waitUntil { fixture.channel?.sentMessages.first?.action == .registerClient }
    fixture.channel?.deliver(RufletMessage(
      action: .registerClient,
      payload: ["page_patch": [:], "error": nil]))

    backend.updatePageSize(CGSize(width: 844, height: 390))
    await drainMainActor()

    XCTAssertEqual(fixture.channels.count, 1)
    XCTAssertEqual(
      fixture.channel?.sentMessages.filter { $0.action == .registerClient }.count,
      1)
  }

  func testDisconnectClearsSessionBeforeReconnect() async throws {
    let fixture = BackendPipelineFixture()
    let backend = fixture.makeBackend()
    backend.updatePageSize(CGSize(width: 390, height: 844))
    backend.onRouteUpdated("/")
    try await waitUntil { fixture.channels.count == 1 }

    fixture.channel?.disconnectFromServer()

    try await waitUntil { fixture.channels.count == 2 }
    XCTAssertEqual(fixture.channels[1].connectCount, 1)
    XCTAssertEqual(fixture.channels[1].sentMessages.first?.action, .registerClient)
  }
}

@MainActor
private final class BackendPipelineFixture {
  var channels: [BackendPipelineChannel] = []
  var channel: BackendPipelineChannel? { channels.last }
  private let onSend: (RufletMessage) -> Void

  init(onSend: @escaping (RufletMessage) -> Void = { _ in }) {
    self.onSend = onSend
  }

  func makeBackend() -> RufletBackend {
    RufletBackend(
      pageURL: URL(string: "http://127.0.0.1:8550/pipeline")!,
      assetsDirectory: "",
      channelFactory: { [weak self] _, onDisconnect, onMessage in
        let channel = BackendPipelineChannel(
          onDisconnect: onDisconnect,
          onMessage: onMessage,
          onSend: self?.onSend ?? { _ in })
        self?.channels.append(channel)
        return channel
      })
  }
}

@MainActor
private final class BackendPipelineChannel: RufletBackendChannel {
  var isLocalConnection = true
  var defaultReconnectIntervalMilliseconds = 0
  var connectCount = 0
  var sentMessages: [RufletMessage] = []
  private let onDisconnect: () -> Void
  private let onMessage: (RufletMessage) -> Void
  private let onSend: (RufletMessage) -> Void

  init(
    onDisconnect: @escaping () -> Void,
    onMessage: @escaping (RufletMessage) -> Void,
    onSend: @escaping (RufletMessage) -> Void
  ) {
    self.onDisconnect = onDisconnect
    self.onMessage = onMessage
    self.onSend = onSend
  }

  func connect() async throws { connectCount += 1 }

  func send(_ message: RufletMessage) throws {
    sentMessages.append(message)
    onSend(message)
  }

  func disconnect() {}

  func deliver(_ message: RufletMessage) {
    onMessage(message)
  }

  func disconnectFromServer() {
    onDisconnect()
  }
}

@MainActor
private func drainMainActor(iterations: Int = 20) async {
  for _ in 0 ..< iterations { await Task.yield() }
}

@MainActor
private func waitUntil(
  iterations: Int = 200,
  _ predicate: () -> Bool
) async throws {
  for _ in 0 ..< iterations {
    if predicate() { return }
    await Task.yield()
  }
  throw BackendPipelineTestError.timedOut
}

private enum BackendPipelineTestError: Error {
  case timedOut
}
