import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _RecordingBackend()
    : super(
        pageUri: Uri.parse('inprocess://material-context-menu-items-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      ) {
    platform = TargetPlatform.android;
  }

  @override
  void triggerControlEventById(
    int controlId,
    String eventName, [
    dynamic eventData,
  ]) => events.add((controlId, eventName, eventData));
}

/// PopupMenuItems with ids base, base + 1, ...
List<Map<String, dynamic>> _list(int base, List<String> labels) => [
  for (final (index, label) in labels.indexed)
    {'_c': 'PopupMenuItem', '_i': base + index, 'content': label},
];

/// Ruflet.context_menu(text("Target"), **props, on_select:, on_dismiss:)
Future<_RecordingBackend> _pump(
  WidgetTester tester,
  Map<String, dynamic> props,
) async {
  final backend = _RecordingBackend();
  final control = Control.fromMap({
    '_c': 'ContextMenu',
    '_i': 1,
    'content': {'_c': 'Text', '_i': 2, 'value': 'Target'},
    ...props,
    'on_select': true,
    'on_dismiss': true,
  }, backend);
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: ControlWidget(control: control)),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return backend;
}

Future<void> _rightClick(WidgetTester tester) async {
  final mouse = await tester.startGesture(
    tester.getCenter(find.text('Target')),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await mouse.up();
  await tester.pumpAndSettle();
}

List<String?> _menuLabels(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data)
    .toList();

void main() {
  testWidgets('right-click opens Ruby `items` when secondary has no list', (
    tester,
  ) async {
    // Ruflet.context_menu(text("Target"), items: [...]): the common case.
    final backend = await _pump(tester, {
      'items': _list(10, ['Copy', 'Paste']),
    });
    await _rightClick(tester);
    expect(_menuLabels(tester), ['Copy', 'Paste']);
    expect(
      backend.events.where((e) => e.$2 == 'dismiss'),
      isEmpty,
      reason: 'the menu must open, not report an empty dismissal',
    );

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    final select = backend.events
        .singleWhere((e) => e.$1 == 1 && e.$2 == 'select')
        .$3;
    expect(select['b'], 'secondary');
    expect(select['id'], 11);
    expect(select['idx'], 1);
    expect(select['ic'], 2);
  });

  testWidgets('a per-trigger list still wins over `items`', (tester) async {
    await _pump(tester, {
      'items': _list(10, ['Shared']),
      'secondary_items': _list(30, ['Inspect']),
    });
    await _rightClick(tester);
    expect(_menuLabels(tester), ['Inspect']);
  });

  testWidgets('`actions` remains the last fallback', (tester) async {
    await _pump(tester, {
      'actions': _list(50, ['Only action']),
    });
    await _rightClick(tester);
    expect(_menuLabels(tester), ['Only action']);
  });
}
