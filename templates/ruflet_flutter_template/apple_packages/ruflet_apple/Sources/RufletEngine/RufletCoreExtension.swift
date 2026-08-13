import SwiftUI

/// Core control and Apple service entry point, mirroring FletCoreExtension.
///
/// Every exposed wire control is registered explicitly. A missing case is a
/// porting error, never a request to switch to another renderer.
@MainActor
public struct RufletCoreExtension: RufletExtension {
  private let services = RufletCoreServiceExtension()

  public let renderedControlTypes: Set<String> = [
    "AdaptiveAlertDialog", "AdaptiveButton", "AdaptiveCheckbox", "AdaptiveRadio", "AdaptiveSlider", "AdaptiveSwitch", "AdaptiveTextField",
    "AlertDialog", "AnimatedSwitcher", "AppBar", "AutoComplete", "AutofillGroup", "Banner", "BottomAppBar", "BottomSheet", "Button", "Card", "Checkbox", "Chip", "CircleAvatar", "Column", "Container", "ContextMenu",
    "CupertinoButton", "CupertinoCheckbox", "CupertinoDialogAction", "CupertinoFilledButton",
    "CupertinoActionSheet", "CupertinoActionSheetAction", "CupertinoActivityIndicator", "CupertinoAlertDialog", "CupertinoAppBar", "CupertinoBottomSheet", "CupertinoContextMenu", "CupertinoContextMenuAction", "CupertinoDatePicker", "CupertinoListTile", "CupertinoPicker", "CupertinoRadio", "CupertinoSegmentedButton", "CupertinoSlider", "CupertinoSlidingSegmentedButton", "CupertinoSwitch", "CupertinoTextField", "CupertinoTimerPicker", "CupertinoTintedButton", "Dismissible",
    "DataTable", "DatePicker", "DateRangePicker", "Divider", "Draggable", "DragTarget", "Dropdown", "DropdownM2", "ExpansionPanelList", "ExpansionTile", "FilledButton", "FilledIconButton", "FilledTonalButton", "FilledTonalIconButton", "FloatingActionButton", "GestureDetector", "GridView", "Hero",
    "CupertinoNavigationBar", "FletApp", "Icon", "IconButton", "Image", "InteractiveViewer", "KeyboardListener", "ListTile", "ListView", "MenuBar", "MenuItemButton", "MergeSemantics", "NavigationBar", "NavigationBarDestination", "NavigationDrawer", "NavigationRail", "OutlinedButton", "OutlinedIconButton", "Page", "PageView", "Pagelet", "PopupMenuButton",
    "Placeholder", "ProgressBar", "ProgressRing", "Radio", "RadioGroup", "RangeSlider",
    "ReorderableDragHandle", "ReorderableListView", "ResponsiveRow", "Row", "SafeArea",
    "Screenshot", "SearchBar", "SegmentedButton", "SelectionArea", "Semantics", "ShaderMask", "Shimmer", "Slider", "SnackBar", "Stack", "SubmenuButton", "Switch", "Tab", "TabBar", "TabBarView", "Tabs", "Text", "TextButton", "TextField", "TimePicker", "View",
    "TransparentPointer", "VerticalDivider", "WindowDragArea",
  ]

  public init() {}

