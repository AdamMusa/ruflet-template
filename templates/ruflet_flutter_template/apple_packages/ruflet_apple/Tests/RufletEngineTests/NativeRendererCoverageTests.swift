import RufletEngine
import RufletAudio
import RufletAudioRecorder
import RufletCamera
import RufletFlashlight
import RufletGeolocator
import RufletLocation
import RufletPermissionHandler
import RufletQRScanner
import RufletMotion
import RufletSecureStorage
@testable import RufletUI
import XCTest

/// Cross-layer compatibility contracts for the native Apple engine.
///
/// Ruflet's Ruby wire types are the public UI protocol. A missing registry
/// entry otherwise falls through to `UnmappedControlView`, which can look like
/// a valid empty screen. Keep the complete protocol surface here so adding a
/// Ruby control or service must be accompanied by its native implementation.
final class NativeRendererCoverageTests: XCTestCase {
  private static let registeredWireTypes = """
  AlertDialog
  AnimatedSwitcher
  AppBar
  Arc
  Audio
  AudioRecorder
  AutoComplete
  AutoCompleteSuggestion
  AutofillGroup
  Badge
  Banner
  BarChart
  BasePage
  BottomAppBar
  BottomSheet
  BrowserContextMenu
  Button
  CandlestickChart
  CandlestickChartSpot
  Canvas
  Camera
  Card
  Checkbox
  Chip
  Circle
  CircleAvatar
  Color
  Column
  CodeEditor
  Container
  ContextMenu
  CupertinoActionSheet
  CupertinoActionSheetAction
  CupertinoActivityIndicator
  CupertinoAlertDialog
  CupertinoAppBar
  CupertinoBottomSheet
  CupertinoButton
  CupertinoCheckbox
  CupertinoContextMenu
  CupertinoContextMenuAction
  CupertinoDatePicker
  CupertinoDialogAction
  CupertinoFilledButton
  CupertinoListTile
  CupertinoNavigationBar
  CupertinoPicker
  CupertinoRadio
  CupertinoSegmentedButton
  CupertinoSlider
  CupertinoSlidingSegmentedButton
  CupertinoSwitch
  CupertinoTextField
  CupertinoTimerPicker
  CupertinoTintedButton
  DataCell
  DataColumn
  DataRow
  DataTable
  DatePicker
  DateRangePicker
  Dialogs
  Dismissible
  Divider
  DragTarget
  Draggable
  Dropdown
  DropdownM2
  DropdownOption
  ElevatedButton
  ExpansionPanel
  ExpansionPanelList
  ExpansionTile
  Fill
  FilledButton
  FilledIconButton
  FilledTonalButton
  FilledTonalIconButton
  RufletApp
  FloatingActionButton
  GestureDetector
  GridView
  Hero
  Icon
  IconButton
  Image
  InteractiveViewer
  KeyboardListener
  Line
  LineChart
  ListTile
  ListView
  Map
  Markdown
  MenuBar
  MenuItemButton
  MergeSemantics
  NavigationBar
  NavigationBarDestination
  NavigationDrawer
  NavigationDrawerDestination
  NavigationRail
  NavigationRailDestination
  Option
  OutlinedButton
  OutlinedIconButton
  Oval
  Overlay
  Page
  PageView
  Pagelet
  Path
  PieChart
  Placeholder
  Points
  PopupMenuButton
  PopupMenuItem
  ProgressBar
  ProgressRing
  RadarChart
  RadarChartTitle
  RadarDataSet
  RadarDataSetEntry
  Radio
  RadioGroup
  RangeSlider
  Rect
  ReorderableDragHandle
  ReorderableListView
  ResponsiveRow
  RotatedBox
  Row
  RufletSpinKit
  Rive
  SafeArea
  ScatterChart
  ScatterChartSpot
  Screenshot
  SearchBar
  Segment
  SegmentedButton
  SelectionArea
  Semantics
  ServiceRegistry
  ShaderMask
  Shadow
  Shimmer
  Slider
  SnackBar
  SnackBarAction
  Stack
  SubmenuButton
  Switch
  Tab
  TabBar
  TabBarView
  Tabs
  Text
  TextButton
  TextField
  TextSpan
  TimePicker
  TransparentPointer
  VerticalDivider
  Video
  View
  WebView
  Window
  WindowDragArea
  """.split(separator: "\n").map(String.init)

  func testEveryRegisteredWireTypeHasACompatibilityDescriptorAndBuilder() {
    for (index, wireType) in Self.registeredWireTypes.enumerated() {
      let node = ControlNode(id: index + 1, type: wireType)
      let descriptor = ControlRegistry.builtInDescriptor(for: wireType)
      XCTAssertNotNil(
        descriptor,
        "\(wireType) has a builder but no Apple compatibility descriptor")
      if descriptor?.classification == .service {
        // Services are resolved by RufletServiceRegistry and deliberately do
        // not fabricate a visual SwiftUI control.
        continue
      }
      if case .optionalBundle = descriptor?.rendering {
        // Optional products install their builder only when the app links and
        // registers that extension. Core must retain just the fallback
        // descriptor so unrelated SDKs are not bundled into RufletUI.
        continue
      }
      XCTAssertNotNil(
        ControlRegistry.build(node: node, axis: .none),
        "\(wireType) has no Apple renderer registry entry")
    }
  }

