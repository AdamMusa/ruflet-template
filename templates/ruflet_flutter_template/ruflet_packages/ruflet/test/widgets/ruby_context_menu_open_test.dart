import 'dart:async';

import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://context-menu-open'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

/// The Ruby side waits this long; the iOS reply must not depend on it.
const _rubyTimeout = Duration(seconds: 30);

Future<Control> _pump(WidgetTester tester, TargetPlatform platform) async {
  final backend = _Backend(platform);
  final menu = Control.fromMap({
    '_c': 'ContextMenu',
    '_i': 10,
    'content': {'_c': 'Text', '_i': 11, 'value': 'Hold me'},
    'actions': [
      {
        '_c': 'ContextMenuAction',
        '_i': 12,
        'content': {'_c': 'Text', '_i': 13, 'value': 'Copy'}
      }
    ],
  }, backend);
  final body = Center(child: ControlWidget(control: menu));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  return menu;
}

void main() {
  testWidgets('iOS ContextMenu.open replies at once with the reason',
      (tester) async {
    final menu = await _pump(tester, TargetPlatform.iOS);
    expect(find.byType(CupertinoContextMenu), findsOneWidget);

    var settled = false;
    Object? error;
    unawaited(menu
        .invokeMethod('open', const {}, _rubyTimeout)
        .then((_) {}, onError: (Object e) {
      error = e;
    }).whenComplete(() => settled = true));
    await tester.pump();

    expect(settled, isTrue);
    expect(
        error,
        isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('ContextMenu.open'), contains('long press'),
                contains('action_sheet'))));
    // Nothing was presented.
    expect(find.text('Copy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS ContextMenu rejects other method names', (tester) async {
    final menu = await _pump(tester, TargetPlatform.iOS);
    Object? error;
    await menu
        .invokeMethod('close', const {}, _rubyTimeout)
        .then((_) {}, onError: (Object e) {
      error = e;
    });
    expect(error.toString(), contains('Unknown ContextMenu method: close'));
  });

  testWidgets('Material ContextMenu.open still presents the menu',
      (tester) async {
    final menu = await _pump(tester, TargetPlatform.android);
    expect(find.text('Copy'), findsNothing);

    final call = menu.invokeMethod('open', const {}, _rubyTimeout);
    await tester.pumpAndSettle();
    await call;
    expect(find.text('Copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
