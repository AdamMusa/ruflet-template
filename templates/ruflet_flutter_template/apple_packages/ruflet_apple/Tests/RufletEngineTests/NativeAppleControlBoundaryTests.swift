import Foundation
import XCTest

final class NativeAppleControlBoundaryTests: XCTestCase {
  func testIOSControlsWithPublicAppleEquivalentsUseThoseEquivalents() throws {
    let expectations: [(String, [String])] = [
      ("Controls/text.swift", ["Text(", "RufletNativeSelectableText("]),
      ("Controls/button.swift", ["Button(action:"]),
      ("Controls/cupertino_button.swift", ["Button(action:"]),
      ("Controls/icon_button.swift", ["Button(action:"]),
      ("Controls/floating_action_button.swift", ["Button(action:"]),
      ("Controls/checkbox.swift", ["Button(action: toggle)", "Image(systemName: \"checkmark\")"]),
      ("Controls/radio.swift", ["Button(action: select)", "Circle()"]),
      ("Controls/alert_dialog.swift", ["UIAlertController", "preferredStyle: .alert", "NSAlert"]),
      ("Controls/bottom_sheet.swift", [".sheet(isPresented:", "presentationSizing(.fitted)"]),
      ("Controls/tabs.swift", ["UISegmentedControl", "RufletNativeSegmentedControl"]),
      ("Widgets/native_tab_bar.swift", ["UITabBar", "UITabBarDelegate"]),
      ("Controls/navigation_bar.swift", ["RufletNativeTabBar"]),
      ("Controls/dropdown.swift", ["Menu {"]),
      ("Controls/dropdownm2.swift", ["Menu {"]),
      ("Widgets/native_date_picker.swift", ["UIDatePicker", "UIViewRepresentable"]),
      ("Controls/cupertino_picker.swift", ["UIPickerView", "UIViewRepresentable"]),
      ("Widgets/native_slider.swift", ["UISlider", "RufletNativeRangeSlider"]),
      ("Widgets/native_switch.swift", ["UISwitch", "UIViewRepresentable"]),
      ("Widgets/native_text_input.swift", ["UITextField", "UITextView"]),
      ("Controls/search_bar.swift", ["RufletNativeTextInput("]),
    ]

    for (relativePath, requiredSymbols) in expectations {
      let source = try source(relativePath)
      for symbol in requiredSymbols {
        XCTAssertTrue(source.contains(symbol), "\(relativePath) must use public Apple \(symbol)")
      }
    }
  }

  func testNativeModalsHaveNoAlternateVisualRenderer() throws {
    let alert = try source("Controls/alert_dialog.swift")
    for forbidden in [
      "dialogLayer", "RufletDialogSurfaceModifier", "nativeFallbackActionViews",
      "glassEffect(",
    ] {
      XCTAssertFalse(alert.contains(forbidden), "AlertDialog cannot use \(forbidden)")
    }

    let sheet = try source("Controls/bottom_sheet.swift")
    for forbidden in [
      "fallbackSheetContent", "RufletSheetClip", "DragGesture(", "barrierColor",
    ] {
      XCTAssertFalse(sheet.contains(forbidden), "BottomSheet cannot use \(forbidden)")
    }

    let datePicker = try source("Controls/date_picker.swift")
    XCTAssertTrue(datePicker.contains(".sheet(isPresented:"))
    XCTAssertFalse(datePicker.contains("RufletPickerDialogLayer"))
  }

  func testAllSliderAndSwitchWireTypesChooseTheNativeIOSBridges() throws {
    let selections: [(String, String)] = [
      ("Controls/slider.swift", "RufletNativeSlider("),
      ("Controls/cupertino_slider.swift", "RufletNativeSlider("),
      ("Controls/range_slider.swift", "RufletNativeRangeSlider("),
      ("Controls/switch.swift", "RufletNativeSwitch("),
      ("Controls/cupertino_switch.swift", "RufletNativeSwitch("),
    ]

    for (relativePath, nativeType) in selections {
      let source = try source(relativePath)
      XCTAssertTrue(source.contains("#if os(iOS)"), "\(relativePath) must select its iOS path")
      XCTAssertTrue(source.contains(nativeType), "\(relativePath) must select \(nativeType) on iOS")
    }
  }

  func testNativeBridgesDoNotUsePrivateUIKitIntrospection() throws {
    let combined = try [
      "Controls/alert_dialog.swift",
      "Controls/tabs.swift",
      "Widgets/native_tab_bar.swift",
      "Widgets/native_date_picker.swift",
      "Widgets/native_slider.swift",
      "Widgets/native_switch.swift",
      "Widgets/native_text_input.swift",
    ].map(source).joined(separator: "\n")

    for forbidden in ["value(forKey:", "perform(Selector", "_thumb", "_visualProvider"] {
      XCTAssertFalse(
        combined.contains(forbidden), "Native Apple controls cannot depend on \(forbidden)")
    }
  }

  func testNativeTabSelectionUsesSegmentedControlTargetAction() throws {
    let tabs = try source("Controls/tabs.swift")

    XCTAssertTrue(tabs.contains("for: .valueChanged"))
    XCTAssertTrue(tabs.contains("insertSegment(with:"))
    XCTAssertTrue(tabs.contains("insertSegment(withTitle:"))
    XCTAssertFalse(tabs.contains("insertSegment(action:"))
  }

  private func source(_ relativePath: String) throws -> String {
    try String(
      contentsOf:
        packageRoot
        .appendingPathComponent("Sources/RufletEngine")
        .appendingPathComponent(relativePath),
      encoding: .utf8)
  }

  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }
}
