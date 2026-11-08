import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <String>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://menu-item-button-focus-events-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      ) {
    this.platform = platform;
  }

  @override
  void triggerControlEventById(
    int controlId,
    String eventName, [
    dynamic eventData,
  ]) => events.add(eventName);
}

Future<_RecordingBackend> _pump(
  WidgetTester tester,
  TargetPlatform platform, {
  bool autofocus = false,
}) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'MenuItemButton',
    '_i': 1,
    'content': 'File',
    'on_click': true,
    if (autofocus) 'autofocus': true,
    'on_focus': true,
    'on_blur': true,
  }, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: ControlWidget(control: control),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  return backend;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform MenuItemButton fires Ruby on_focus and on_blur', (
      tester,
    ) async {
      final backend = await _pump(tester, platform);
      expect(backend.events, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(backend.events, ['focus']);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(backend.events, ['focus', 'blur']);
    });

    testWidgets('$platform MenuItemButton honors Ruby autofocus', (
      tester,
    ) async {
      final backend = await _pump(tester, platform, autofocus: true);
      expect(backend.events, ['focus']);
    });
  }
}
