import RufletEngine
import RufletProtocol
import XCTest

final class HapticSemanticsServiceParityTests: XCTestCase {
  private func call(_ method: String, _ args: [String: RufletValue] = [:])
    -> RufletMethodCall
  {
    RufletMethodCall(controlID: 1, callID: "test", name: method, args: .map(args))
  }

  func testHapticMethodsMatchThePinnedFletServiceExactly() throws {
    XCTAssertEqual(
      Set(FletHapticFeedbackSemantics.Method.allCases.map(\.rawValue)),
      ["heavy_impact", "light_impact", "medium_impact", "vibrate", "selection_click"])
    for method in FletHapticFeedbackSemantics.Method.allCases {
      XCTAssertEqual(
        try FletHapticFeedbackSemantics.method(method.rawValue).rawValue,
        method.rawValue)
    }
    XCTAssertThrowsError(try FletHapticFeedbackSemantics.method("impact"))
  }

  @MainActor
  func testUnknownHapticMethodDoesNotSucceedSilentlyOnMacOS() {
    var result: Result<RufletValue, Error>?
    HapticFeedbackService().invoke(
      call("impact"), node: nil,
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { result = $0 }
    guard case .failure(let error)? = result else {
      return XCTFail("unknown haptic methods must fail")
    }
    XCTAssertEqual(
      error as? RufletServiceError,
      .unsupportedMethod(type: "HapticFeedback", method: "impact"))
  }

  func testAnnouncementDefaultsMatchFletsDartHandler() throws {
    let announcement = try FletSemanticsServiceSemantics.announcement(call(
      "announce_message", ["message": .string("Saved")]))
    XCTAssertEqual(announcement.kind, .message)
    XCTAssertEqual(announcement.message, "Saved")
    XCTAssertFalse(announcement.rtl)
    XCTAssertEqual(announcement.assertiveness, .polite)
  }

  func testAnnouncementCarriesRTLAndAssertiveness() throws {
    let announcement = try FletSemanticsServiceSemantics.announcement(call(
      "announce_message",
      [
        "message": .string("تم الحفظ"), "rtl": .bool(true),
        "assertiveness": .string("assertive"),
      ]))
    XCTAssertTrue(announcement.rtl)
    XCTAssertEqual(announcement.assertiveness, .assertive)

    let unknown = try FletSemanticsServiceSemantics.announcement(call(
      "announce_message", ["message": .string("Saved"), "assertiveness": .string("other")]))
    XCTAssertEqual(unknown.assertiveness, .polite)
  }

  func testTooltipIsASeparatePoliteAnnouncement() throws {
    let tooltip = try FletSemanticsServiceSemantics.announcement(call(
      "announce_tooltip", ["message": .string("")]))
    XCTAssertEqual(tooltip.kind, .tooltip)
    XCTAssertEqual(tooltip.message, "")
    XCTAssertFalse(tooltip.rtl)
    XCTAssertEqual(tooltip.assertiveness, .polite)
  }

  func testDartMessageStringConversionPreservesEmptyAndNull() {
    XCTAssertEqual(FletSemanticsServiceSemantics.dartString(.string("")), "")
    XCTAssertEqual(FletSemanticsServiceSemantics.dartString(.int(7)), "7")
    XCTAssertEqual(FletSemanticsServiceSemantics.dartString(.bool(false)), "false")
    XCTAssertEqual(FletSemanticsServiceSemantics.dartString(.null), "null")
    XCTAssertEqual(FletSemanticsServiceSemantics.dartString(nil), "null")
  }

  func testAccessibilityFeaturesKeepTheExactEightBooleanResultFields() throws {
    let features = FletAccessibilityFeatures(
      accessibleNavigation: true, boldText: false, disableAnimations: true,
      highContrast: false, invertColors: true, reduceMotion: true,
      onOffSwitchLabels: false, supportsAnnouncements: true)
    let values = try XCTUnwrap(features.wireValue.mapValue)
    XCTAssertEqual(Set(values.keys), [
      "accessible_navigation", "bold_text", "disable_animations", "high_contrast",
      "invert_colors", "reduce_motion", "on_off_switch_labels", "supports_announcements",
    ])
    XCTAssertTrue(values.values.allSatisfy { $0.boolValue != nil })
    XCTAssertEqual(values["accessible_navigation"], .bool(true))
    XCTAssertEqual(values["on_off_switch_labels"], .bool(false))
  }

  @MainActor
  func testLiveAppleAccessibilitySnapshotHasTheCanonicalShape() throws {
    let values = try XCTUnwrap(
      FletSemanticsServiceSemantics.currentFeatures.wireValue.mapValue)
    XCTAssertEqual(values.count, 8)
    XCTAssertTrue(values.values.allSatisfy { $0.boolValue != nil })
  }

  func testUnknownSemanticsMethodFailsAtTheServiceBoundary() {
    XCTAssertThrowsError(try FletSemanticsServiceSemantics.announcement(call("announce")))
  }
}
