import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://keyboard-dismiss-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 400, child: child));
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

List<Map<String, dynamic>> _items(int count) => [
      {'_c': 'TextField', '_i': 999, 'value': '', 'width': 100},
      for (var i = 0; i < count; i++)
        {
          '_c': 'Container',
          '_i': 1000 + i,
          'height': 50,
          'width': 50,
          'content': {'_c': 'Text', '_i': 2000 + i, 'value': 'Item $i'},
        }
    ];

Map<String, dynamic> _scrollable(String type, String? behavior) => {
      '_c': type == 'RefreshListView' ? 'ListView' : type,
      '_i': 1,
      'controls': _items(30),
      if (type == 'Column' || type == 'Row') 'scroll': 'auto',
      if (type == 'GridView') 'runs_count': 1,
      if (type == 'GridView') 'child_aspect_ratio': 4,
      if (type == 'ReorderableListView') 'expand': true,
      if (type == 'RefreshListView') 'on_refresh': true,
      if (behavior != null) 'keyboard_dismiss_behavior': behavior,
    };

void main() {
  test('keyboard_dismiss_behavior parsing accepts Ruby spellings', () {
    expect(parseKeyboardDismissBehavior(null), isNull);
    expect(parseKeyboardDismissBehavior('manual'),
        ScrollViewKeyboardDismissBehavior.manual);
    for (final spelling in ['onDrag', 'on_drag', 'ondrag', 'ON_DRAG']) {
      expect(parseKeyboardDismissBehavior(spelling),
          ScrollViewKeyboardDismissBehavior.onDrag,
          reason: spelling);
    }
    expect(
        parseKeyboardDismissBehavior(
            'bogus', ScrollViewKeyboardDismissBehavior.manual),
        ScrollViewKeyboardDismissBehavior.manual);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final type in [
      'ListView',
      'GridView',
      'Column',
      'Row',
      'ReorderableListView',
      'RefreshListView',
    ]) {
      for (final behavior in [null, 'manual', 'onDrag']) {
        final dismisses = behavior == 'onDrag';
        testWidgets(
            '${platform.name}: $type keyboard_dismiss_behavior=$behavior '
            '${dismisses ? 'unfocuses' : 'keeps focus'} on drag',
            (tester) async {
          final backend = _Backend(platform);
          final control = Control.fromMap(_scrollable(type, behavior), backend);
          await tester
              .pumpWidget(_host(backend, ControlWidget(control: control)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.showKeyboard(find.byType(EditableText));
          await tester.pump();
          final field = tester.widget<EditableText>(find.byType(EditableText));
          expect(field.focusNode.hasFocus, isTrue);

          final drag =
              type == 'Row' ? const Offset(-120, 0) : const Offset(0, -120);
          await tester.drag(find.text('Item 1'), drag);
          await tester.pumpAndSettle();
          expect(field.focusNode.hasFocus, dismisses ? isFalse : isTrue);
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant.only(platform));
      }
    }
  }
}