  func testVisibleControlsCannotClaimEmptyViewAsNativeCoverage() {
    for wireType in Self.registeredWireTypes {
      guard let descriptor = ControlRegistry.builtInDescriptor(for: wireType),
            descriptor.classification == .visible
      else { continue }

      switch descriptor.rendering {
      case .nativeView, .optionalBundle:
        break
      case .metadataOnly, .hostManaged, .serviceOnly, .unsupportedFallback:
        XCTFail(
          "\(wireType) is visible but is represented by \(descriptor.rendering) "
            + "(\(descriptor.implementation))")
      }
      XCTAssertFalse(descriptor.implementation.contains("EmptyView"))
      XCTAssertFalse(descriptor.implementation.contains("MissingBundleControlView"))
    }
  }

  func testParentOwnedWireTypesAreExplicitlyStructuralChildren() {
    let structuralChildren = [
      "Arc", "AutoCompleteSuggestion", "CandlestickChartSpot", "Circle", "Color",
      "DataCell", "DataColumn", "DataRow", "DropdownOption", "ExpansionPanel", "Fill",
      "Line", "NavigationBarDestination", "NavigationDrawerDestination",
      "NavigationRailDestination", "Option", "Oval", "Path", "Points", "RadarChartTitle",
      "RadarDataSet", "RadarDataSetEntry", "Rect", "ReorderableDragHandle", "ScatterChartSpot",
      "Segment", "Shadow", "Tab"
    ]

    for wireType in structuralChildren {
      let descriptor = ControlRegistry.builtInDescriptor(for: wireType)
      XCTAssertEqual(descriptor?.classification, .structuralChild, wireType)
      XCTAssertEqual(descriptor?.rendering, .metadataOnly, wireType)
    }
  }

  func testHostServiceAndUnsupportedTypesDoNotMasqueradeAsVisibleControls() {
    let expected: [String: ControlClassification] = [
      "AlertDialog": .host,
      "Audio": .service,
      "AudioRecorder": .service,
      "Banner": .host,
      "BottomSheet": .host,
      "BrowserContextMenu": .service,
      "CupertinoAlertDialog": .host,
      "CupertinoBottomSheet": .host,
      "Dialogs": .host,
      "RufletApp": .visible,
      "Overlay": .host,
      "Page": .host,
      "ServiceRegistry": .host,
      "SnackBar": .host,
      "View": .host,
      "Window": .host,
    ]

    for (wireType, classification) in expected {
      XCTAssertEqual(
        ControlRegistry.builtInDescriptor(for: wireType)?.classification,
        classification,
        wireType)
    }
  }

  func testBehavioralControlsDeclareTheMethodsImplementedByTheirNativeHandlers() {
    XCTAssertEqual(
      ControlRegistry.builtInDescriptor(for: "TextField")?.supportedMethods,
      ["focus"])
    XCTAssertTrue(
      ControlRegistry.builtInDescriptor(for: "InteractiveViewer")?.supportedMethods
        .contains("restore_state") == true)
    XCTAssertTrue(
      ControlRegistry.builtInDescriptor(for: "Video")?.supportedMethods.contains("play") == true)
    XCTAssertTrue(
      ControlRegistry.builtInDescriptor(for: "Map")?.supportedMethods.contains("zoom_to") == true)
  }

  @MainActor
  func testOptionalVisualBundleReplacesCameraFallbackWithNativeViewDescriptor() {
    let builtIn = ControlRegistry.builtInDescriptor(for: "Camera")
    XCTAssertEqual(builtIn?.classification, .visible)
    XCTAssertEqual(builtIn?.rendering, .optionalBundle("RufletCamera"))

    let services = ServiceRegistry()
    RufletCamera.register(in: services)

    XCTAssertEqual(ControlRegistry.descriptor(for: "Camera")?.rendering, .nativeView)
    XCTAssertEqual(
      ControlRegistry.descriptor(for: "Camera")?.implementation,
      "RufletCamera.CameraControlView")
  }

  @MainActor
  func testEveryRufletServiceIsProvidedByCoreOrAnOptionalAppleBundle() {
    let registry = ServiceRegistry()
    registry.registerDefaults()
    registry.register(extensions: [
      RufletMotion.self, RufletLocation.self, RufletGeolocator.self,
      RufletPermissionHandler.self, RufletSecureStorage.self,
      RufletAudio.self, RufletQRScanner.self,
      RufletAudioRecorder.self, RufletCamera.self, RufletFlashlight.self,
    ])

    let serviceWireTypes = [
      "Accelerometer", "AudioRecorder", "Barometer", "Battery", "Camera", "Clipboard",
      "Connectivity", "FilePicker", "Flashlight", "Geolocator", "Gyroscope",
      "HapticFeedback", "Magnetometer", "PermissionHandler", "ScreenBrightness",
      "SecureStorage", "SemanticsService", "ShakeDetector", "Share", "SharedPreferences",
      "StoragePaths", "UrlLauncher", "UserAccelerometer", "Wakelock"
    ]

    for wireType in serviceWireTypes {
      XCTAssertTrue(registry.handles(wireType), "\(wireType) has no Apple service implementation")
    }
  }
}
