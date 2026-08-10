import RufletEngine
import RufletLocation
import RufletMedia
import RufletMotion
@testable import RufletUI
import XCTest

/// Cross-layer compatibility contracts for the native Apple engine.
///
/// Ruflet's Ruby wire types are the public UI protocol. A missing registry
/// entry otherwise falls through to `UnmappedControlView`, which can look like
/// a valid empty screen. Keep the complete protocol surface here so adding a
/// Ruby control or service must be accompanied by its native implementation.
final class NativeRendererCoverageTests: XCTestCase {
  private static let visualWireTypes = """
  AlertDialog
  AnimatedSwitcher
  AppBar
  Arc
  Audio
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
  Card
  Checkbox
  Chip
  Circle
  CircleAvatar
  Color
  Column
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
  ExpansionPanel
  ExpansionPanelList
  ExpansionTile
  Fill
  FilledButton
  FilledIconButton
  FilledTonalButton
  FilledTonalIconButton
  FletApp
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

  func testEveryRufletVisualWireTypeHasANativeRenderer() {
    for (index, wireType) in Self.visualWireTypes.enumerated() {
      let node = ControlNode(id: index + 1, type: wireType)
      XCTAssertNotNil(
        ControlRegistry.build(node: node, axis: .none),
        "\(wireType) has no Apple renderer registry entry")
    }
  }

  @MainActor
  func testEveryRufletServiceIsProvidedByCoreOrAnOptionalAppleBundle() {
    let registry = ServiceRegistry()
    registry.registerDefaults()
    registry.register(bundles: [RufletMotion.self, RufletLocation.self, RufletMedia.self])

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
