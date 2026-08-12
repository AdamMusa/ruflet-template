import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class RufletAppControlTests: XCTestCase {
  func testRufletAppIsTheOnlyNativeApplicationWireName() {
    let canonical = ControlRegistry.descriptor(for: "RufletApp")

    XCTAssertEqual(canonical?.classification, .visible)
    XCTAssertEqual(canonical?.implementation, "RufletAppControlView")
    XCTAssertNil(ControlRegistry.descriptor(for: "FletApp"))
  }

  func testNestedAppInheritsParentEndpointWhenURLIsOmitted() {
    let parent = URL(string: "wss://example.test/custom")!
    XCTAssertEqual(RufletAppEndpoint.resolve(nil, inheriting: parent), parent)
    XCTAssertEqual(RufletAppEndpoint.resolve("", inheriting: parent), parent)
  }

  func testNestedAppNormalizesHTTPServerURLsToWebSockets() {
    XCTAssertEqual(
      RufletAppEndpoint.resolve("http://127.0.0.1:8550", inheriting: nil)?.absoluteString,
      "ws://127.0.0.1:8550/ws")
    XCTAssertEqual(
      RufletAppEndpoint.resolve("https://example.test/ruflet", inheriting: nil)?.absoluteString,
      "wss://example.test/ruflet/ws")
    XCTAssertNil(RufletAppEndpoint.resolve("ftp://example.test/ruflet", inheriting: nil))
  }

  func testConfigurationPreservesPinnedFletDefaultsAndDurations() {
    let defaults = RufletAppConfiguration(node: ControlNode(id: 1, type: "RufletApp"))
    XCTAssertEqual(defaults.url, "")
    XCTAssertEqual(defaults.reconnectInterval, 0.5)
    XCTAssertNil(defaults.reconnectTimeout)
    XCTAssertFalse(defaults.showStartupScreen)
    XCTAssertEqual(defaults.startupMessage, "")
    XCTAssertNil(defaults.args)
    XCTAssertNil(defaults.forcePyodide)

    let configured = RufletAppConfiguration(node: ControlNode(
      id: 1, type: "RufletApp", props: [
        "reconnect_interval_ms": 250,
        "reconnect_timeout_ms": 10_000,
        "show_app_startup_screen": true,
        "app_startup_screen_message": "Connecting…",
        "args": .map(["mode": "test"]),
        "force_pyodide": true
      ]))
    XCTAssertEqual(configured.reconnectInterval, 0.25)
    XCTAssertEqual(configured.reconnectTimeout, 10)
    XCTAssertTrue(configured.showStartupScreen)
    XCTAssertEqual(configured.startupMessage, "Connecting…")
    XCTAssertEqual(configured.args, ["mode": "test"])
    XCTAssertEqual(configured.forcePyodide, true)
    XCTAssertNil(configured.validationError)
  }

  func testConfigurationRejectsNonMapArguments() {
    let configuration = RufletAppConfiguration(node: ControlNode(
      id: 1, type: "RufletApp", props: ["args": .array([])]))
    XCTAssertEqual(configuration.validationError, "RufletApp.args must be a map.")
  }

  func testErrorTemplateMatchesFletMessageAndDetailsSubstitution() {
    let defaults = RufletAppConfiguration(node: ControlNode(id: 1, type: "RufletApp"))
    XCTAssertEqual(
      defaults.formatError("Syntax error\nline 4\nline 5"),
      "The application encountered an error: Syntax error\n\nline 4\nline 5")
    XCTAssertEqual(
      defaults.formatError("Disconnected"),
      "The application encountered an error: Disconnected")

    let custom = RufletAppConfiguration(node: ControlNode(
      id: 1, type: "RufletApp", props: [
        "app_error_message": "Failed: {message}\n{details}"
      ]))
    XCTAssertEqual(custom.formatError("Boom\ntrace"), "Failed: Boom\ntrace")
    XCTAssertEqual(custom.formatError("Boom"), "Failed: Boom")
  }
}
