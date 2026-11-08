import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://popup-menu-select-payload-test'),
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
}

/// Taps [item] in a PopupMenuButton and returns every event sent to Ruby.
Future<List<(int, String, dynamic)>> _tapItem(
  WidgetTester tester,
  TargetPlatform platform,
  String item,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'PopupMenuButton',
    '_i': 1,
    'content': 'Menu',
    'on_select': true,
    'items': [
      {'_c': 'PopupMenuItem', '_i': 2, 'content': 'Copy', 'on_click': true},
      // A stray `text` on the wire must not replace the item id.
      {
        '_c': 'PopupMenuItem',
        '_i': 3,
        'content': 'Paste',
        'text': 'paste-label',
        'on_click': true,
      },
      {
        '_c': 'PopupMenuItem',
        '_i': 4,
        'content': 'Wrap lines',
        'checked': true,
        'on_click': true,
      },
    ],
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
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return backend.events.where((e) => e.$2 != 'open').toList();
}

void main() {
  // Material's PopupMenuButton is the reference: the item fires `click`
  // (with `!checked` for a checked item) and the button fires `select` with
  // the item id as a string.
  final expected = <String, List<(int, String, dynamic)>>{
    'Copy': [(2, 'click', null), (1, 'select', '2')],
    'Paste': [(3, 'click', null), (1, 'select', '3')],
    'Wrap lines': [(4, 'click', false), (1, 'select', '4')],
  };
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final MapEntry(key: item, value: events) in expected.entries) {
      testWidgets('$platform PopupMenuButton payload for "$item"', (
        tester,
      ) async {
        expect(await _tapItem(tester, platform, item), events);
      });
    }
  }
}
