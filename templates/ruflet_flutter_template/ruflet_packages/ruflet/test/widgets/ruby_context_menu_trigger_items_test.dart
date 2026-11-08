import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://context-menu-trigger-items-test'),
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
  ]) => events.add((controlId, eventName, eventData));

  Map selectPayload() =>
      events.singleWhere((e) => e.$1 == 1 && e.$2 == 'select').$3 as Map;
}

/// PopupMenuItems with ids base, base + 1, ...
List<Map<String, dynamic>> _list(int base, List<String> labels) => [
  for (final (index, label) in labels.indexed)
    {'_c': 'PopupMenuItem', '_i': base + index, 'content': label},
];

/// Ruflet.context_menu(text("Target"), **props, on_select:, on_dismiss:)
Future<_RecordingBackend> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> props,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'ContextMenu',
    '_i': 1,
    'content': {'_c': 'Text', '_i': 2, 'value': 'Target'},
    ...props,
    'on_select': true,
    'on_dismiss': true,
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

/// The native iOS gesture: a long press opens CupertinoContextMenu.
Future<void> _longPress(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text('Target')),
  );
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
}

List<String?> _shownActions(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(CupertinoContextMenuAction),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data)
    .toList();

Map _ids(Map payload) => {
  for (final key in ['b', 'tr', 'id', 'idx', 'ic']) key: payload[key],
};

void main() {
  testWidgets('iOS long press shows `items` with the default triggers', (
    tester,
  ) async {
    final backend = await _pump(tester, TargetPlatform.iOS, {
      'items': _list(10, ['Copy', 'Paste']),
    });
    await _longPress(tester);
    expect(_shownActions(tester), ['Copy', 'Paste']);
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    // Same as a right-click on Material: the secondary button, trigger down.
    expect(_ids(backend.selectPayload()), {
      'b': 'secondary',
      'tr': 'down',
      'id': 11,
      'idx': 1,
      'ic': 2,
    });
  });

  testWidgets('iOS long press prefers `secondary_items` (the context click)', (
    tester,
  ) async {
    await _pump(tester, TargetPlatform.iOS, {
      'items': _list(10, ['Shared']),
      'primary_items': _list(20, ['Primary']),
      'secondary_items': _list(30, ['Inspect', 'Rename']),
      'tertiary_items': _list(40, ['Middle']),
    });
    await _longPress(tester);
    expect(_shownActions(tester), ['Inspect', 'Rename']);
  });

  testWidgets('iOS long press uses `primary_items` bound to long_press', (
    tester,
  ) async {
    final backend = await _pump(tester, TargetPlatform.iOS, {
      'primary_trigger': 'long_press',
      'primary_items': _list(20, ['Primary']),
      'secondary_items': _list(30, ['Inspect']),
    });
    await _longPress(tester);
    expect(_shownActions(tester), ['Primary']);
    await tester.tap(find.text('Primary'));
    await tester.pumpAndSettle();
    final payload = backend.selectPayload();
    expect(payload['b'], 'primary');
    expect(payload['tr'], 'longPress');
    expect(payload['idx'], 0);
  });

  testWidgets('iOS honours a disabled secondary trigger', (tester) async {
    await _pump(tester, TargetPlatform.iOS, {
      'secondary_trigger': 'disabled',
      'secondary_items': _list(30, ['Inspect']),
      'items': _list(10, ['Shared']),
    });
    await _longPress(tester);
    expect(_shownActions(tester), ['Shared']);
  });

  testWidgets('iOS keeps desktop-only lists reachable by long press', (
    tester,
  ) async {
    final backend = await _pump(tester, TargetPlatform.iOS, {
      'tertiary_items': _list(40, ['Middle']),
    });
    expect(
      find.byType(CupertinoContextMenu),
      findsOneWidget,
      reason: 'no error box when only a per-button list is given',
    );
    await _longPress(tester);
    expect(_shownActions(tester), ['Middle']);
    await tester.tap(find.text('Middle'));
    await tester.pumpAndSettle();
    expect(backend.selectPayload()['b'], 'tertiary');
  });

  // Ruby sends `primary_trigger: "long_press"`; the Dart name is longPress.
  // Both spellings bind a touch long press to `primary_items` on both
  // designs and report the trigger as Material names it.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final trigger in ['long_press', 'longPress']) {
      testWidgets('$platform primary_trigger "$trigger" opens on long press', (
        tester,
      ) async {
        final backend = await _pump(tester, platform, {
          'primary_trigger': trigger,
          'primary_items': _list(20, ['Primary']),
          'secondary_items': _list(30, ['Inspect']),
        });
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Target')),
        );
        await tester.pump(kLongPressTimeout + kPressTimeout);
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('Inspect'), findsNothing);

        await tester.tap(find.text('Primary'));
        await tester.pumpAndSettle();
        expect(_ids(backend.selectPayload()), {
          'b': 'primary',
          'tr': 'longPress',
          'id': 20,
          'idx': 0,
          'ic': 1,
        });
      });
    }
  }

  testWidgets('iOS select payload matches a Material right-click', (
    tester,
  ) async {
    final props = {
      'items': _list(10, ['Shared']),
      'secondary_items': _list(30, ['Inspect', 'Rename']),
    };
    // Material: right-click opens secondary_items.
    final material = await _pump(tester, TargetPlatform.android, props);
    final mouse = await tester.startGesture(
      tester.getCenter(find.text('Target')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    final expected = _ids(material.selectPayload());
    expect(expected['b'], 'secondary');
    expect(expected['idx'], 1);

    final ios = await _pump(tester, TargetPlatform.iOS, props);
    await _longPress(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(_ids(ios.selectPayload()), expected);
  });
}
