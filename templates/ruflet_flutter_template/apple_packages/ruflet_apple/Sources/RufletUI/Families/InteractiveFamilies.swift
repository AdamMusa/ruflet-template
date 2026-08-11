import RufletEngine
import SwiftUI

extension ControlRegistry {
  /// Every Material button variant plus the button-shaped controls.
  static func buttons(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "Button", "ElevatedButton", "TextButton", "FilledButton", "FilledTonalButton",
      "OutlinedButton", "IconButton", "FilledIconButton", "FilledTonalIconButton",
      "OutlinedIconButton", "FloatingActionButton":
      return AnyView(ButtonControlView(node: node, variant: ButtonVariant(wireType: node.type)))
    case "Chip":
      return AnyView(ChipControlView(node: node))
    case "SegmentedButton":
      return AnyView(SegmentedButtonControlView(node: node))
    case "Segment", "Option", "DropdownOption", "AutoCompleteSuggestion":
      // Data-carrying children rendered by their parent, never on their own.
      return AnyView(EmptyView())
    default:
      return nil
    }
  }

  /// Value-carrying controls: the ones that report `change`.
  static func inputs(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "Switch":
      return AnyView(SwitchControlView(node: node))
    case "Checkbox":
      return AnyView(CheckboxControlView(node: node))
    case "Radio":
      return AnyView(RadioControlView(node: node))
    case "RadioGroup":
      return AnyView(RadioGroupControlView(node: node))
    case "Slider":
      return AnyView(SliderControlView(node: node))
    case "RangeSlider":
      return AnyView(RangeSliderControlView(node: node))
    case "TextField":
      return AnyView(TextFieldControlView(node: node))
    case "CodeEditor":
      return AnyView(CodeEditorControlView(node: node))
    case "SearchBar":
      return AnyView(SearchBarControlView(node: node))
    case "Dropdown":
      return AnyView(DropdownControlView(node: node))
    case "DropdownM2":
      return AnyView(DropdownM2ControlView(node: node))
    case "AutoComplete":
      return AnyView(AutoCompleteControlView(node: node))
    case "DatePicker":
      return AnyView(DateTimePickerControlView(node: node, kind: .date))
    case "TimePicker":
      return AnyView(DateTimePickerControlView(node: node, kind: .time))
    case "DateRangePicker":
      return AnyView(DateTimePickerControlView(node: node, kind: .dateRange))
    default:
      return nil
    }
  }
}
