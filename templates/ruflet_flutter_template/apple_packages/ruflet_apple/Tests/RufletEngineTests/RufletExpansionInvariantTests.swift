import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class RufletExpansionInvariantTests: XCTestCase {
  func testTileCommitsPropertyBeforeChangeEventWithoutParentNotification() {
    let backend = ExpansionTestBackend()
    let tile = RufletControl(id: 1, type: "ExpansionTile", properties: [:], backend: backend)

    rufletCommitExpansion(
      target: tile,
      expanded: true,
      notify: false,
      eventControl: tile,
      eventData: .bool(true))

    XCTAssertEqual(backend.operations, ["update:1:true:false", "event:1:change:true"])
  }

  func testPanelCommitsChildWithNotificationThenIndexesParentEvent() {
    let backend = ExpansionTestBackend()
    let list = RufletControl(id: 10, type: "ExpansionPanelList", properties: [:], backend: backend)
    let panel = RufletControl(id: 11, type: "ExpansionPanel", properties: [:], backend: backend)

    rufletCommitExpansion(
      target: panel,
      expanded: false,
      notify: true,
      eventControl: list,
      eventData: .int(3))

    XCTAssertEqual(backend.operations, ["update:11:false:true", "event:10:change:3"])
  }
}

@MainActor
private final class ExpansionTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var operations: [String] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    operations.append("event:\(control.id):\(name):\(wireString(data))")
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    operations.append("update:\(id):\(properties["expanded"]?.bool == true):\(notify)")
  }

  func resolveAssetSource(_ value: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}

  private func wireString(_ value: RufletValue) -> String {
    if let value = value.bool { return String(value) }
    if let value = value.integer { return String(value) }
    return "null"
  }
}
