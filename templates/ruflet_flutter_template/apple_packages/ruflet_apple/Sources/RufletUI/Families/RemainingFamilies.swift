import RufletEngine
import SwiftUI

extension ControlRegistry {
  /// Pointer, drag and keyboard surfaces.
  static func gestures(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "GestureDetector":
      return AnyView(GestureDetectorControlView(node: node))
    case "Draggable":
      return AnyView(DraggableControlView(node: node))
    case "DragTarget":
      return AnyView(DragTargetControlView(node: node))
    case "Dismissible":
      return AnyView(DismissibleControlView(node: node))
    case "InteractiveViewer":
      return AnyView(InteractiveViewerControlView(node: node))
    case "KeyboardListener":
      return AnyView(KeyboardListenerControlView(node: node))
    default:
      return nil
    }
  }

  /// The Cupertino family.
  static func cupertino(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "CupertinoButton", "CupertinoFilledButton", "CupertinoTintedButton":
      return AnyView(CupertinoButtonControlView(node: node))
    case "CupertinoSwitch":
      return AnyView(CupertinoSwitchControlView(node: node))
    case "CupertinoSlider":
      return AnyView(CupertinoSliderControlView(node: node))
    case "CupertinoCheckbox":
      return AnyView(CupertinoSelectionControlView(node: node, kind: .checkbox))
    case "CupertinoRadio":
      return AnyView(CupertinoSelectionControlView(node: node, kind: .radio))
    case "CupertinoTextField":
      return AnyView(CupertinoTextFieldControlView(node: node))
    case "CupertinoSegmentedButton", "CupertinoSlidingSegmentedButton":
      return AnyView(CupertinoSegmentedControlView(node: node))
    case "CupertinoPicker":
      return AnyView(CupertinoPickerControlView(node: node))
    case "CupertinoDatePicker":
      return AnyView(CupertinoDatePickerControlView(node: node, timerMode: false))
    case "CupertinoTimerPicker":
      return AnyView(CupertinoDatePickerControlView(node: node, timerMode: true))
    case "CupertinoActivityIndicator":
      return AnyView(CupertinoActivityIndicatorControlView(node: node))
    case "CupertinoAppBar":
      return AnyView(CupertinoAppBarControlView(node: node))
    case "CupertinoNavigationBar":
      return AnyView(CupertinoNavigationBarControlView(node: node))
    case "CupertinoActionSheet":
      return AnyView(CupertinoActionSheetControlView(node: node))
    default:
      return nil
    }
  }

  /// Drawing, charts and media.
  static func media(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "Canvas":
      return AnyView(CanvasControlView(node: node))
    case "ColorPicker", "HueRingPicker", "SlidePicker", "MaterialPicker", "BlockPicker",
      "MultipleChoiceBlockPicker":
      return AnyView(MissingBundleControlView(node: node, bundle: "RufletColorPickers"))
    case "Map":
      return AnyView(MissingBundleControlView(node: node, bundle: "RufletMap"))
    case "TileLayer", "MarkerLayer", "Marker", "CircleLayer", "CircleMarker",
      "PolylineLayer", "PolylineMarker", "PolygonLayer", "PolygonMarker",
      "SimpleAttribution", "RichAttribution", "TextSourceAttribution",
      "ImageSourceAttribution":
      // MapKit consumes these through the Map parent.
      return AnyView(EmptyView())
    case "Audio", "AudioRecorder":
      // Services with no visible body; they answer method calls instead.
      return AnyView(EmptyView())
    case "Camera":
      // Ruflet treats camera as a *visual* service, so unlike the others it
      // renders. The preview lives in RufletCamera and registers itself there,
      // which is what keeps AVFoundation capture out of an app that does not
      // link it; this case is the fallback for one that does not.
      return AnyView(MissingBundleControlView(node: node, bundle: "RufletCamera"))
    case "QrcodeScanner", "qrcode_scanner":
      return AnyView(MissingBundleControlView(node: node, bundle: "RufletQRScanner"))
    case "Arc", "Circle", "Color", "Fill", "Line", "Oval", "Path", "Points", "Rect", "Shadow":
      // Canvas shapes, drawn by their Canvas parent.
      return AnyView(EmptyView())
    case "RadarChartTitle", "RadarDataSet", "RadarDataSetEntry", "CandlestickChartSpot",
      "ScatterChartSpot", "group", "rod", "stack_item", "axis", "l", "data", "p",
      "section":
      // Series data read by the chart that owns them.
      return AnyView(EmptyView())
    default:
      return nil
    }
  }
}
