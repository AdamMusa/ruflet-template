import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_list_tile.dart';
import 'package:ruflet/src/controls/list_tile.dart';
import 'package:ruflet/src/widgets/ruflet_cupertino_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <String>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://list-tile-events-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    events.add(name);
  }
}

Future<_Backend> _pumpTile(
    WidgetTester tester, TargetPlatform platform, Map<String, dynamic> props) async {
  final backend = _Backend(platform);
  final control = Control.fromMap({
    '_c': 'ListTile',
    '_i': 1,
    'title': {'_c': 'Text', '_i': 2, 'value': 'Row'},
    ...props,
  }, backend);
  final body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, child: ControlWidget(control: control)));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.android
        ? material.MaterialApp(home: material.Scaffold(body: body))
        : CupertinoApp(home: body),
  ));
  await tester.pump();
  return backend;
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    final rendererType = platform == TargetPlatform.android
        ? MaterialListTileSkin
        : CupertinoListTileSkin;

    for (final notched in [false, true]) {
      testWidgets(
          '$platform ListTile long press fires long_press and tap fires click (notched=$notched)',
          (tester) async {
        final backend = await _pumpTile(tester, platform, {
          'on_click': true,
          'on_long_press': true,
          if (notched) 'notched': true,
        });
        expect(find.byType(rendererType), findsOneWidget);

        await tester.longPress(find.text('Row'));
        await tester.pumpAndSettle();
        expect(backend.events, ['long_press']);
        if (platform != TargetPlatform.android) {
          // The pressed highlight must not stay on after a long press.
          final background = tester.widget<ColoredBox>(find
              .descendant(
                  of: find.byType(RufletCupertinoListTile),
                  matching: find.byType(ColoredBox))
              .first);
          expect(background.color, CupertinoColors.transparent);
        }

        backend.events.clear();
        await tester.tap(find.text('Row'));
        await tester.pumpAndSettle();
        expect(backend.events, ['click']);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform ListTile fires long_press without on_click',
        (tester) async {
      final backend =
          await _pumpTile(tester, platform, {'on_long_press': true});
      await tester.longPress(find.text('Row'));
      await tester.pumpAndSettle();
      expect(backend.events, ['long_press']);

      backend.events.clear();
      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(backend.events, isEmpty);
    });

    testWidgets('$platform ListTile long press without on_long_press is silent',
        (tester) async {
      final backend = await _pumpTile(tester, platform, {'on_click': true});
      await tester.longPress(find.text('Row'));
      await tester.pumpAndSettle();
      expect(backend.events, isNot(contains('long_press')));
    });

    testWidgets('$platform disabled ListTile ignores long press',
        (tester) async {
      final backend = await _pumpTile(tester, platform, {
        'on_click': true,
        'on_long_press': true,
        'disabled': true,
      });
      await tester.longPress(find.text('Row'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(backend.events, isEmpty);
    });
  }
}
