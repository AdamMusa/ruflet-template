import RufletEngine
import RufletProtocol
import SwiftUI

/// The role a wire control plays in the native renderer.
///
/// This is deliberately separate from the SwiftUI builder. A successful
/// `AnyView` construction is not evidence that a visible control is rendered:
/// `EmptyView` is also an `AnyView`. Coverage tests and optional bundles can
/// use this contract without instantiating opaque SwiftUI views.
public enum ControlClassification: String, Sendable {
  /// A control that must produce standalone, visible native content.
  case visible
  /// Metadata consumed by a parent control (a tab, table row, chart spot, …).
  case structuralChild
  /// A control owned by page/window/overlay presentation infrastructure.
  case host
  /// A command/event service with no body in the visual tree.
  case service
  /// A known wire type for which the Apple renderer intentionally has no
  /// behavioral equivalent. It must never be counted as visual coverage.
  case unsupported
}

/// How a registered control is expected to enter the native tree.
public enum ControlRendering: Equatable, Sendable {
  case nativeView
  case metadataOnly
  case hostManaged
  case serviceOnly
  case optionalBundle(String)
  case unsupportedFallback
}

/// Executable registry metadata for a Ruflet wire control.
///
/// Events and methods describe behavior implemented by this Apple package,
/// not the complete upstream Flet API. An empty set therefore means "not yet
/// implemented" and is useful parity information rather than an assertion
/// that the upstream control has no events or methods.
public struct ControlDescriptor: Equatable, Sendable {
  public let wireType: String
  public let classification: ControlClassification
  public let implementation: String
  public let rendering: ControlRendering
  public let supportedEvents: Set<String>
  public let supportedMethods: Set<String>

  public init(
    wireType: String,
    classification: ControlClassification,
    implementation: String,
    rendering: ControlRendering,
    supportedEvents: Set<String> = [],
    supportedMethods: Set<String> = []
  ) {
    self.wireType = wireType
    self.classification = classification
    self.implementation = implementation
    self.rendering = rendering
    self.supportedEvents = supportedEvents
    self.supportedMethods = supportedMethods
  }
}

/// Maps a wire type onto its native implementation and its compatibility
/// contract. The builders remain split into families so adding descriptors
/// does not change rendering behavior.
public enum ControlRegistry {
  public typealias Builder = (ControlNode, LayoutAxis) -> AnyView

  /// Extra types a host registers at runtime, mirroring
  /// `ControlFactory::EXTENSION_CLASS_MAP` on the Ruby side.
  private static var extensions: [String: Builder] = [:]
  private static var extensionDescriptors: [String: ControlDescriptor] = [:]

  /// Registers a visible extension control. Existing callers keep their
  /// behavior, while bundles that need another classification can use the
  /// descriptor overload below.
  public static func register(_ wireType: String, builder: @escaping Builder) {
    register(
      descriptor: ControlDescriptor(
        wireType: wireType,
        classification: .visible,
        implementation: "extension:\(wireType)",
        rendering: .nativeView),
      builder: builder)
  }

  public static func register(
    descriptor: ControlDescriptor,
    builder: @escaping Builder
  ) {
    let key = descriptor.wireType.lowercased()
    extensions[key] = builder
    extensionDescriptors[key] = descriptor
  }

  /// The active descriptor, including an optional bundle/host override.
  public static func descriptor(for wireType: String) -> ControlDescriptor? {
    let key = wireType.lowercased()
    return extensionDescriptors[key] ?? builtInDescriptors[key]
  }

  /// The package's built-in contract, unaffected by process-global extension
  /// registration. Tests use this to remain order independent.
  static func builtInDescriptor(for wireType: String) -> ControlDescriptor? {
    builtInDescriptors[wireType.lowercased()]
  }

  static func build(node: ControlNode, axis: LayoutAxis) -> AnyView? {
    if let custom = extensions[node.type.lowercased()] {
      return custom(node, axis)
    }
    let families: [(ControlNode, LayoutAxis) -> AnyView?] = [
      layout, buttons, inputs, display, collections,
      chrome, overlays, gestures, cupertino, media
    ]
    for family in families {
      if let view = family(node, axis) { return view }
    }
    return nil
  }

  // MARK: - Built-in compatibility contract

