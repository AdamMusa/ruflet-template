import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://search-bar-view'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    if (control.get("on_$eventName") == true) {
      events.add((control.id, eventName, data));
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

const _timeout = Duration(seconds: 5);

Future<(_Backend, Control)> _pump(
    WidgetTester tester, TargetPlatform platform,
    {String value = '', bool disabled = false}) async {
  final backend = _Backend(platform);
  final control = Control.fromMap({
    '_c': 'SearchBar',
    '_i': 10,
    'value': value,
    'bar_hint_text': 'Search fruit',
    'disabled': disabled,
    'on_focus': true,
    'on_blur': true,
    'on_change': true,
    'controls': [
      {'_c': 'Text', '_i': 11, 'value': 'Apple'},
      {'_c': 'Text', '_i': 12, 'value': 'Banana'},
    ],
  }, backend);
  final body = Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: 360, child: ControlWidget(control: control)),
  );
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  return (backend, control);
}

Future<void> _invoke(WidgetTester tester, Control control, String method,
    [Map<String, dynamic>? args]) async {
  final call = control.invokeMethod(method, args, _timeout);
  await tester.pumpAndSettle();
  await call;
}

void main() {
  group('iOS SearchBar view methods', () {
    const platform = TargetPlatform.iOS;

    FocusNode searchFocus(WidgetTester tester) => tester
        .widget<CupertinoSearchTextField>(find.byType(CupertinoSearchTextField))
        .focusNode!;

    testWidgets('open_view activates search and shows all suggestions',
        (tester) async {
      final (backend, control) = await _pump(tester, platform);
      expect(find.text('Apple'), findsNothing);

      await _invoke(tester, control, 'open_view');

      expect(searchFocus(tester).hasFocus, isTrue);
      // Like an active UISearchController, results show before typing.
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      final field = tester.getRect(find.byType(CupertinoSearchTextField));
      expect(tester.getTopLeft(find.text('Apple')).dy,
          greaterThan(field.bottom));
      expect(backend.events, [(10, 'focus', null)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('close_view sets the text, writes value and deactivates',
        (tester) async {
      final (backend, control) = await _pump(tester, platform);
      await _invoke(tester, control, 'open_view');
      backend.events.clear();

      await _invoke(tester, control, 'close_view', {'text': 'Apple'});

      expect(searchFocus(tester).hasFocus, isFalse);
      expect(find.text('Banana'), findsNothing);
      expect(
          tester
              .widget<CupertinoSearchTextField>(
                  find.byType(CupertinoSearchTextField))
              .controller!
              .text,
          'Apple');
      expect(control.get('value'), 'Apple');
      // Same as Material: closing writes value without a change event.
      expect(backend.events, [(10, 'blur', null)]);
    });

    testWidgets('close_view without text keeps the query', (tester) async {
      final (_, control) = await _pump(tester, platform, value: 'Ban');
      await _invoke(tester, control, 'open_view');
      await _invoke(tester, control, 'close_view');

      expect(searchFocus(tester).hasFocus, isFalse);
      expect(control.get('value'), 'Ban');
      expect(
          tester
              .widget<CupertinoSearchTextField>(
                  find.byType(CupertinoSearchTextField))
              .controller!
              .text,
          'Ban');
    });

    testWidgets('close_view on a closed search is a no-op', (tester) async {
      final (backend, control) = await _pump(tester, platform, value: 'q');
      await _invoke(tester, control, 'close_view', {'text': 'ignored'});
      expect(control.get('value'), 'q');
      expect(backend.events, isEmpty);
    });

    testWidgets('open_view on a disabled search bar is a no-op',
        (tester) async {
      final (_, control) = await _pump(tester, platform, disabled: true);
      await _invoke(tester, control, 'open_view');
      expect(searchFocus(tester).hasFocus, isFalse);
      expect(find.text('Apple'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving the field ends the opened view', (tester) async {
      final (_, control) = await _pump(tester, platform);
      await _invoke(tester, control, 'open_view');
      expect(find.text('Apple'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);

      // A plain tap focuses the field but keeps the typed-query behavior:
      // suggestions wait for text.
      await tester.tap(find.byType(CupertinoSearchTextField));
      await tester.pumpAndSettle();
      expect(searchFocus(tester).hasFocus, isTrue);
      expect(find.text('Apple'), findsNothing);
    });
  });

  testWidgets('Material SearchBar view methods are unchanged', (tester) async {
    final (_, control) =
        await _pump(tester, TargetPlatform.android, value: '');
    expect(find.text('Apple'), findsNothing);

    await _invoke(tester, control, 'open_view');
    expect(find.text('Apple'), findsOneWidget);

    await _invoke(tester, control, 'close_view', {'text': 'Banana'});
    expect(find.text('Apple'), findsNothing);
    expect(control.get('value'), 'Banana');
    expect(tester.takeException(), isNull);
  });
}
