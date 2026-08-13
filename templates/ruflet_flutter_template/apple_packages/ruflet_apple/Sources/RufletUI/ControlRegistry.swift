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
    if let adaptive = adaptiveTwin(node) { return adaptive }
    let families: [(ControlNode, LayoutAxis) -> AnyView?] = [
      layout, buttons, inputs, display, collections,
      chrome, overlays, gestures, cupertino, media
    ]
    for family in families {
      if let view = family(node, axis) { return view }
    }
    return nil
  }

  /// `adaptive` — the Material control asks to be its Cupertino twin.
  ///
  /// Flet pairs seven families this way, in `adaptive_*.dart`, and each twin
  /// is chosen when the property is set and the platform is iOS or macOS. Both
  /// are always true here, so this renderer only has to check the property.
  ///
  /// AlertDialog is absent because the Material and Cupertino dialogs already
  /// share one view.
  private static func adaptiveTwin(_ node: ControlNode) -> AnyView? {
    guard node.bool("adaptive") == true else { return nil }
    switch node.type {
    case "Switch": return AnyView(CupertinoSwitchControlView(node: node))
    case "Slider": return AnyView(CupertinoSliderControlView(node: node))
    case "Checkbox": return AnyView(CupertinoSelectionControlView(node: node, kind: .checkbox))
    case "Radio": return AnyView(CupertinoSelectionControlView(node: node, kind: .radio))
    case "TextField": return AnyView(CupertinoTextFieldControlView(node: node))
    case "AppBar": return AnyView(CupertinoAppBarControlView(node: node))
    case "Button", "ElevatedButton", "FilledButton", "FilledTonalButton",
      "OutlinedButton", "TextButton":
      if AdaptiveControlSemantics.usesCupertinoDialogAction(node) {
        return AnyView(DialogActionControlView(node: AdaptiveControlSemantics.dialogAction(node)))
      }
      return AnyView(CupertinoButtonControlView(node: node))
    default: return nil
    }
  }

  enum AdaptiveControlSemantics {
    static func usesCupertinoDialogAction(_ node: ControlNode) -> Bool {
      guard node.bool("adaptive") == true else { return false }
      return ["AlertDialog", "CupertinoAlertDialog"].contains(
        node.internals["_flet_parent_type"]?.stringValue)
    }

    static func dialogAction(_ node: ControlNode) -> ControlNode {
      var action = node
      action.type = "CupertinoDialogAction"
      return action
    }
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
    add(["Page"], .host, "PageControlView", .hostManaged,
        events: ["app_lifecycle_state_change", "keyboard_event", "locale_change", "route_change"])
    add(["View", "BasePage"], .host, "ViewControlView", .hostManaged,
        events: ["confirm_pop", "scroll"], methods: RufletViewCommands.methods)
    add(["Overlay", "Dialogs", "ServiceRegistry"], .host,
        "RufletAppView host", .hostManaged)
    add(["Window"], .host, "WindowService", .hostManaged,
        methods: ["center", "close", "destroy", "start_dragging", "start_resizing",
                  "to_front", "wait_until_ready_to_show"])
    add(["AlertDialog", "CupertinoAlertDialog", "BottomSheet", "CupertinoBottomSheet",
         "Banner"], .host, "OverlayPresenter", .hostManaged,
        events: ["dismiss", "visible"])
    add(["SnackBar"], .host, "OverlayPresenter", .hostManaged,
        events: ["action", "dismiss", "visible"])

    // Shared layout and wrappers.
    add(["Row"], .visible, "RowControlView", .nativeView, events: ["scroll"])
    add(["Column"], .visible, "ColumnControlView", .nativeView, events: ["scroll"])
    add(["ResponsiveRow"], .visible, "ResponsiveRowControlView", .nativeView)
    add(["Stack"], .visible, "StackControlView", .nativeView)
    add(["Container"], .visible, "ContainerControlView", .nativeView,
        events: ["animation_end", "click", "hover", "long_press", "tap_down"])
    add(["Card"], .visible, "CardControlView", .nativeView)
    add(["SafeArea"], .visible, "SafeAreaControlView", .nativeView)
    add(["Divider", "VerticalDivider"], .visible, "DividerControlView", .nativeView)
    add(["Placeholder"], .visible, "PlaceholderControlView", .nativeView)
    add(["RotatedBox"], .visible, "RotatedBoxControlView", .nativeView)
    add(["Pagelet"], .visible, "PageletControlView", .nativeView,
        methods: PageletPresentation.methods)
    add(["AnimatedSwitcher"], .visible, "AnimatedSwitcherControlView", .nativeView)
    add(["Hero"], .visible, "HeroControlView", .nativeView)
    add(["Semantics"], .visible, "SemanticsControlView", .nativeView,
        events: ["click", "copy", "cut", "decrease", "did_gain_accessibility_focus",
                 "did_lose_accessibility_focus", "dismiss", "increase",
                 "move_cursor_backward_by_character", "move_cursor_forward_by_character",
                 "paste", "scroll_down", "scroll_left", "scroll_right", "scroll_up",
                 "set_text"])
    add(["MergeSemantics"], .visible, "MergeSemanticsControlView", .nativeView)
    add(["SelectionArea"], .visible, "SelectionAreaControlView", .nativeView,
        events: ["change"])
    add(["TransparentPointer"], .visible, "TransparentPointerControlView", .nativeView)
    add(["Shimmer"], .visible, "ShimmerControlView", .nativeView)
    add(["ShaderMask"], .visible, "ShaderMaskControlView", .nativeView)
    add(["Screenshot"], .visible, "ScreenshotControlView", .nativeView,
        methods: ["capture"])
    add(["WindowDragArea"], .visible, "WindowDragAreaControlView", .nativeView,
        events: ["double_tap", "drag_end", "drag_start"])
    add(["AutofillGroup"], .visible, "AutofillGroupControlView", .nativeView)
    add(["BrowserContextMenu"], .service, "BrowserContextMenuService", .serviceOnly,
        methods: ["disable_menu", "enable_menu"])
    // Current Ruflet clients emit `RufletApp`; older self-contained runtimes
    // used Flet's original `FletApp` wire name. Both describe the same nested
    // application contract, so Apple accepts both at the renderer boundary.
    add(["RufletApp", "FletApp"], .visible, "RufletAppControlView", .nativeView,
        events: ["animation_end", "error", "size_change"])

    // Display controls.
    add(["Text"], .visible, "TextControlView", .nativeView,
        events: ["selection_change", "tap"])
    add(["TextSpan"], .visible, "TextSpanControlView", .nativeView,
        events: ["click", "enter", "exit"])
    add(["Icon"], .visible, "IconControlView", .nativeView)
    add(["Image"], .visible, "ImageControlView", .nativeView)
    add(["ProgressBar"], .visible, "ProgressBarControlView", .nativeView)
    add(["ProgressRing"], .visible, "ProgressRingControlView", .nativeView)
    let spinKitWireTypes = [
      "SpinKitRotatingPlain", "SpinKitDoubleBounce", "SpinKitWave",
      "SpinKitWanderingCubes", "SpinKitFadingFour", "SpinKitFadingCube",
      "SpinKitPulse", "SpinKitChasingDots", "SpinKitThreeBounce", "SpinKitCircle",
      "SpinKitCubeGrid", "SpinKitFadingCircle", "SpinKitRotatingCircle",
      "SpinKitFoldingCube", "SpinKitPumpingHeart", "SpinKitHourGlass",
      "SpinKitPouringHourGlass", "SpinKitPouringHourGlassRefined", "SpinKitFadingGrid",
      "SpinKitRing", "SpinKitRipple", "SpinKitDualRing", "SpinKitSpinningCircle",
      "SpinKitSpinningLines", "SpinKitSquareCircle", "SpinKitThreeInOut",
      "SpinKitDancingSquare", "SpinKitPianoWave", "SpinKitPulsingGrid",
      "SpinKitWaveSpinner",
    ]
    add(
      ["RufletSpinKit"] + spinKitWireTypes,
      .visible, "RufletSpinKit.SpinKitControlView", .optionalBundle("RufletSpinKit"))
    add(["Rive"], .visible, "RufletRive.RiveControlView", .optionalBundle("RufletRive"))
    add(["Lottie"], .visible, "RufletLottie.LottieControlView", .optionalBundle("RufletLottie"),
        events: ["error", "load"])
    add(["CircleAvatar"], .visible, "CircleAvatarControlView", .nativeView,
        events: ["image_error"])
    add(["Badge"], .visible, "BadgeControlView", .nativeView)
    add(["ColorPicker"], .visible, "RufletColorPickers.RufletColorPickerControlView",
        .optionalBundle("RufletColorPickers"),
        events: ["color_change", "history_change", "hsv_color_change"])
    add(["HueRingPicker", "SlidePicker", "BlockPicker"], .visible,
        "RufletColorPickers.RufletColorPickerControlView",
        .optionalBundle("RufletColorPickers"), events: ["color_change"])
    add(["MaterialPicker"], .visible, "RufletColorPickers.RufletColorPickerControlView",
        .optionalBundle("RufletColorPickers"), events: ["color_change", "primary_change"])
    add(["MultipleChoiceBlockPicker"], .visible,
        "RufletColorPickers.RufletColorPickerControlView",
        .optionalBundle("RufletColorPickers"), events: ["colors_change"])
    add(["Markdown"], .visible, "MarkdownControlView", .nativeView,
        events: ["selection_change", "tap_link", "tap_text"])

    // Cross-platform button and value-control wire contracts rendered by
    // Apple-native controls on iOS and macOS.
    let buttonEvents: Set<String> = ["blur", "click", "focus", "hover", "long_press"]
    add(["Button", "ElevatedButton", "TextButton", "FilledButton", "FilledTonalButton",
         "OutlinedButton", "IconButton", "FilledIconButton", "FilledTonalIconButton",
         "OutlinedIconButton", "FloatingActionButton"], .visible,
        "ButtonControlView", .nativeView, events: buttonEvents)
    for type in ["IconButton", "FilledIconButton", "FilledTonalIconButton",
                 "OutlinedIconButton"] {
      result[type.lowercased()] = ControlDescriptor(
        wireType: type,
        classification: .visible,
        implementation: "ButtonControlView",
        rendering: .nativeView,
        supportedEvents: buttonEvents,
        supportedMethods: ["focus"])
    }
    add(["Chip"], .visible, "ChipControlView", .nativeView,
        events: ["click", "delete", "select"])
    add(["SegmentedButton"], .visible, "SegmentedButtonControlView", .nativeView,
        events: ["change"])
    // Flet gives each of these a FocusNode and reports focus/blur from it, so
    // the native marks must advertise the pair or FocusReporter never mounts.
    add(["Switch", "Checkbox"], .visible,
        "Native Apple selection control", .nativeView,
        events: ["blur", "change", "focus"])
    // Radio delegates value changes to RadioGroup; the radio itself owns only
    // its FocusNode events in Flet 0.80.5.
    add(["Radio"], .visible, "Native Apple radio control", .nativeView,
        events: ["blur", "focus"])
    add(["RadioGroup"], .visible, "RadioGroupControlView", .nativeView, events: ["change"])
    add(["Slider"], .visible, "SliderControlView", .nativeView,
        events: ["blur", "change", "change_end", "change_start", "focus"])
    add(["RangeSlider"], .visible, "RangeSliderControlView", .nativeView,
        events: ["change", "change_end", "change_start"])
    add(["TextField"], .visible, "Native text field", .nativeView,
        events: ["blur", "change", "click", "focus", "selection_change", "submit", "tap_outside"],
        methods: ["focus"])
    add(["CupertinoTextField"], .visible, "Native Cupertino text field", .nativeView,
        events: ["blur", "change", "click", "focus", "selection_change", "submit", "tap_outside"],
        methods: ["focus"])
    add(["CodeEditor"], .visible, "RufletCodeEditor.CodeEditorControlView",
        .optionalBundle("RufletCodeEditor"),
        events: ["blur", "change", "focus", "selection_change"],
        methods: ["focus", "fold_at", "fold_comment_at_line_zero", "fold_imports"])
    add(["SearchBar"], .visible, "SearchBarControlView", .nativeView,
        events: ["blur", "change", "focus", "submit", "tap", "tap_outside_bar"],
        methods: ["close_view", "focus", "open_view"])
    add(["Dropdown"], .visible, "DropdownControlView", .nativeView,
        events: ["blur", "focus", "select", "text_change"], methods: ["focus"])
    add(["DropdownM2"], .visible, "DropdownM2ControlView", .nativeView,
        events: ["blur", "change", "click", "focus"], methods: ["focus"])
    add(["AutoComplete"], .visible, "AutoCompleteControlView", .nativeView,
        events: ["change", "select"])
    add(["DatePicker", "TimePicker"], .visible,
        "DateTimePickerControlView", .nativeView,
        events: ["change", "dismiss", "entry_mode_change"])
    add(["DateRangePicker"], .visible,
        "DateTimePickerControlView", .nativeView, events: ["change", "dismiss"])

    // Data-only children consumed by the controls above.
    add(["Segment", "Option", "DropdownOption", "AutoCompleteSuggestion"],
        .structuralChild, "Parent-owned option metadata", .metadataOnly)

    // Collections.
    add(["ListView"], .visible, "ListViewControlView", .nativeView,
        events: ["scroll"], methods: ["scroll_to"])
    add(["GridView"], .visible, "GridViewControlView", .nativeView,
        events: ["scroll"], methods: ["scroll_to"])
    add(["ReorderableListView"], .visible, "ReorderableListControlView", .nativeView,
        events: ["reorder", "reorder_end", "reorder_start", "scroll"])
    add(["PageView"], .visible, "PageViewControlView", .nativeView,
        events: ["change"],
        methods: ["go_to_page", "jump_to", "jump_to_page", "next_page", "previous_page"])
    add(["ListTile"], .visible, "ListTileControlView", .nativeView,
        events: ["blur", "click", "focus", "long_press"])
    add(["CupertinoListTile"], .visible, "ListTileControlView", .nativeView,
        events: ["click"])
    add(["ExpansionTile"], .visible, "ExpansionTileControlView", .nativeView,
        events: ["change"])
    add(["ExpansionPanelList"], .visible, "ExpansionPanelListControlView", .nativeView,
        events: ["change"])
    add(["Tabs"], .visible, "TabsControlView", .nativeView,
        events: ["change"], methods: ["move_to"])
    add(["TabBar"], .visible, "TabBarControlView", .nativeView,
        events: ["click", "hover"])
    add(["TabBarView"], .visible, "TabBarViewControlView", .nativeView)
    add(["DataTable"], .visible, "DataTableControlView", .nativeView,
        events: ["double_tap", "long_press", "select_all", "select_change", "sort",
                 "tap", "tap_cancel", "tap_down"])
    add(["DataTable2"], .visible, "RufletDataTable2.DataTable2ControlView",
        .optionalBundle("RufletDataTable2"),
        events: ["double_tap", "long_press", "secondary_tap", "secondary_tap_down",
                 "select_all", "select_change", "sort", "tap", "tap_cancel", "tap_down"])
    add(["ExpansionPanel", "Tab"],
        .structuralChild, "Parent-owned collection metadata", .metadataOnly)
    add(["DataColumn"], .structuralChild, "Parent-owned DataColumn", .metadataOnly,
        events: ["sort"])
    add(["DataRow"], .structuralChild, "Parent-owned DataRow", .metadataOnly,
        events: ["long_press", "select_change"])
    add(["DataCell"], .structuralChild, "Parent-owned DataCell", .metadataOnly,
        events: ["double_tap", "long_press", "tap", "tap_cancel", "tap_down"])
    add([
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
        events: ["cancel", "open", "select"])
    add(["MenuBar"], .visible, "MenuBarControlView", .nativeView)
    add(["SubmenuButton"], .visible, "SubmenuButtonControlView", .nativeView,
        events: ["blur", "close", "focus", "hover", "open"])
    add(["MenuItemButton"], .visible, "MenuItemButtonControlView", .nativeView,
        events: ["blur", "click", "focus", "hover"])
    add(["PopupMenuItem"], .structuralChild, "Parent-owned popup menu entry", .metadataOnly,
        events: ["click"])
    add(["ContextMenu"], .visible, "ContextMenuControlView", .nativeView,
        events: ["dismiss", "select"], methods: ["open"])
    add(["CupertinoContextMenu"], .visible, "ContextMenuControlView", .nativeView)
    add(["SnackBarAction", "CupertinoContextMenuAction", "CupertinoActionSheetAction",
         "CupertinoDialogAction"], .visible, "DialogActionControlView", .nativeView,
        events: ["click"])

    // Gesture surfaces.
    add(["GestureDetector"], .visible, "GestureDetectorControlView", .nativeView,
        events: ["double_tap", "double_tap_cancel", "double_tap_down", "enter", "exit",
                 "force_press_end", "force_press_peak", "force_press_start", "force_press_update",
                 "horizontal_drag_cancel", "horizontal_drag_down", "horizontal_drag_end",
                 "horizontal_drag_start", "horizontal_drag_update", "hover", "long_press",
                 "long_press_cancel", "long_press_down", "long_press_end",
                 "long_press_move_update", "long_press_start", "long_press_up",
                 "multi_long_press", "multi_tap", "pan_cancel", "pan_down", "pan_end",
                 "pan_start", "pan_update", "right_pan_end", "right_pan_start",
                 "right_pan_update", "scale_end", "scale_start", "scale_update", "scroll",
                 "secondary_long_press", "secondary_long_press_cancel",
                 "secondary_long_press_down", "secondary_long_press_end",
                 "secondary_long_press_move_update", "secondary_long_press_start",
                 "secondary_long_press_up", "secondary_tap", "secondary_tap_cancel",
                 "secondary_tap_down", "secondary_tap_up", "tap", "tap_cancel", "tap_down",
                 "tap_move", "tap_up", "tertiary_long_press", "tertiary_long_press_cancel",
                 "tertiary_long_press_down", "tertiary_long_press_end",
                 "tertiary_long_press_move_update", "tertiary_long_press_start",
                 "tertiary_long_press_up", "tertiary_tap_cancel", "tertiary_tap_down",
                 "tertiary_tap_up", "vertical_drag_cancel", "vertical_drag_down",
                 "vertical_drag_end", "vertical_drag_start", "vertical_drag_update"])
    add(["Draggable"], .visible, "DraggableControlView", .nativeView,
        events: ["drag_complete", "drag_start"])
    add(["DragTarget"], .visible, "DragTargetControlView", .nativeView,
        events: ["accept", "leave", "move", "will_accept"])
    add(["Dismissible"], .visible, "DismissibleControlView", .nativeView,
        events: ["confirm_dismiss", "dismiss", "resize", "update"],
        methods: ["confirm_dismiss"])
    add(["InteractiveViewer"], .visible, "InteractiveViewerControlView", .nativeView,
        events: ["interaction_end", "interaction_start", "interaction_update"],
        methods: ["pan", "reset", "restore_state", "save_state", "zoom"])
    add(["KeyboardListener"], .visible, "KeyboardListenerControlView", .nativeView,
        events: ["key_down", "key_repeat", "key_up"], methods: ["focus"])

    // Cupertino-native controls.
    add(["CupertinoButton", "CupertinoFilledButton", "CupertinoTintedButton"], .visible,
        "CupertinoButtonControlView", .nativeView, events: buttonEvents, methods: ["focus"])
    add(["CupertinoSegmentedButton", "CupertinoSlidingSegmentedButton", "CupertinoPicker",
         "CupertinoDatePicker", "CupertinoTimerPicker"], .visible,
        "Cupertino native value control", .nativeView, events: ["change"])
    add(["CupertinoCheckbox"], .visible, "CupertinoSelectionControlView", .nativeView,
        events: ["blur", "change", "focus"])
    add(["CupertinoRadio"], .visible, "CupertinoSelectionControlView", .nativeView,
        events: ["blur", "focus"])
    add(["CupertinoSwitch"], .visible, "CupertinoSwitchControlView", .nativeView,
        events: ["blur", "change", "focus", "image_error"])
    add(["CupertinoSlider"], .visible, "CupertinoSliderControlView", .nativeView,
        events: ["change", "change_end", "change_start"])
    add(["CupertinoActivityIndicator"], .visible, "CupertinoActivityIndicatorControlView",
        .nativeView)
    add(["CupertinoAppBar"], .visible, "CupertinoAppBarControlView", .nativeView)
    add(["CupertinoNavigationBar"], .visible, "CupertinoNavigationBarControlView", .nativeView,
        events: ["change"])
    add(["CupertinoActionSheet"], .visible, "CupertinoActionSheetControlView", .nativeView)

    // Drawing, charts and their parent-owned data.
    add(["Canvas"], .visible, "CanvasControlView", .nativeView,
        events: ["resize"], methods: ["capture", "clear_capture", "get_capture"])
    add(["LineChart", "BarChart", "PieChart", "ScatterChart", "RadarChart",
        "CandlestickChart"], .visible, "RufletCharts.ChartControlView",
        .optionalBundle("RufletCharts"),
        events: ["event"])
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
    add(["BannerAd"], .visible, "RufletAds.BannerAdControlView",
        .optionalBundle("RufletAds"),
        events: ["click", "close", "error", "impression", "load", "open", "paid",
                 "will_dismiss"])
    add(["InterstitialAd"], .service, "RufletAds.InterstitialAdService", .serviceOnly,
        events: ["click", "close", "error", "impression", "load", "open"],
        methods: ["show"])
    add(["WebView"], .visible, "RufletWebView.WebViewControlView",
        .optionalBundle("RufletWebView"),
        events: ["console_message", "javascript_alert_dialog", "page_ended", "page_started",
                 "progress", "scroll", "url_change", "web_resource_error"],
        methods: ["can_go_back", "can_go_forward", "clear_cache", "clear_local_storage",
                  "disable_zoom", "enable_zoom", "get_current_url", "get_title",
                  "get_user_agent", "go_back", "go_forward", "load_file", "load_html",
                  "load_request", "reload", "run_javascript", "scroll_by", "scroll_to",
                  "set_javascript_mode"])
    add(["Video"], .visible, "RufletVideo.VideoControlView",
        .optionalBundle("RufletVideo"),
        events: ["complete", "enter_fullscreen", "error", "exit_fullscreen", "loaded",
                 "track_change"],
        methods: ["get_current_position", "get_duration", "is_completed", "is_playing",
                  "jump_to", "next", "pause", "play", "play_or_pause", "playlist_add",
                  "playlist_remove", "previous", "seek", "stop"])
    add(["Map"], .visible, "RufletMap.MapControlView", .optionalBundle("RufletMap"),
        events: ["event", "hover", "init", "long_press", "pointer_cancel", "pointer_down",
                 "pointer_up", "position_change", "secondary_tap", "tap"],
        methods: ["center_on", "move_to", "reset_rotation", "rotate_from", "zoom_in",
                  "zoom_out", "zoom_to"])
    add(["TileLayer", "MarkerLayer", "Marker", "CircleLayer", "CircleMarker",
         "PolylineLayer", "PolylineMarker", "PolygonLayer", "PolygonMarker",
         "SimpleAttribution", "RichAttribution", "TextSourceAttribution",
         "ImageSourceAttribution"], .structuralChild, "RufletMap layer metadata",
        .optionalBundle("RufletMap"))
    result["tilelayer"] = ControlDescriptor(
      wireType: "TileLayer", classification: .structuralChild,
      implementation: "RufletMap.ReportingTileOverlay", rendering: .optionalBundle("RufletMap"),
      supportedEvents: ["image_error"])
    result["simpleattribution"] = ControlDescriptor(
      wireType: "SimpleAttribution", classification: .structuralChild,
      implementation: "RufletMap.MapAttributionView", rendering: .optionalBundle("RufletMap"),
      supportedEvents: ["click"])
    result["richattribution"] = ControlDescriptor(
      wireType: "RichAttribution", classification: .structuralChild,
      implementation: "RufletMap.MapRichAttributionView", rendering: .optionalBundle("RufletMap"),
      supportedEvents: ["click"])
    result["textsourceattribution"] = ControlDescriptor(
      wireType: "TextSourceAttribution", classification: .structuralChild,
      implementation: "RufletMap.MapRichAttributionView", rendering: .optionalBundle("RufletMap"),
      supportedEvents: ["click"])
    result["imagesourceattribution"] = ControlDescriptor(
      wireType: "ImageSourceAttribution", classification: .structuralChild,
      implementation: "RufletMap.MapRichAttributionView", rendering: .optionalBundle("RufletMap"),
      supportedEvents: ["click"])
    add(["Camera"], .visible, "RufletCamera.CameraControlView",
        .optionalBundle("RufletCamera"),
        events: ["state_change", "stream_image"],
        methods: ["get_available_cameras", "get_exposure_offset_step_size",
                  "get_max_exposure_offset", "get_max_zoom_level",
                  "get_min_exposure_offset", "get_min_zoom_level", "initialize",
                  "lock_capture_orientation", "pause_preview", "pause_video_recording",
                  "prepare_for_video_recording", "resume_preview", "resume_video_recording",
                  "set_description", "set_exposure_mode", "set_exposure_offset",
                  "set_exposure_point", "set_flash_mode", "set_focus_mode",
                  "set_focus_point", "set_zoom_level", "start_image_stream",
                  "start_video_recording", "stop_image_stream", "stop_video_recording",
                  "supports_image_streaming", "take_picture", "unlock_capture_orientation"])
    add(["QrcodeScanner", "qrcode_scanner"], .visible,
        "RufletQRScanner.QRScannerControlView", .optionalBundle("RufletQRScanner"),
        events: ["detect", "error"],
        methods: ["reset_zoom_scale", "set_zoom_scale", "start", "stop",
                  "switch_camera", "toggle_torch"])
    add(["Audio"], .service, "RufletAudio.AudioService", .serviceOnly,
        events: ["duration_change", "loaded", "position_change", "seek_complete", "state_change"],
        methods: ["get_current_position", "get_duration", "pause", "play", "release",
                  "resume", "seek"])
    add(["AudioRecorder"], .service, "RufletAudioRecorder.AudioRecorderService", .serviceOnly,
        events: ["state_change", "stream"],
        methods: ["cancel_recording", "get_input_devices", "has_permission", "is_paused",
                  "is_recording", "is_supported_encoder", "pause_recording",
                  "resume_recording", "start_recording", "stop_recording"])
    add(["Battery"], .service, "BatteryService", .serviceOnly,
        events: ["state_change"],
        methods: ["get_battery_level", "get_battery_state", "is_in_battery_save_mode"])

    return result
  }()
}
