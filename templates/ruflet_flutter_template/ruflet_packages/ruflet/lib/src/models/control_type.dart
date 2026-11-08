import 'control.dart';

/// Legacy and transitional protocol names normalized to one logical control.
///
/// Renderers must branch on platform, never on a Material/Cupertino wire name.
/// The aliases remain accepted so existing applications continue to load while
/// new SDKs emit only the canonical names.
const Map<String, String> _controlTypeAliases = {
  "AdaptiveAlertDialog": "AlertDialog",
  "CupertinoAlertDialog": "AlertDialog",
  "AdaptiveAppBar": "AppBar",
  "CupertinoAppBar": "AppBar",
  "AdaptiveButton": "Button",
  "ElevatedButton": "Button",
  "CupertinoButton": "Button",
  "CupertinoFilledButton": "FilledButton",
  "CupertinoTintedButton": "FilledTonalButton",
  "AdaptiveCheckbox": "Checkbox",
  "CupertinoCheckbox": "Checkbox",
  "AdaptiveRadio": "Radio",
  "CupertinoRadio": "Radio",
  "AdaptiveSlider": "Slider",
  "CupertinoSlider": "Slider",
  "AdaptiveSwitch": "Switch",
  "CupertinoSwitch": "Switch",
  "AdaptiveTextField": "TextField",
  "CupertinoTextField": "TextField",
  "CupertinoActivityIndicator": "ProgressRing",
  "CupertinoFormRow": "FormRow",
  "CupertinoFormSection": "ListSection",
  "CupertinoListSection": "ListSection",
  "CupertinoListTile": "ListTile",
  "CupertinoNavigationBar": "NavigationBar",
  "CupertinoSegmentedButton": "SegmentedButton",
  "CupertinoSlidingSegmentedButton": "SegmentedButton",
  "CupertinoContextMenu": "ContextMenu",
  "CupertinoContextMenuAction": "ContextMenuAction",
  "PopupMenuItem": "ContextMenuAction",
  "CupertinoBottomSheet": "BottomSheet",
  "CupertinoActionSheet": "ActionSheet",
  "CupertinoActionSheetAction": "ActionSheetAction",
  "CupertinoDatePicker": "DatePicker",
  "CupertinoDialogAction": "Button",
  "CupertinoPicker": "Picker",
  "CupertinoTimerPicker": "TimerPicker",
  "CupertinoSliverNavigationBar": "SliverAppBar",
  "DropdownM2": "Dropdown",
};

String canonicalControlType(String type) => _controlTypeAliases[type] ?? type;

/// Properties a legacy wire alias implies. Clients from before ruflet
/// b9e52ff7 send a Cupertino wire name where the canonical type now takes a
/// declared property, so renderers branch on the property, never on the
/// wire name.
const Map<String, Map<String, Object?>> _controlTypeAliasProperties = {
  "CupertinoDatePicker": {"inline": true},
  "CupertinoSlidingSegmentedButton": {"sliding": true},
};

Map<String, Object?> controlTypeAliasProperties(String type) =>
    _controlTypeAliasProperties[type] ?? const {};

extension CanonicalControlType on Control {
  String get canonicalType => canonicalControlType(type);
}

/// Event names a legacy wire alias subscribes under. Renderers fire only the
/// canonical event; the backend delivers it under the name the old client
/// registered. Clients from before ruflet b9e52ff7 send `DropdownM2` with
/// `on_change`, the Material 2 name for what Dropdown calls `select`.
const Map<String, Map<String, String>> _controlTypeAliasEvents = {
  "DropdownM2": {"select": "change"},
};

String controlTypeAliasEventName(String type, String eventName) =>
    _controlTypeAliasEvents[type]?[eventName] ?? eventName;
