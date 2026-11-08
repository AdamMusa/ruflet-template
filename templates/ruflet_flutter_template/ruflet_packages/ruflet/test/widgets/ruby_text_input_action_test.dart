import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _Backend(TargetPlatform targetPlatform)
      : super(
            pageUri: Uri.parse('ruflet://text-input-action-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = targetPlatform;
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

void main() {
  group('parseTextInputAction', () {
    test('accepts camelCase, snake_case and any letter case', () {
      expect(parseTextInputAction('done', TargetPlatform.android),
          TextInputAction.done);
      expect(parseTextInputAction('NEXT', TargetPlatform.android),
          TextInputAction.next);
      expect(parseTextInputAction('continueAction', TargetPlatform.iOS),
          TextInputAction.continueAction);
      expect(parseTextInputAction('continue_action', TargetPlatform.iOS),
          TextInputAction.continueAction);
      expect(parseTextInputAction('emergency_call', TargetPlatform.iOS),
          TextInputAction.emergencyCall);
      expect(parseTextInputAction(null, TargetPlatform.iOS), isNull);
      expect(parseTextInputAction('bogus', TargetPlatform.android), isNull);
    });

    test('drops actions the platform keyboard does not support', () {
      const android = {
        'none': TextInputAction.none,
        'unspecified': TextInputAction.unspecified,
        'done': TextInputAction.done,
        'send': TextInputAction.send,
        'go': TextInputAction.go,
        'search': TextInputAction.search,
        'next': TextInputAction.next,
        'previous': TextInputAction.previous,
        'newline': TextInputAction.newline,
      };
      const ios = {
        'unspecified': TextInputAction.unspecified,
        'done': TextInputAction.done,
        'send': TextInputAction.send,
        'go': TextInputAction.go,
        'search': TextInputAction.search,
        'next': TextInputAction.next,
        'newline': TextInputAction.newline,
        'continueAction': TextInputAction.continueAction,
        'join': TextInputAction.join,
        'route': TextInputAction.route,
        'emergencyCall': TextInputAction.emergencyCall,
      };
      for (final action in TextInputAction.values) {
        expect(parseTextInputAction(action.name, TargetPlatform.android),
            android[action.name],
            reason: 'android ${action.name}');
        expect(parseTextInputAction(action.name, TargetPlatform.iOS),
            ios[action.name],
            reason: 'iOS ${action.name}');
        // Desktop and other targets have no platform restriction.
        expect(parseTextInputAction(action.name, TargetPlatform.macOS), action,
            reason: 'macOS ${action.name}');
        expect(
            parseTextInputAction(action.name, TargetPlatform.windows), action,
            reason: 'windows ${action.name}');
      }
    });
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final cupertino = platform == TargetPlatform.iOS;
    final fieldType = cupertino ? CupertinoTextField : TextField;

    Future<_Backend> pumpFields(
        WidgetTester tester, List<Map<String, dynamic>> fields) async {
      final backend = _Backend(platform);
      var id = 100;
      final controls = [
        for (final props in fields)
          Control.fromMap({'_c': 'TextField', '_i': ++id, ...props}, backend)
      ];
      for (final control in controls) {
        backend.controlsIndex.set(control.id, control);
      }
      final body = Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final control in controls) ControlWidget(control: control),
            ],
          ),
        ),
      );
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: cupertino
            ? CupertinoApp(home: CupertinoPageScaffold(child: body))
            : MaterialApp(home: Scaffold(body: body)),
      ));
      return backend;
    }

    Finder editable(int index) => find.byType(EditableText).at(index);

    EditableText editableWidget(WidgetTester tester, int index) =>
        tester.widget<EditableText>(editable(index));

    testWidgets(
        '$platform next moves focus to the following field and submits',
        (tester) async {
      final backend = await pumpFields(tester, [
        {
          'value': 'ada@example.com',
          'text_input_action': 'next',
          'on_submit': true,
          'on_blur': true,
        },
        {
          'value': 'secret',
          'password': true,
          'text_input_action': 'done',
          'on_submit': true,
          'on_focus': true,
        },
      ]);

      expect(find.byType(fieldType), findsNWidgets(2));
      expect(editableWidget(tester, 0).textInputAction, TextInputAction.next);
      expect(editableWidget(tester, 1).textInputAction, TextInputAction.done);

      await tester.showKeyboard(editable(0));
      expect(editableWidget(tester, 0).focusNode.hasFocus, isTrue);
      backend.events.clear();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(editableWidget(tester, 0).focusNode.hasFocus, isFalse);
      expect(editableWidget(tester, 1).focusNode.hasFocus, isTrue);
      expect(backend.events, contains((101, 'submit', 'ada@example.com')));
      expect(backend.events, contains((101, 'blur', null)));
      expect(backend.events, contains((102, 'focus', null)));

      backend.events.clear();
      await tester.showKeyboard(editable(1));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(editableWidget(tester, 1).focusNode.hasFocus, isFalse);
      expect(backend.events, [(102, 'submit', 'secret')]);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('$platform sanitizes actions the keyboard does not support',
        (tester) async {
      await pumpFields(tester, [
        {'text_input_action': 'previous'},
        {'text_input_action': 'join'},
        {'text_input_action': 'emergency_call'},
        {'text_input_action': 'Search'},
        {},
      ]);

      expect(editableWidget(tester, 0).textInputAction,
          cupertino ? isNull : TextInputAction.previous);
      expect(editableWidget(tester, 1).textInputAction,
          cupertino ? TextInputAction.join : isNull);
      expect(editableWidget(tester, 2).textInputAction,
          cupertino ? TextInputAction.emergencyCall : isNull);
      expect(editableWidget(tester, 3).textInputAction, TextInputAction.search);
      // No keyword keeps Flutter's platform default.
      expect(editableWidget(tester, 4).textInputAction, isNull);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('$platform multiline done submits instead of a newline',
        (tester) async {
      final backend = await pumpFields(tester, [
        {
          'value': 'Line one',
          'multiline': true,
          'text_input_action': 'done',
          'on_submit': true,
        },
        {
          'value': 'Notes',
          'multiline': true,
          'on_submit': true,
        },
      ]);

      expect(editableWidget(tester, 0).textInputAction, TextInputAction.done);
      expect(editableWidget(tester, 0).keyboardType, TextInputType.multiline);

      await tester.showKeyboard(editable(0));
      backend.events.clear();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.events, [(101, 'submit', 'Line one')]);
      expect(editableWidget(tester, 0).controller.text, 'Line one');
      expect(editableWidget(tester, 0).focusNode.hasFocus, isFalse);

      // Without text_input_action a multiline field keeps Return as newline
      // and never submits (unchanged behaviour).
      await tester.showKeyboard(editable(1));
      backend.events.clear();
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();
      expect(backend.events.where((event) => event.$2 == 'submit'), isEmpty);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('android previous moves focus to the preceding field',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final first = Control.fromMap(
        {'_c': 'TextField', '_i': 201, 'text_input_action': 'next'}, backend);
    final second = Control.fromMap({
      '_c': 'TextField',
      '_i': 202,
      'value': 'b',
      'text_input_action': 'previous',
      'on_submit': true,
    }, backend);
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: MaterialApp(
        home: Scaffold(
          body: Column(children: [
            ControlWidget(control: first),
            ControlWidget(control: second),
          ]),
        ),
      ),
    ));

    await tester.showKeyboard(find.byType(EditableText).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.previous);
    await tester.pumpAndSettle();

    final editables =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(editables[0].focusNode.hasFocus, isTrue);
    expect(editables[1].focusNode.hasFocus, isFalse);
    expect(backend.events, contains((202, 'submit', 'b')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