  private static let builtInDescriptors: [String: ControlDescriptor] = {
    var result: [String: ControlDescriptor] = [:]

    func add(
      _ types: [String],
      _ classification: ControlClassification,
      _ implementation: String,
      _ rendering: ControlRendering,
      events: Set<String> = [],
      methods: Set<String> = []
    ) {
      for type in types {
        precondition(result[type.lowercased()] == nil, "Duplicate control descriptor: \(type)")
        result[type.lowercased()] = ControlDescriptor(
          wireType: type,
          classification: classification,
          implementation: implementation,
          rendering: rendering,
          supportedEvents: events,
          supportedMethods: methods)
      }
    }

    // Page and presentation hosts.
    add(["Page"], .host, "PageControlView", .hostManaged)
    add(["View", "BasePage"], .host, "ViewControlView", .hostManaged)
    add(["Overlay", "Dialogs", "ServiceRegistry", "Window"], .host,
        "RufletAppView host", .hostManaged)
    add(["AlertDialog", "CupertinoAlertDialog", "BottomSheet", "CupertinoBottomSheet",
         "SnackBar", "Banner"], .host, "OverlayPresenter", .hostManaged,
        events: ["dismiss", "visible"])

    // Shared layout and wrappers.
    add(["Row"], .visible, "RowControlView", .nativeView)
    add(["Column"], .visible, "ColumnControlView", .nativeView)
    add(["ResponsiveRow"], .visible, "ResponsiveRowControlView", .nativeView)
    add(["Stack"], .visible, "StackControlView", .nativeView)
    add(["Container"], .visible, "ContainerControlView", .nativeView,
        events: ["click", "hover", "long_press"])
    add(["Card"], .visible, "CardControlView", .nativeView)
    add(["SafeArea"], .visible, "SafeAreaControlView", .nativeView)
    add(["Divider", "VerticalDivider"], .visible, "DividerControlView", .nativeView)
    add(["Placeholder"], .visible, "PlaceholderControlView", .nativeView)
    add(["RotatedBox"], .visible, "RotatedBoxControlView", .nativeView)
    add(["Pagelet"], .visible, "PageletControlView", .nativeView)
    add(["AnimatedSwitcher"], .visible, "AnimatedSwitcherControlView", .nativeView)
    add(["Hero"], .visible, "HeroControlView", .nativeView)
    add(["Semantics"], .visible, "SemanticsControlView", .nativeView)
    add(["MergeSemantics"], .visible, "MergeSemanticsControlView", .nativeView)
    add(["SelectionArea"], .visible, "SelectionAreaControlView", .nativeView)
    add(["TransparentPointer"], .visible, "TransparentPointerControlView", .nativeView)
    add(["Shimmer"], .visible, "ShimmerControlView", .nativeView)
    add(["ShaderMask"], .visible, "ShaderMaskControlView", .nativeView)
    add(["Screenshot"], .visible, "ScreenshotControlView", .nativeView,
        methods: ["capture"])
    add(["WindowDragArea"], .visible, "WindowDragAreaControlView", .nativeView)
    add(["AutofillGroup"], .visible, "InertWrapperControlView", .nativeView)
    add(["BrowserContextMenu"], .unsupported, "InertWrapperControlView", .unsupportedFallback)
    add(["FletApp"], .unsupported, "PassthroughControlView", .unsupportedFallback)

    // Display controls.
    add(["Text"], .visible, "TextControlView", .nativeView,
        events: ["click", "selection_change"])
    add(["TextSpan"], .visible, "TextSpanControlView", .nativeView, events: ["click"])
    add(["Icon"], .visible, "IconControlView", .nativeView)
    add(["Image"], .visible, "ImageControlView", .nativeView,
        events: ["click", "error", "load"])
    add(["ProgressBar"], .visible, "ProgressBarControlView", .nativeView)
    add(["ProgressRing"], .visible, "ProgressRingControlView", .nativeView)
    add(["RufletSpinKit"], .visible, "SpinKitControlView", .nativeView)
    add(["Rive"], .visible, "RiveControlView", .nativeView)
    add(["CircleAvatar"], .visible, "CircleAvatarControlView", .nativeView)
    add(["Badge"], .visible, "BadgeControlView", .nativeView)
    add(["Markdown"], .visible, "MarkdownControlView", .nativeView,
        events: ["selection_change", "tap_link"])

    // Material buttons and value controls.
    let buttonEvents: Set<String> = ["blur", "click", "focus", "hover", "long_press"]
    add(["Button", "ElevatedButton", "TextButton", "FilledButton", "FilledTonalButton",
         "OutlinedButton", "IconButton", "FilledIconButton", "FilledTonalIconButton",
         "OutlinedIconButton", "FloatingActionButton"], .visible,
        "ButtonControlView", .nativeView, events: buttonEvents)
    add(["Chip"], .visible, "ChipControlView", .nativeView,
        events: ["click", "delete", "select"])
    add(["SegmentedButton"], .visible, "SegmentedButtonControlView", .nativeView,
        events: ["change"])
    add(["Switch", "Checkbox", "Radio", "RadioGroup"], .visible,
        "Native selection control", .nativeView, events: ["change"])
    add(["Slider", "RangeSlider"], .visible, "Native slider control", .nativeView,
        events: ["change", "change_end", "change_start"])
    add(["TextField", "CupertinoTextField"], .visible, "Native text field", .nativeView,
        events: ["blur", "change", "focus", "submit"], methods: ["blur", "focus"])
    add(["CodeEditor"], .visible, "CodeEditorControlView", .nativeView,
        events: ["blur", "change", "focus"], methods: ["blur", "focus"])
    add(["SearchBar"], .visible, "SearchBarControlView", .nativeView,
        events: ["change", "submit", "tap"], methods: ["close_view", "focus", "open_view"])
    add(["Dropdown", "DropdownM2"], .visible, "DropdownControlView", .nativeView,
        events: ["change", "focus"])
    add(["AutoComplete"], .visible, "AutoCompleteControlView", .nativeView,
        events: ["select"])
    add(["DatePicker", "TimePicker", "DateRangePicker"], .visible,
        "DateTimePickerControlView", .nativeView, events: ["change", "dismiss"])

    // Data-only children consumed by the controls above.
    add(["Segment", "Option", "DropdownOption", "AutoCompleteSuggestion"],
        .structuralChild, "Parent-owned option metadata", .metadataOnly)

    // Collections.
    add(["ListView"], .visible, "ListViewControlView", .nativeView, events: ["scroll"])
    add(["GridView"], .visible, "GridViewControlView", .nativeView, events: ["scroll"])
    add(["ReorderableListView"], .visible, "ReorderableListControlView", .nativeView,
        events: ["reorder", "scroll"])
    add(["PageView"], .visible, "PageViewControlView", .nativeView,
        events: ["change"], methods: ["jump_to_page", "next_page", "previous_page"])
    add(["ListTile", "CupertinoListTile"], .visible, "ListTileControlView", .nativeView,
        events: ["click", "long_press"])
    add(["ExpansionTile"], .visible, "ExpansionTileControlView", .nativeView,
        events: ["change"])
    add(["ExpansionPanelList"], .visible, "ExpansionPanelListControlView", .nativeView,
        events: ["change"])
    add(["Tabs", "TabBar"], .visible, "TabsControlView", .nativeView,
        events: ["change"], methods: ["move_to"])
    add(["TabBarView"], .visible, "TabBarViewControlView", .nativeView)
    add(["DataTable"], .visible, "DataTableControlView", .nativeView,
        events: ["select_all", "sort"])
    add(["ExpansionPanel", "Tab", "DataColumn", "DataRow", "DataCell",
         "NavigationBarDestination", "NavigationRailDestination",
         "NavigationDrawerDestination", "ReorderableDragHandle"],
        .structuralChild, "Parent-owned collection metadata", .metadataOnly)

    // Chrome and menus.
    add(["AppBar"], .visible, "AppBarControlView", .nativeView)
    add(["BottomAppBar"], .visible, "BottomAppBarControlView", .nativeView)
    add(["NavigationBar"], .visible, "NavigationBarControlView", .nativeView,
        events: ["change"])
    add(["NavigationRail"], .visible, "NavigationRailControlView", .nativeView,
        events: ["change"])
    add(["NavigationDrawer"], .visible, "NavigationDrawerControlView", .nativeView,
        events: ["change", "dismiss"])
    add(["PopupMenuButton"], .visible, "PopupMenuControlView", .nativeView,
        events: ["cancel", "select"])
    add(["MenuBar"], .visible, "MenuBarControlView", .nativeView)
    add(["SubmenuButton"], .visible, "SubmenuButtonControlView", .nativeView)
    add(["MenuItemButton", "PopupMenuItem"], .visible, "MenuItemButtonControlView", .nativeView,
        events: ["click"])
    add(["ContextMenu", "CupertinoContextMenu"], .visible, "ContextMenuControlView", .nativeView)
    add(["SnackBarAction", "CupertinoContextMenuAction", "CupertinoActionSheetAction",
         "CupertinoDialogAction"], .visible, "DialogActionControlView", .nativeView,
        events: ["click"])

    // Gesture surfaces.
    add(["GestureDetector"], .visible, "GestureDetectorControlView", .nativeView,
        events: ["double_tap", "hover", "long_press", "pan_end", "pan_start",
                 "pan_update", "secondary_tap", "tap"])
    add(["Draggable"], .visible, "DraggableControlView", .nativeView,
        events: ["drag_complete", "drag_end", "drag_start"])
    add(["DragTarget"], .visible, "DragTargetControlView", .nativeView,
        events: ["accept", "leave", "move", "will_accept"])
    add(["Dismissible"], .visible, "DismissibleControlView", .nativeView,
        events: ["dismiss", "update"])
    add(["InteractiveViewer"], .visible, "InteractiveViewerControlView", .nativeView,
        events: ["interaction_end", "interaction_start", "interaction_update"],
        methods: ["pan", "reset", "restore_state", "save_state", "zoom"])
    add(["KeyboardListener"], .visible, "KeyboardListenerControlView", .nativeView,
        events: ["key"])

    // Cupertino-native controls.
    add(["CupertinoButton", "CupertinoFilledButton", "CupertinoTintedButton"], .visible,
        "CupertinoButtonControlView", .nativeView, events: buttonEvents)
    add(["CupertinoSwitch", "CupertinoSlider", "CupertinoCheckbox", "CupertinoRadio",
         "CupertinoSegmentedButton", "CupertinoSlidingSegmentedButton", "CupertinoPicker",
         "CupertinoDatePicker", "CupertinoTimerPicker"], .visible,
        "Cupertino native value control", .nativeView, events: ["change"])
    add(["CupertinoActivityIndicator"], .visible, "CupertinoActivityIndicatorControlView",
        .nativeView)
    add(["CupertinoAppBar", "CupertinoNavigationBar"], .visible,
        "CupertinoNavigationBarControlView", .nativeView)
    add(["CupertinoActionSheet"], .visible, "CupertinoActionSheetControlView", .nativeView)

    // Drawing, charts and their parent-owned data.
    add(["Canvas"], .visible, "CanvasControlView", .nativeView, methods: ["get_image"])
    add(["LineChart", "BarChart", "PieChart", "ScatterChart", "RadarChart",
         "CandlestickChart"], .visible, "ChartControlView", .nativeView,
        events: ["chart_event"])
    add(["Arc", "Circle", "Color", "Fill", "Line", "Oval", "Path", "Points", "Rect",
         "Shadow", "RadarChartTitle", "RadarDataSet", "RadarDataSetEntry",
         "CandlestickChartSpot", "ScatterChartSpot"], .structuralChild,
        "Canvas/chart metadata", .metadataOnly)
    // Flet chart plugins deliberately serialize their high-volume child
    // controls with compact wire names. Ruflet exposes both underscored and
    // compact Ruby constructors, but both forms emit these exact wire types.
    add(["group", "rod", "stack_item", "axis", "l", "data", "p", "section"],
        .structuralChild, "Flet compact chart metadata", .metadataOnly)

    // Media and optional native bundles.
    add(["WebView"], .visible, "WebViewControlView", .nativeView,
        events: ["page_end", "page_start", "url_change"])
    add(["Video"], .visible, "VideoControlView", .nativeView,
        events: ["completed", "enter_fullscreen", "error", "exit_fullscreen", "loaded"],
        methods: ["get_current_position", "get_duration", "is_completed", "is_playing",
                  "jump_to", "next", "pause", "play", "play_or_pause", "playlist_add",
                  "playlist_remove", "previous", "seek", "stop"])
    add(["Map"], .visible, "MapControlView", .nativeView,
        events: ["event", "hover", "init", "long_press", "pointer_cancel", "pointer_down",
                 "pointer_up", "position_change", "secondary_tap", "tap"],
        methods: ["center_on", "move_to", "reset_rotation", "rotate_from", "zoom_in",
                  "zoom_out", "zoom_to"])
    add(["TileLayer", "MarkerLayer", "Marker", "CircleLayer", "CircleMarker",
         "PolylineLayer", "PolylineMarker", "PolygonLayer", "PolygonMarker",
         "SimpleAttribution"], .structuralChild, "MapKit layer metadata", .metadataOnly)
    add(["Camera"], .visible, "RufletMedia.CameraControlView",
        .optionalBundle("RufletMedia"), events: ["error", "initialized", "picture_taken"])
    add(["Audio", "AudioRecorder"], .service, "RufletMedia service", .serviceOnly)

    return result
  }()
}
