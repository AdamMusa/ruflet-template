import 'package:ruflet/src/models/control_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('common and legacy control names resolve to one entry point', () {
    expect(canonicalControlType('Button'), 'Button');
    expect(canonicalControlType('AdaptiveButton'), 'Button');
    expect(canonicalControlType('ElevatedButton'), 'Button');
    expect(canonicalControlType('CupertinoButton'), 'Button');
    expect(canonicalControlType('CupertinoFilledButton'), 'FilledButton');
    expect(canonicalControlType('CupertinoTintedButton'), 'FilledTonalButton');
    expect(canonicalControlType('CupertinoTextField'), 'TextField');
    expect(canonicalControlType('CupertinoAppBar'), 'AppBar');
    expect(canonicalControlType('CupertinoActivityIndicator'), 'ProgressRing');
    expect(canonicalControlType('CupertinoListTile'), 'ListTile');
    expect(canonicalControlType('CupertinoNavigationBar'), 'NavigationBar');
    expect(canonicalControlType('CupertinoSegmentedButton'), 'SegmentedButton');
    expect(canonicalControlType('CupertinoSlidingSegmentedButton'),
        'SegmentedButton');
    expect(canonicalControlType('CupertinoContextMenu'), 'ContextMenu');
    expect(canonicalControlType('CupertinoContextMenuAction'),
        'ContextMenuAction');
    expect(canonicalControlType('PopupMenuItem'), 'ContextMenuAction');
    expect(canonicalControlType('CupertinoBottomSheet'), 'BottomSheet');
    expect(canonicalControlType('CupertinoActionSheet'), 'ActionSheet');
    expect(canonicalControlType('CupertinoActionSheetAction'),
        'ActionSheetAction');
    expect(canonicalControlType('CupertinoDatePicker'), 'DatePicker');
    expect(canonicalControlType('CupertinoDialogAction'), 'Button');
    expect(canonicalControlType('CupertinoPicker'), 'Picker');
    expect(canonicalControlType('CupertinoTimerPicker'), 'TimerPicker');
    expect(canonicalControlType('CupertinoSliverNavigationBar'),
        'SliverAppBar');
    expect(canonicalControlType('DropdownM2'), 'Dropdown');
  });

  test('a legacy alias receives the canonical event under its own name', () {
    expect(controlTypeAliasEventName('DropdownM2', 'select'), 'change');
    expect(controlTypeAliasEventName('DropdownM2', 'focus'), 'focus');
    expect(controlTypeAliasEventName('Dropdown', 'select'), 'select');
    expect(controlTypeAliasEventName('Container', 'click'), 'click');
  });

  test('unrelated control names are unchanged', () {
    expect(canonicalControlType('Container'), 'Container');
    expect(canonicalControlType('CustomExtensionControl'),
        'CustomExtensionControl');
  });
}
