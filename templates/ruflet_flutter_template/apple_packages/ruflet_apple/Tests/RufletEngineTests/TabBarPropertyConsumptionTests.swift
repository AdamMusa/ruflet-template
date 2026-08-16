import RufletProtocol
import XCTest

@testable import RufletEngine

@MainActor
final class TabBarPropertyConsumptionTests: XCTestCase {
  func testPresentationConsumesPinnedNativeTabBarAppearanceAndFeedbackContract() {
    let control = makeControl(
      type: "TabBar",
      properties: [
        "enable_feedback": false,
        "indicator_size": "label",
        "mouse_cursor": "click",
        "overlay_color": ["hovered": "blue", "pressed": "red"],
        "secondary": true,
        "splash_border_radius": 12.0,
      ])

    let presentation = RufletTabBarPresentation(control: control)
    let hovered = presentation.states(
      selected: true,
      hovered: true,
      pressed: false,
      disabled: false)

    XCTAssertFalse(presentation.enableFeedback)
    XCTAssertEqual(presentation.indicatorSize, .label)
    XCTAssertEqual(presentation.mouseCursor, "click")
    XCTAssertTrue(presentation.secondary)
    XCTAssertEqual(presentation.minimumHeight, 40)
    XCTAssertEqual(presentation.splashBorderRadius.topLeft, 12)
    XCTAssertEqual(
      presentation.indicatorHorizontalInset(
        labelPadding: .init(top: 0, leading: 16, bottom: 0, trailing: 12)),
      12)
    XCTAssertTrue(hovered.contains(.selected))
    XCTAssertTrue(hovered.contains(.hovered))
    XCTAssertNotNil(presentation.overlay(hovered))
  }

  func testPrimaryTabBarDefaultsMatchPinnedConstructorDefaults() {
    let presentation = RufletTabBarPresentation(
      control: makeControl(type: "TabBar", properties: [:]))

    XCTAssertTrue(presentation.enableFeedback)
    XCTAssertEqual(presentation.indicatorSize, .tab)
    XCTAssertEqual(presentation.indicatorAnimation, .linear)
    XCTAssertEqual(presentation.indicatorThickness, 2)
    XCTAssertEqual(presentation.indicatorPadding.leading, 0)
    XCTAssertEqual(presentation.labelPadding.leading, 16)
    XCTAssertTrue(presentation.scrollable)
    XCTAssertEqual(presentation.tabAlignment, .start)
    XCTAssertFalse(presentation.secondary)
    XCTAssertEqual(presentation.minimumHeight, 44)
    XCTAssertEqual(
      presentation.indicatorHorizontalInset(
        labelPadding: .init(top: 0, leading: 16, bottom: 0, trailing: 16)),
      0)
  }

  func testPresentationConsumesTabBarWirePropertiesWithoutScreenSpecificRules() {
    let control = makeControl(
      type: "TabBar",
      properties: [
        "indicator": [
          "border_side": ["width": 3.0, "color": "blue"],
          "insets": 1.0,
        ],
        "indicator_animation": "elastic",
        "indicator_color": "red",
        "indicator_padding": 4.0,
        "indicator_thickness": 5.0,
        "label_padding": 6.0,
        "on_hover": true,
        "scrollable": false,
        "tab_alignment": "fill",
      ])

    let presentation = RufletTabBarPresentation(control: control)

    XCTAssertEqual(presentation.indicator?.borderSide.width, 3)
    XCTAssertEqual(presentation.indicator?.insets.leading, 1)
    XCTAssertEqual(presentation.indicatorAnimation, .elastic)
    XCTAssertNotNil(presentation.indicatorColor)
    XCTAssertEqual(presentation.indicatorPadding.leading, 4)
    XCTAssertEqual(presentation.indicatorThickness, 5)
    XCTAssertTrue(presentation.hasExplicitIndicatorThickness)
    XCTAssertEqual(presentation.labelPadding.leading, 6)
    XCTAssertTrue(control.hasEventHandler("hover"))
    XCTAssertFalse(presentation.scrollable)
    XCTAssertEqual(presentation.tabAlignment, .fill)
  }

  func testDirectTabBarPropertiesOverrideComponentTheme() {
    let theme = parseTheme([
      "tab_bar_theme": [
        "divider_height": 9.0,
        "indicator_animation": "linear",
        "indicator_size": "tab",
        "label_padding": 10.0,
      ]
    ])
    let control = makeControl(
      type: "TabBar",
      properties: [
        "divider_height": 2.0,
        "indicator_animation": "elastic",
        "indicator_size": "label",
        "label_padding": 3.0,
      ])

    let presentation = RufletTabBarPresentation(control: control, theme: theme)

    XCTAssertEqual(presentation.dividerHeight, 2)
    XCTAssertEqual(presentation.indicatorAnimation, .elastic)
    XCTAssertEqual(presentation.indicatorSize, .label)
    XCTAssertEqual(presentation.labelPadding.leading, 3)
  }

  func testTabsSelectionWritesThenEmitsPinnedChangeExactlyOnce() {
    let backend = TabBarBackend()
    let control = RufletControl(
      id: 1,
      type: "Tabs",
      properties: ["length": 3, "selected_index": 0, "on_change": true],
      backend: backend)
    let state = RufletTabsState(control: control)

    state.select(2)

    XCTAssertEqual(backend.updates.count, 1)
    XCTAssertEqual(backend.updates[0].properties, ["selected_index": 2])
    XCTAssertFalse(backend.updates[0].notify)
    XCTAssertEqual(backend.events, [TabBarBackend.Event(name: "change", data: 2)])
  }

  func testWireScrollablePropertySelectsNativeTabBarPresentation() {
    XCTAssertTrue(rufletTabBarUsesAppleSegmentedPresentation(
      isIOS: true,
      scrollable: false))
    XCTAssertFalse(rufletTabBarUsesAppleSegmentedPresentation(
      isIOS: true,
      scrollable: true))
    XCTAssertFalse(rufletTabBarUsesAppleSegmentedPresentation(
      isIOS: false,
      scrollable: false))
  }

  private func makeControl(type: String, properties: [String: RufletValue]) -> RufletControl {
    RufletControl(id: 1, type: type, properties: properties, backend: TabBarBackend())
  }
}

@MainActor
private final class TabBarBackend: RufletBackendProtocol {
  struct Update: Equatable {
    let properties: [String: RufletValue]
    let notify: Bool
  }

  struct Event: Equatable {
    let name: String
    let data: RufletValue
  }

  let pageURI: URL? = nil
  let extensionRegistry = RufletExtensionRegistry([])
  var updates: [Update] = []
  var events: [Event] = []

  func index(_ control: RufletControl) {}

  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func triggerControlEvent(controlID: Int, name: String, data: RufletValue) {
    events.append(Event(name: name, data: data))
  }

  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool
  ) {
    updates.append(Update(properties: properties, notify: notify))
  }

  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource? { nil }
  func onWindowEvent(_ name: String, state: RufletWindowState) {}
}
