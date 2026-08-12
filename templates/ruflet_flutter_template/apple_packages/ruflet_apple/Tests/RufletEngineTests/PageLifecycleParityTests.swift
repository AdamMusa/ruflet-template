import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

@MainActor
final class PageLifecycleParityTests: XCTestCase {
  func testEveryPinnedFletLifecycleNameIsPreserved() {
    XCTAssertEqual(
      FletPageLifecycleSemantics.State.allCases.map(\.rawValue),
      ["show", "resume", "hide", "inactive", "pause", "detach", "restart"])
  }

  func testLifecyclePayloadMatchesFletPageEventShape() {
    XCTAssertEqual(
      FletPageLifecycleSemantics.payload(.pause),
      .map(["state": .string("pause")]))
  }

  func testRestartIsEmittedOnlyWhenReturningFromPause() {
    XCTAssertEqual(FletPageLifecycleSemantics.foregroundStates(wasPaused: false), [.show])
    XCTAssertEqual(
      FletPageLifecycleSemantics.foregroundStates(wasPaused: true),
      [.show, .restart])
  }

  func testPageDescriptorDeclaresTheNativeLifecycleEvent() {
    XCTAssertTrue(
      ControlRegistry.descriptor(for: "Page")?.supportedEvents
        .contains("app_lifecycle_state_change") == true)
  }

  #if os(macOS)
    func testOrientationCommandIsSuccessfulNoOpOffMobile() {
      let service = PageService()
      let store = ControlStore()
      var result: Result<RufletValue, Error>?
      service.invoke(
        RufletMethodCall(
          controlID: 1, callID: "orientation", name: "set_allowed_device_orientations",
          args: .map(["orientations": .array([.string("portrait_up")])])),
        node: nil,
        context: RufletServiceContext(store: store, emitEvent: { _, _, _ in }),
        completion: { result = $0 })
      guard case .success(.null)? = result else {
        return XCTFail("non-mobile orientation command must complete with null")
      }
    }
  #endif

  func testUnmountedPageScreenshotReturnsNull() {
    let service = PageService()
    let store = ControlStore()
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(
        controlID: 1, callID: "capture", name: "take_screenshot", args: .map([:])),
      node: nil,
      context: RufletServiceContext(store: store, emitEvent: { _, _, _ in }),
      completion: { result = $0 })
    guard case .success(.null)? = result else {
      return XCTFail("unmounted Page screenshot must return null")
    }
  }
}
