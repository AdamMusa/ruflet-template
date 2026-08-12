import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

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

  func testPageDescriptorDeclaresTheNativeLifecycleEvent() {
    XCTAssertTrue(
      ControlRegistry.descriptor(for: "Page")?.supportedEvents
        .contains("app_lifecycle_state_change") == true)
  }
}
