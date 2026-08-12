import RufletEngine
import RufletProtocol
@testable import RufletUI
import XCTest

final class BannerSlotResidualTests: XCTestCase {
  func testStringContentSatisfiesBannerContractWhenAnActionIsVisible() {
    let banner = ControlNode(
      id: 1, type: "Banner",
      props: ["content": .string("Offline"), "actions": .array([.controlRef(2)])])
    XCTAssertNil(OverlayDefaults.bannerValidation(
      banner, content: nil, visibleActionCount: 1))
    XCTAssertEqual(
      OverlayDefaults.bannerValidation(banner, content: nil, visibleActionCount: 0),
      OverlayDefaults.bannerMissingActionsError)
  }

  func testNonStringScalarContentRemainsInvalid() {
    for value: RufletValue in [.int(1), .double(1.5), .bool(true)] {
      let banner = ControlNode(id: 1, type: "Banner", props: ["content": value])
      XCTAssertEqual(
        OverlayDefaults.bannerValidation(banner, content: nil, visibleActionCount: 1),
        OverlayDefaults.bannerMissingContentError)
    }
  }

  func testActionLayoutUsesOnlyResolvedVisibleChildrenInWireOrder() {
    let banner = ControlNode(
      id: 1, type: "Banner",
      props: ["actions": .array([.controlRef(2), .controlRef(3), .controlRef(4)])])
    let visibility = { (id: Int) -> Bool? in
      if id == 2 { return true }
      if id == 3 { return false }
      return nil
    }
    XCTAssertEqual(BannerSlots.visibleActionIDs(banner, visibilityForID: visibility), [2])
  }
}
