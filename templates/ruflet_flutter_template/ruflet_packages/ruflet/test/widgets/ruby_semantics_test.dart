import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/semantics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _EventBackend extends RufletBackend {
  final events = <(String, dynamic)>[];

  _EventBackend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://semantics-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    if (control.get("on_$eventName") == true) {
      events.add((eventName, data));
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

Future<_EventBackend> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> wire) async {
  final backend = _EventBackend(platform);
  final control = Control.fromMap(wire, backend);
  final body = Align(
      alignment: Alignment.topLeft, child: ControlWidget(control: control));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  await tester.pump();
  return backend;
}

Finder _semanticsWidget() => find
    .descendant(
        of: find.byType(SemanticsControl), matching: find.byType(Semantics))
    .first;

Map<String, dynamic> _text(int id, String value) =>
    {'_c': 'Text', '_i': id, 'value': value};

const _eventKeywords = [
  'on_copy',
  'on_cut',
  'on_decrease',
  'on_did_gain_accessibility_focus',
  'on_did_lose_accessibility_focus',
  'on_dismiss',
  'on_double_tap',
  'on_increase',
  'on_long_press',
  'on_move_cursor_backward_by_character',
  'on_move_cursor_forward_by_character',
  'on_paste',
  'on_scroll_down',
  'on_scroll_left',
  'on_scroll_right',
  'on_scroll_up',
  'on_set_text',
  'on_tap',
];

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final design = platform == TargetPlatform.iOS ? 'Cupertino' : 'Material';

    testWidgets('$design Semantics renders its Ruby content child',
        (tester) async {
      await _pump(tester, platform, {
        '_c': 'Semantics',
        '_i': 1,
        'label': 'greeting',
        'content': _text(2, 'Hello'),
      });
      final text = find.text('Hello');
      expect(text, findsOneWidget);
      expect(find.descendant(of: find.byType(SemanticsControl), matching: text),
          findsOneWidget);
      expect(tester.getSize(text).height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design Semantics exposes Ruby keys in the semantics tree',
        (tester) async {
      await _pump(tester, platform, {
        '_c': 'Semantics',
        '_i': 1,
        'container': true,
        'label': 'field',
        'textfield': true,
        'hint_text': 'type here',
        'on_tap_hint_text': 'activate',
        'on_long_press_hint_text': 'hold',
        'focus': true,
        'on_tap': true,
        'on_long_press': true,
        'content': _text(2, 'x'),
      });
      expect(
          tester.getSemantics(_semanticsWidget()),
          isSemantics(
            isTextField: true,
            isFocused: true,
            hint: 'type here',
            onTapHint: 'activate',
            onLongPressHint: 'hold',
            hasTapAction: true,
            hasLongPressAction: true,
          ));
    });

    testWidgets('$design Semantics exposes the Ruby identifier',
        (tester) async {
      await _pump(tester, platform, {
        '_c': 'Semantics',
        '_i': 1,
        'container': true,
        'identifier': 'save-button',
        'label': 'Save',
        'content': _text(2, 'Save'),
      });
      expect(tester.widget<Semantics>(_semanticsWidget()).properties.identifier,
          'save-button');
      expect(tester.getSemantics(_semanticsWidget()).getSemanticsData().identifier,
          'save-button');
      expect(find.bySemanticsIdentifier('save-button'), findsOneWidget);
    });

    testWidgets('$design Semantics without identifier sets none',
        (tester) async {
      await _pump(tester, platform, {
        '_c': 'Semantics',
        '_i': 1,
        'container': true,
        'label': 'Plain',
        'content': _text(2, 'Plain'),
      });
      expect(tester.widget<Semantics>(_semanticsWidget()).properties.identifier,
          isNull);
      expect(tester.getSemantics(_semanticsWidget()).getSemanticsData().identifier,
          isEmpty);
    });

    testWidgets('$design Semantics fires each Ruby on_* event by name',
        (tester) async {
      final backend = await _pump(tester, platform, {
        '_c': 'Semantics',
        '_i': 1,
        'container': true,
        'label': 'target',
        for (final keyword in _eventKeywords) keyword: true,
        'content': _text(2, 'Target'),
      });
      final node = tester.getSemantics(_semanticsWidget());
      final actions = <SemanticsAction, (String, Object?)>{
        SemanticsAction.tap: ('tap', null),
        SemanticsAction.longPress: ('long_press', null),
        SemanticsAction.increase: ('increase', null),
        SemanticsAction.decrease: ('decrease', null),
        SemanticsAction.dismiss: ('dismiss', null),
        SemanticsAction.scrollLeft: ('scroll_left', null),
        SemanticsAction.scrollRight: ('scroll_right', null),
        SemanticsAction.scrollUp: ('scroll_up', null),
        SemanticsAction.scrollDown: ('scroll_down', null),
        SemanticsAction.copy: ('copy', null),
        SemanticsAction.cut: ('cut', null),
        SemanticsAction.paste: ('paste', null),
        SemanticsAction.didGainAccessibilityFocus: (
          'did_gain_accessibility_focus',
          null
        ),
        SemanticsAction.didLoseAccessibilityFocus: (
          'did_lose_accessibility_focus',
          null
        ),
        SemanticsAction.moveCursorForwardByCharacter: (
          'move_cursor_forward_by_character',
          true
        ),
        SemanticsAction.moveCursorBackwardByCharacter: (
          'move_cursor_backward_by_character',
          false
        ),
        SemanticsAction.setText: ('set_text', 'typed'),
      };
      for (final MapEntry(key: action, value: (name, args))
          in actions.entries) {
        expect(node.getSemanticsData().hasAction(action), isTrue,
            reason: '$action is not wired');
        backend.events.clear();
        node.owner!.performAction(node.id, action, args);
        await tester.pump();
        expect(backend.events, [(name, args)], reason: '$action');
      }

      backend.events.clear();
      await tester.tap(find.text('Target'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Target'));
      await tester.pumpAndSettle();
      expect(backend.events.map((e) => e.$1), ['double_tap']);
    });

    testWidgets('$design Semantics ignores Flet-only key spellings',
        (tester) async {
      final backend = await _pump(tester, platform, {
        '_c': 'Semantics',
        '_i': 1,
        'container': true,
        'label': 'legacy',
        'text_field': true,
        'hint': 'flet hint',
        'focused': true,
        'on_click': true,
        'on_dismiss': true,
        'content': _text(2, 'Legacy'),
      });
      final node = tester.getSemantics(_semanticsWidget());
      final data = node.getSemanticsData();
      expect(data.hint, isEmpty);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.hasAction(SemanticsAction.longPress), isFalse);
      node.owner!.performAction(node.id, SemanticsAction.dismiss);
      await tester.pump();
      expect(backend.events.map((e) => e.$1), ['dismiss']);
    });
  }
}
