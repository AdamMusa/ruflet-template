import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _RecordingBackend()
    : super(
        pageUri: Uri.parse('inprocess://context-menu-events-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      ) {
    platform = TargetPlatform.iOS;
  }

  @override
  void triggerControlEventById(
    int controlId,
    String eventName, [
    dynamic eventData,
  ]) => events.add((controlId, eventName, eventData));

  List<(String, dynamic)> eventsFor(int id) => [
    for (final (target, name, data) in events)
      if (target == id) (name, data),
  ];
}

/// Mirrors Ruflet.context_menu(text("Target"), items: [popup_menu_item(...)],
/// on_select:, on_dismiss:) rendered by the Cupertino design.
Future<_RecordingBackend> _pumpMenu(WidgetTester tester) async {
  final backend = _RecordingBackend();
  final control = Control.fromMap({
    '_c': 'ContextMenu',
    '_i': 1,
    'content': {'_c': 'Text', '_i': 2, 'value': 'Target'},
    'items': [
      {'_c': 'PopupMenuItem', '_i': 3, 'content': 'Open', 'on_click': true},
      {'_c': 'PopupMenuItem', '_i': 4, 'content': 'Delete'},
    ],
    'on_select': true,
    'on_dismiss': true,
  }, backend);
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(child: ControlWidget(control: control)),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return backend;
}

Future<void> _openMenu(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text('Target')),
  );
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
  expect(find.byType(CupertinoContextMenuAction), findsNWidgets(2));
}

void main() {
  testWidgets(
    'Cupertino ContextMenu fires Ruby on_select for the chosen item',
    (tester) async {
      final backend = await _pumpMenu(tester);
      await _openMenu(tester);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoContextMenuAction), findsNothing);
      final menuEvents = backend.eventsFor(1);
      expect(
        menuEvents.map((e) => e.$1),
        ['select'],
        reason: 'a selection must not also report a dismissal',
      );
      final data = menuEvents.single.$2 as Map;
      expect(data['id'], 4);
      expect(data['idx'], 1);
      expect(data['ic'], 2);
    },
  );

  testWidgets('Cupertino ContextMenu keeps the item click event', (
    tester,
  ) async {
    final backend = await _pumpMenu(tester);
    await _openMenu(tester);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(backend.eventsFor(3).map((e) => e.$1), ['click']);
    expect(backend.eventsFor(1).map((e) => e.$1), ['select']);
    expect((backend.eventsFor(1).single.$2 as Map)['idx'], 0);
  });

  testWidgets(
    'Cupertino ContextMenu fires Ruby on_dismiss when closed unchosen',
    (tester) async {
      final backend = await _pumpMenu(tester);
      await _openMenu(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoContextMenuAction), findsNothing);
      final menuEvents = backend.eventsFor(1);
      expect(menuEvents.map((e) => e.$1), ['dismiss']);
      expect((menuEvents.single.$2 as Map)['ic'], 2);

      // A second session reports independently of the first.
      await _openMenu(tester);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(backend.eventsFor(1).map((e) => e.$1), ['dismiss', 'select']);
    },
  );
}
