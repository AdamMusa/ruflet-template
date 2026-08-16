import RufletEngine
import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class AlertDialogPropertyConsumptionTests: XCTestCase {
  func testButtonsInsideIOSDialogsAlwaysUseAppleDialogActions() {
    XCTAssertTrue(rufletUsesAppleDialogAction(parentType: "AlertDialog", isIOS: true))
    XCTAssertTrue(rufletUsesAppleDialogAction(parentType: "CupertinoAlertDialog", isIOS: true))
    XCTAssertFalse(rufletUsesAppleDialogAction(parentType: "AlertDialog", isIOS: false))
    XCTAssertFalse(rufletUsesAppleDialogAction(parentType: "Column", isIOS: true))
  }

  func testPinnedDefaultsDoNotClipOrOverrideAccessibilityLabel() {
    let presentation = RufletAlertDialogPresentation(control: control(properties: [:]))

    XCTAssertNil(presentation.actionButtonPadding)
    XCTAssertEqual(presentation.clipBehavior, "none")
    XCTAssertFalse(presentation.clipsContent)
    XCTAssertFalse(presentation.antialiasedClip)
    XCTAssertNil(presentation.semanticsLabel)
    XCTAssertFalse(presentation.hasExplicitBackground)
    XCTAssertTrue(presentation.usesNativeGlassSurface)
  }

  func testExplicitDialogBackgroundRemainsProtocolDrivenInsteadOfGlass() {
    let presentation = RufletAlertDialogPresentation(
      control: control(properties: ["bgcolor": .string("#ffffff")]))

    XCTAssertTrue(presentation.hasExplicitBackground)
    XCTAssertFalse(presentation.usesNativeGlassSurface)
  }

  func testActionButtonPaddingAndSemanticLabelAreConsumed() {
    let presentation = RufletAlertDialogPresentation(
      control: control(properties: [
        "action_button_padding": .map([
          "top": .double(2),
          "right": .double(4),
          "bottom": .double(6),
          "left": .double(8),
        ]),
        "semantics_label": .string("Session expired dialog"),
      ]))

    XCTAssertEqual(presentation.actionButtonPadding?.top, 2)
    XCTAssertEqual(presentation.actionButtonPadding?.trailing, 4)
    XCTAssertEqual(presentation.actionButtonPadding?.bottom, 6)
    XCTAssertEqual(presentation.actionButtonPadding?.leading, 8)
    XCTAssertEqual(presentation.semanticsLabel, "Session expired dialog")
  }

  func testEveryPinnedClipModePreservesItsNativeAntialiasContract() {
    let hardEdge = RufletAlertDialogPresentation(
      control: control(properties: [
        "clip_behavior": .string("hardEdge")
      ]))
    XCTAssertTrue(hardEdge.clipsContent)
    XCTAssertFalse(hardEdge.antialiasedClip)

    let antialias = RufletAlertDialogPresentation(
      control: control(properties: [
        "clip_behavior": .string("antiAliasWithSaveLayer")
      ]))
    XCTAssertTrue(antialias.clipsContent)
    XCTAssertTrue(antialias.antialiasedClip)
  }

  private func control(properties: [String: RufletValue]) -> RufletControl {
    RufletControl(
      id: 1,
      type: "AlertDialog",
      properties: properties,
      backend: AlertDialogTestBackend())
  }
}

@MainActor
private final class AlertDialogTestBackend: RufletBackendProtocol {
  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])

  func index(_ control: RufletControl) {}
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {}
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {}
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {}
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
