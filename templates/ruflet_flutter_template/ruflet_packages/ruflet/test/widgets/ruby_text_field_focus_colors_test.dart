import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <String>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://text-field-focus-colors'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    events.add(eventName);
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

const _bg = Color(0xFF111111);
const _focusedBg = Color(0xFFFFFF00);
const _color = Color(0xFF222222);
const _focusedColor = Color(0xFFFF0000);

Future<_Backend> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> extra) async {
  final backend = _Backend(platform);
  final field = Control.fromMap({
    '_c': 'TextField',
    '_i': 10,
    'value': 'Ada',
    'filled': true,
    'bgcolor': '#111111',
    'focused_bgcolor': '#ffff00',
    'color': '#222222',
    'focused_color': '#ff0000',
    ...extra,
  }, backend);
  final body = Center(
      child: SizedBox(width: 320, child: ControlWidget(control: field)));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  return backend;
}

Color? _textColor(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).style.color;

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  for (final shiftEnter in [false, true]) {
    final label = shiftEnter ? ' (shift_enter)' : '';

    testWidgets(
        'Material focused_bgcolor and focused_color follow focus$label',
        (tester) async {
      final backend = await _pump(
          tester, TargetPlatform.android, {'shift_enter': shiftEnter});
      material.InputDecoration decoration() => tester
          .widget<material.InputDecorator>(
              find.byType(material.InputDecorator))
          .decoration;

      expect(decoration().fillColor, _bg);
      expect(_textColor(tester), _color);

      await tester.showKeyboard(find.byType(EditableText));
      await tester.pumpAndSettle();
      expect(decoration().fillColor, _focusedBg);
      expect(_textColor(tester), _focusedColor);

      await _blur(tester);
      expect(decoration().fillColor, _bg);
      expect(_textColor(tester), _color);
      expect(backend.events, containsAllInOrder(['focus', 'blur']));
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform focused_bgcolor replaces fill_color while focused',
        (tester) async {
      await _pump(tester, platform, {'fill_color': '#00ff00'});
      Color? background() => platform == TargetPlatform.iOS
          ? tester
              .widget<CupertinoTextField>(find.byType(CupertinoTextField))
              .decoration
              ?.color
          : tester
              .widget<material.InputDecorator>(
                  find.byType(material.InputDecorator))
              .decoration
              .fillColor;

      expect(background(), const Color(0xFF00FF00));

      await tester.showKeyboard(find.byType(EditableText));
      await tester.pumpAndSettle();
      expect(background(), _focusedBg);

      await _blur(tester);
      expect(background(), const Color(0xFF00FF00));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('iOS focused_color behavior is unchanged', (tester) async {
    await _pump(tester, TargetPlatform.iOS, {});
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(_textColor(tester), _color);

    await tester.showKeyboard(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(_textColor(tester), _focusedColor);

    await _blur(tester);
    expect(_textColor(tester), _color);
  });
}
