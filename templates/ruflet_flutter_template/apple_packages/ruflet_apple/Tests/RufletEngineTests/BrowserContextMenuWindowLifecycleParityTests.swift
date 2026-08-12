@testable import RufletEngine
import RufletProtocol
import XCTest

final class BrowserContextMenuWindowLifecycleParityTests: XCTestCase {
  @MainActor
  private final class RecordingWindowHost: RufletWindowHost {
    var preventClose = false
    var eventHandler: ((RufletWindowEvent) -> Void)?
    var actions: [RufletWindowAction] = []

    func configureLifecycle(
      preventClose: Bool,
      eventHandler: @escaping (RufletWindowEvent) -> Void
    ) {
      self.preventClose = preventClose
      self.eventHandler = eventHandler
    }

    func perform(
      _ action: RufletWindowAction,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
      actions.append(action)
      completion(.success(()))
    }
  }

  @MainActor
  private func invoke(
    _ service: RufletService,
    method: String,
    args: RufletValue = .map([:]),
    node: ControlNode? = nil,
    context: RufletServiceContext? = nil
  ) -> Result<RufletValue, Error>? {
    var reply: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: node?.id ?? 1, callID: "test", name: method, args: args),
      node: node,
      context: context ?? RufletServiceContext(store: ControlStore()) { _, _, _ in }
    ) { reply = $0 }
    return reply
  }

  @MainActor
  func testBrowserContextMenuCommandsAreNoOpsOnApple() throws {
    RufletBrowserContextMenuPolicy.setEnabled(true)
    let service = BrowserContextMenuService()

    XCTAssertEqual(try invoke(service, method: "disable_menu")?.get(), .null)
    XCTAssertTrue(RufletBrowserContextMenuPolicy.isEnabled)
    XCTAssertEqual(try invoke(service, method: "enable_menu")?.get(), .null)
    XCTAssertTrue(RufletBrowserContextMenuPolicy.isEnabled)
  }

  func testWindowEventNamesAndStateShapeMatchPinnedFlet() {
    XCTAssertEqual(Set(RufletWindowEventType.allCases.map(\.rawValue)), Set([
      "close", "focus", "blur", "hide", "show", "maximize", "unmaximize",
      "minimize", "restore", "resize", "resized", "move", "moved",
      "leave-full-screen", "enter-full-screen",
    ]))

    let state = snapshot(maximized: true)
    XCTAssertEqual(Set(state.wireProperties.keys), Set([
      "maximized", "minimized", "full_screen", "always_on_top", "focused", "visible",
      "width", "height", "top", "left", "opacity",
    ]))
    XCTAssertEqual(state.wireProperties["maximized"], .bool(true))
    XCTAssertEqual(state.wireProperties["width"], .double(900))
    XCTAssertNil(state.wireProperties["prevent_close"])
    XCTAssertNil(state.wireProperties["resizable"])
  }

  @MainActor
  func testWindowLifecycleAppliesStateThenEmitsTypedEventWhenSubscribed() {
    let store = ControlStore()
    store.apply(ControlPatch(controlID: 2, operations: [
      .set(key: RufletControlKey.type, value: .string("Window")),
      .set(key: "prevent_close", value: .bool(true)),
      .set(key: "on_event", value: .bool(true)),
    ]))
    let host = RecordingWindowHost()
    let service = WindowService(host: host)
    var emitted: (Int, String, RufletValue)?
    let context = RufletServiceContext(store: store) { emitted = ($0, $1, $2) }

    service.activate(node: store.node(2)!, context: context)
    XCTAssertTrue(host.preventClose)
    host.eventHandler?(RufletWindowEvent(type: .maximize, state: snapshot(maximized: true)))

    XCTAssertEqual(store.node(2)?.bool("maximized"), true)
    XCTAssertEqual(store.node(2)?.double("width"), 900)
    XCTAssertEqual(emitted?.0, 2)
    XCTAssertEqual(emitted?.1, "event")
    XCTAssertEqual(emitted?.2, .map(["type": .string("maximize")]))

    XCTAssertEqual(try? invoke(
      service, method: "close", node: store.node(2), context: context)?.get(), .null)
    XCTAssertEqual(host.actions, [.close])
  }

  @MainActor
  func testWindowLifecycleUpdatesStateWithoutEmittingWhenNotSubscribed() {
    let store = ControlStore()
    store.apply(ControlPatch(controlID: 2, operations: [
      .set(key: RufletControlKey.type, value: .string("Window")),
      .set(key: "prevent_close", value: .bool(false)),
      .set(key: "on_event", value: .bool(false)),
    ]))
    let host = RecordingWindowHost()
    let service = WindowService(host: host)
    var eventCount = 0
    let context = RufletServiceContext(store: store) { _, _, _ in eventCount += 1 }

    service.activate(node: store.node(2)!, context: context)
    XCTAssertFalse(host.preventClose)
    host.eventHandler?(RufletWindowEvent(type: .minimize, state: snapshot(minimized: true)))

    XCTAssertEqual(store.node(2)?.bool("minimized"), true)
    XCTAssertEqual(eventCount, 0)
  }

  private func snapshot(
    maximized: Bool = false,
    minimized: Bool = false
  ) -> RufletWindowStateSnapshot {
    RufletWindowStateSnapshot(
      maximized: maximized,
      minimized: minimized,
      fullScreen: false,
      alwaysOnTop: false,
      focused: true,
      visible: true,
      width: 900,
      height: 600,
      top: 20,
      left: 40,
      opacity: 1)
  }
}
