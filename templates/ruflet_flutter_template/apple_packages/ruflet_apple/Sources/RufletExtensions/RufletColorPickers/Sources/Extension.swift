import RufletEngine
import SwiftUI

@MainActor
public struct RufletColorPickersExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletColorPickers.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    switch control.type {
    case "ColorPicker": AnyView(ColorPickerControl(control: control))
    case "HueRingPicker": AnyView(HueRingPickerControl(control: control))
    case "SlidePicker": AnyView(SlidePickerControl(control: control))
    case "MaterialPicker": AnyView(MaterialPickerControl(control: control))
    case "BlockPicker": AnyView(BlockPickerControl(control: control))
    case "MultipleChoiceBlockPicker": AnyView(MultipleChoiceBlockPickerControl(control: control))
    default: nil
    }
  }
}
