import Foundation
import RufletEngine
import RufletProtocol
import XCTest

@MainActor
final class RendererRegistryContractTests: XCTestCase {
  func testEveryClaimedCoreControlTypeCreatesANativeView() {
    let backend = RendererRegistryTestBackend()
    let registry = backend.extensionRegistry
    let unresolved = registry.renderedControlTypes.sorted().filter { type in
      let control = backend.control(type: type)
      return registry.view(for: control) == nil
    }
    XCTAssertEqual(
      unresolved, [],
      "Every control type claimed by the extension registry must create a native view")
  }

  func testRufletBasePageCreatesTheNativePageRenderer() {
    let backend = RendererRegistryTestBackend()
    XCTAssertTrue(backend.extensionRegistry.renderedControlTypes.contains("BasePage"))
    XCTAssertNotNil(backend.extensionRegistry.view(for: backend.control(type: "BasePage")))
  }

  func testEveryPinnedFletCoreWidgetTypeIsRegistered() {
    let backend = RendererRegistryTestBackend()
    let missing = PinnedFletCoreWidgetTypes.all
      .subtracting(backend.extensionRegistry.renderedControlTypes)
      .sorted()

    print(
      "Pinned Flet core widget registry accounting: "
        + "\(PinnedFletCoreWidgetTypes.all.count - missing.count)/"
        + "\(PinnedFletCoreWidgetTypes.all.count) wire types declared; "
        + "\(missing.count) remain unregistered.")
    if !missing.isEmpty {
      print("Unregistered pinned Flet widget types:\n  " + missing.joined(separator: "\n  "))
    }

    XCTAssertEqual(
      missing, [],
      "Every pinned Flet widget wire type must be registered in the native extension registry")
  }

  func testCoreRegistryDeclaresAndCreatesEveryCoreService() {
    let backend = RendererRegistryTestBackend()
    let registry = backend.extensionRegistry
    let expected = RufletCoreServiceExtension().serviceControlTypes

    XCTAssertEqual(registry.serviceControlTypes, expected)
    for type in expected {
      XCTAssertNotNil(registry.service(for: backend.control(type: type)), type)
    }
  }
}

private enum PinnedFletCoreWidgetTypes {
  // Exact createWidget switch cases from pinned Flet 0.80.5, commit
  // 53b579f2d84cc6e3041c73b3ef249b370056a37c.
  static let all: Set<String> = [
    "AdaptiveAlertDialog",
    "AdaptiveButton",
    "AdaptiveCheckbox",
    "AdaptiveRadio",
    "AdaptiveSlider",
    "AdaptiveSwitch",
    "AdaptiveTextField",
    "AlertDialog",
    "AnimatedSwitcher",
    "AppBar",
    "AutoComplete",
    "AutofillGroup",
    "Banner",
    "BottomAppBar",
    "BottomSheet",
    "Button",
    "Canvas",
    "Card",
    "Checkbox",
    "Chip",
    "CircleAvatar",
    "Column",
    "Container",
    "ContextMenu",
    "CupertinoActionSheet",
    "CupertinoActionSheetAction",
    "CupertinoActivityIndicator",
    "CupertinoAlertDialog",
    "CupertinoAppBar",
    "CupertinoBottomSheet",
    "CupertinoButton",
    "CupertinoCheckbox",
    "CupertinoContextMenu",
    "CupertinoContextMenuAction",
    "CupertinoDatePicker",
    "CupertinoDialogAction",
    "CupertinoFilledButton",
    "CupertinoListTile",
    "CupertinoNavigationBar",
    "CupertinoPicker",
    "CupertinoRadio",
    "CupertinoSegmentedButton",
    "CupertinoSlider",
    "CupertinoSlidingSegmentedButton",
    "CupertinoSwitch",
    "CupertinoTextField",
    "CupertinoTimerPicker",
    "CupertinoTintedButton",
    "DataTable",
    "DatePicker",
    "DateRangePicker",
    "Dismissible",
    "Divider",
    "DragTarget",
    "Draggable",
    "Dropdown",
    "DropdownM2",
    "ExpansionPanelList",
    "ExpansionTile",
    "FilledButton",
    "FilledIconButton",
    "FilledTonalButton",
    "FilledTonalIconButton",
    "FletApp",
    "FloatingActionButton",
    "GestureDetector",
    "GridView",
    "Hero",
    "Icon",
    "IconButton",
    "Image",
    "InteractiveViewer",
    "KeyboardListener",
    "ListTile",
    "ListView",
    "Markdown",
    "MenuBar",
    "MenuItemButton",
    "MergeSemantics",
    "NavigationBar",
    "NavigationBarDestination",
    "NavigationDrawer",
    "NavigationRail",
    "OutlinedButton",
    "OutlinedIconButton",
    "Page",
    "PageView",
    "Pagelet",
    "Placeholder",
    "PopupMenuButton",
    "ProgressBar",
    "ProgressRing",
    "Radio",
    "RadioGroup",
    "RangeSlider",
    "ReorderableDragHandle",
    "ReorderableListView",
    "ResponsiveRow",
    "Row",
    "SafeArea",
    "Screenshot",
    "SearchBar",
    "SegmentedButton",
    "SelectionArea",
    "Semantics",
    "ShaderMask",
    "Shimmer",
    "Slider",
    "SnackBar",
    "Stack",
    "SubmenuButton",
    "Switch",
    "Tab",
    "TabBar",
    "TabBarView",
    "Tabs",
    "Text",
    "TextButton",
    "TextField",
    "TimePicker",
    "TransparentPointer",
    "VerticalDivider",
    "View",
    "WindowDragArea",
  ]
}

@MainActor
private final class RendererRegistryTestBackend: RufletBackendProtocol {
  var pageURI: URL?
  lazy var extensionRegistry = RufletExtensionRegistry([RufletCoreExtension()])
  private var nextID = 1

  func control(type: String) -> RufletControl {
    defer { nextID += 1 }
    return RufletControl(id: nextID, type: type, properties: [:], backend: self)
  }

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