  public func createView(for control: RufletControl) -> AnyView? {
    switch control.type {
    case "AdaptiveAlertDialog", "AlertDialog":
      return AnyView(AdaptiveAlertDialogControl(control: control))
    case "AdaptiveButton", "Button", "FilledButton", "FilledTonalButton", "OutlinedButton", "TextButton":
      return AnyView(AdaptiveButtonControl(control: control))
    case "AdaptiveCheckbox", "Checkbox":
      return AnyView(AdaptiveCheckboxControl(control: control))
    case "AdaptiveRadio", "Radio":
      return AnyView(AdaptiveRadioControl(control: control))
    case "AdaptiveSlider", "Slider":
      return AnyView(AdaptiveSliderControl(control: control))
    case "AdaptiveSwitch", "Switch":
      return AnyView(AdaptiveSwitchControl(control: control))
    case "AdaptiveTextField", "TextField":
      return AnyView(AdaptiveTextFieldControl(control: control))
    case "AnimatedSwitcher": return AnyView(AnimatedSwitcherControl(control: control))
    case "AppBar": return AnyView(AppBarControl(control: control))
    case "AutoComplete": return AnyView(AutoCompleteControl(control: control))
    case "AutofillGroup": return AnyView(AutofillGroupControl(control: control))
    case "Banner": return AnyView(BannerControl(control: control))
    case "BottomAppBar": return AnyView(BottomAppBarControl(control: control))
    case "BottomSheet": return AnyView(BottomSheetControl(control: control))
    case "Card": return AnyView(CardControl(control: control))
    case "Chip": return AnyView(ChipControl(control: control))
    case "CircleAvatar": return AnyView(CircleAvatarControl(control: control))
    case "Container": return AnyView(ContainerControl(control: control))
    case "ContextMenu": return AnyView(ContextMenuControl(control: control))
    case "CupertinoButton", "CupertinoFilledButton", "CupertinoTintedButton":
      return AnyView(CupertinoButtonControl(control: control))
    case "CupertinoActionSheet": return AnyView(CupertinoActionSheetControl(control: control))
    case "CupertinoActionSheetAction": return AnyView(CupertinoActionSheetActionControl(control: control))
    case "CupertinoActivityIndicator": return AnyView(CupertinoActivityIndicatorControl(control: control))
    case "CupertinoAlertDialog": return AnyView(CupertinoAlertDialogControl(control: control))
    case "CupertinoCheckbox": return AnyView(CupertinoCheckboxControl(control: control))
    case "CupertinoDialogAction": return AnyView(CupertinoDialogActionControl(control: control))
    case "CupertinoAppBar": return AnyView(CupertinoAppBarControl(control: control))
    case "CupertinoBottomSheet": return AnyView(CupertinoBottomSheetControl(control: control))
    case "CupertinoContextMenu": return AnyView(CupertinoContextMenuControl(control: control))
    case "CupertinoContextMenuAction": return AnyView(CupertinoContextMenuActionControl(control: control))
    case "CupertinoDatePicker": return AnyView(CupertinoDatePickerControl(control: control))
    case "CupertinoListTile": return AnyView(CupertinoListTileControl(control: control))
    case "CupertinoNavigationBar": return AnyView(CupertinoNavigationBarControl(control: control))
    case "CupertinoPicker": return AnyView(CupertinoPickerControl(control: control))
    case "CupertinoRadio": return AnyView(CupertinoRadioControl(control: control))
    case "CupertinoSegmentedButton": return AnyView(CupertinoSegmentedButtonControl(control: control))
    case "CupertinoSlider": return AnyView(CupertinoSliderControl(control: control))
    case "CupertinoSlidingSegmentedButton": return AnyView(CupertinoSlidingSegmentedButtonControl(control: control))
    case "CupertinoSwitch": return AnyView(CupertinoSwitchControl(control: control))
    case "CupertinoTextField": return AnyView(CupertinoTextFieldControl(control: control))
    case "CupertinoTimerPicker": return AnyView(CupertinoTimerPickerControl(control: control))
    case "DataTable": return AnyView(DataTableControl(control: control))
    case "DatePicker": return AnyView(DatePickerControl(control: control))
    case "DateRangePicker": return AnyView(DateRangePickerControl(control: control))
    case "Divider": return AnyView(DividerControl(control: control))
    case "Dismissible": return AnyView(DismissibleControl(control: control))
    case "Draggable": return AnyView(DraggableControl(control: control))
    case "DragTarget": return AnyView(DragTargetControl(control: control))
    case "Dropdown": return AnyView(DropdownControl(control: control))
    case "DropdownM2": return AnyView(DropdownM2Control(control: control))
    case "ExpansionPanelList": return AnyView(ExpansionPanelListControl(control: control))
    case "ExpansionTile": return AnyView(ExpansionTileControl(control: control))
    case "FilledIconButton", "FilledTonalIconButton", "IconButton", "OutlinedIconButton":
      return AnyView(IconButtonControl(control: control))
    case "FloatingActionButton": return AnyView(FloatingActionButtonControl(control: control))
    case "GestureDetector": return AnyView(GestureDetectorControl(control: control))
    case "FletApp": return AnyView(FletAppControl(control: control))
    case "VerticalDivider": return AnyView(VerticalDividerControl(control: control))
    case "View": return AnyView(ViewControl(control: control))
    case "Icon": return AnyView(IconControl(control: control))
    case "Image": return AnyView(ImageControl(control: control))
    case "Hero": return AnyView(HeroControl(control: control))
    case "InteractiveViewer": return AnyView(InteractiveViewerControl(control: control))
    case "GridView": return AnyView(GridViewControl(control: control))
    case "ListView": return AnyView(ListViewControl(control: control))
    case "ListTile": return AnyView(ListTileControl(control: control))
    case "KeyboardListener": return AnyView(KeyboardListenerControl(control: control))
    case "MenuBar": return AnyView(MenuBarControl(control: control))
    case "MenuItemButton": return AnyView(MenuItemButtonControl(control: control))
    case "NavigationBar": return AnyView(NavigationBarControl(control: control))
    case "NavigationBarDestination": return AnyView(NavigationBarDestinationControl(control: control))
    case "NavigationDrawer": return AnyView(NavigationDrawerControl(control: control))
    case "NavigationRail": return AnyView(NavigationRailControl(control: control))
    case "ProgressBar": return AnyView(ProgressBarControl(control: control))
    case "ProgressRing": return AnyView(ProgressRingControl(control: control))
    case "PageView": return AnyView(PageViewControl(control: control))
    case "Pagelet": return AnyView(PageletControl(control: control))
    case "PopupMenuButton": return AnyView(PopupMenuButtonControl(control: control))
    case "RadioGroup": return AnyView(RadioGroupControl(control: control))
    case "RangeSlider": return AnyView(RangeSliderControl(control: control))
    case "ReorderableDragHandle": return AnyView(ReorderableDragHandleControl(control: control))
    case "ReorderableListView": return AnyView(ReorderableListViewControl(control: control))
    case "ResponsiveRow": return AnyView(ResponsiveRowControl(control: control))
    case "Screenshot": return AnyView(ScreenshotControl(control: control))
    case "SearchBar": return AnyView(SearchBarControl(control: control))
    case "SegmentedButton": return AnyView(SegmentedButtonControl(control: control))
    case "SnackBar": return AnyView(SnackBarControl(control: control))
    case "SubmenuButton": return AnyView(SubmenuButtonControl(control: control))
    case "Tab": return AnyView(TabControl(control: control))
    case "TabBar": return AnyView(TabBarControl(control: control))
    case "TabBarView": return AnyView(TabBarViewControl(control: control))
    case "Tabs": return AnyView(TabsControl(control: control))
    case "Text": return AnyView(TextControl(control: control))
    case "TimePicker": return AnyView(TimePickerControl(control: control))
    case "Row": return AnyView(RowControl(control: control))
    case "Column": return AnyView(ColumnControl(control: control))
    case "Stack": return AnyView(StackControl(control: control))
    case "SafeArea": return AnyView(SafeAreaControl(control: control))
    case "TransparentPointer": return AnyView(TransparentPointerControl(control: control))
    case "MergeSemantics": return AnyView(MergeSemanticsControl(control: control))
    case "SelectionArea": return AnyView(SelectionAreaControl(control: control))
    case "Semantics": return AnyView(SemanticsControl(control: control))
    case "ShaderMask": return AnyView(ShaderMaskControl(control: control))
    case "Shimmer": return AnyView(ShimmerControl(control: control))
    case "Placeholder": return AnyView(PlaceholderControl(control: control))
    case "Page": return AnyView(PageControl(control: control))
    case "WindowDragArea": return AnyView(WindowDragAreaControl(control: control))
    default: return nil
    }
  }

  public func createService(for control: RufletControl) -> RufletService? {
    services.createService(for: control)
  }

  public func createAppleIcon(for iconCode: Int) -> RufletAppleIcon? {
    RufletAppleIconCatalog.icon(for: iconCode)
  }
}
