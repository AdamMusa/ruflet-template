import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <String>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://popup-menu-button-cancel-test'),
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

Future<_RecordingBackend> _pumpMenuButton(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'PopupMenuButton',
    '_i': 1,
    'content': 'Menu',
    'items': [
      {'_c': 'PopupMenuItem', '_i': 2, 'content': 'Copy'},
    ],
    'on_open': true,
    'on_select': true,
    'on_cancel': true,
  }, backend);
  final body = Center(child: ControlWidget(control: control));
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: CupertinoPageScaffold(child: body))
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
  return backend;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform PopupMenuButton fires Ruby on_cancel when dismissed',
      (tester) async {
        final backend = await _pumpMenuButton(tester, platform);
        await tester.tap(find.text('Menu'));
        await tester.pumpAndSettle();
        expect(find.text('Copy'), findsOneWidget);

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Copy'), findsNothing);
        expect(backend.events, ['open', 'cancel']);
      },
    );

    testWidgets('$platform PopupMenuButton does not cancel on selection', (
      tester,
    ) async {
      final backend = await _pumpMenuButton(tester, platform);
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(backend.events, ['open', 'select']);
    });
  }
}
