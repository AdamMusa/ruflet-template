import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _Backend(TargetPlatform targetPlatform)
      : super(
            pageUri: Uri.parse('ruflet://control-methods-test'),
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

const _timeout = Duration(seconds: 5);

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final cupertino = platform == TargetPlatform.iOS;

    Future<_Backend> pump(WidgetTester tester, _Backend backend,
        List<Map<String, dynamic>> nodes) async {
      final controls = [
        for (final node in nodes) Control.fromMap(node, backend),
      ];
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

    /// Invokes [name] like Page#invoke does and pumps until the (possibly
    /// animated) handler completes.
    Future<dynamic> invoke(WidgetTester tester, Control control, String name,
        [dynamic args]) async {
      final result = control.invokeMethod(name, args, _timeout);
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('$platform TextField focus and blur methods move focus',
        (tester) async {
      final backend = _Backend(platform);
      await pump(tester, backend, [
        {
          '_c': 'TextField',
          '_i': 11,
          'value': 'email',
          'on_focus': true,
          'on_blur': true,
        },
        {
          '_c': 'TextField',
          '_i': 12,
          'value': 'notes',
          'shift_enter': true,
          'on_focus': true,
          'on_blur': true,
        },
      ]);
      final field = backend.controlsIndex.get(11)!;
      final shiftEnterField = backend.controlsIndex.get(12)!;
      EditableText editable(int index) =>
          tester.widget<EditableText>(find.byType(EditableText).at(index));

      expect(find.byType(cupertino ? CupertinoTextField : TextField),
          findsNWidgets(2));
      expect(editable(0).focusNode.hasFocus, isFalse);

      await invoke(tester, field, 'focus', const {});
      expect(editable(0).focusNode.hasFocus, isTrue);

      await invoke(tester, field, 'blur', const {});
      expect(editable(0).focusNode.hasFocus, isFalse);
      expect(backend.events, [(11, 'focus', null), (11, 'blur', null)]);

      // A nil args payload (Page#invoke without args) is tolerated.
      await invoke(tester, field, 'focus');
      expect(editable(0).focusNode.hasFocus, isTrue);
      await invoke(tester, field, 'blur');
      expect(editable(0).focusNode.hasFocus, isFalse);

      // shift_enter fields render with their own focus node.
      backend.events.clear();
      await invoke(tester, shiftEnterField, 'focus', const {});
      expect(editable(1).focusNode.hasFocus, isTrue);
      await invoke(tester, shiftEnterField, 'blur', const {});
      expect(editable(1).focusNode.hasFocus, isFalse);
      expect(backend.events, [(12, 'focus', null), (12, 'blur', null)]);

      await expectLater(
          field.invokeMethod('unknown', const {}, _timeout), throwsException);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform buttons and dropdowns take focus on invoke',
        (tester) async {
      final backend = _Backend(platform);
      final focusable = {
        81: {'_c': 'Button', 'content': 'Save'},
        82: {'_c': 'FilledButton', 'content': 'Send'},
        83: {'_c': 'IconButton', 'icon': 71571},
        // Material DropdownMenu is only focusable when editable.
        84: {
          '_c': 'Dropdown',
          'editable': true,
          'options': [
            {'_c': 'DropdownOption', '_i': 90, 'key': 'one', 'text': 'One'}
          ],
        },
      };
      await pump(tester, backend, [
        for (final entry in focusable.entries)
          {
            ...entry.value,
            '_i': entry.key,
            'on_focus': true,
          }
      ]);

      for (final id in focusable.keys) {
        await invoke(tester, backend.controlsIndex.get(id)!, 'focus', const {});
        expect(backend.events.last, (id, 'focus', null), reason: '$id');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform PageView methods turn pages and tolerate nil args',
        (tester) async {
      final backend = _Backend(platform);
      await pump(tester, backend, [
        {
          '_c': 'PageView',
          '_i': 21,
          'height': 200,
          'selected_index': 0,
          'animation_duration': 50,
          'on_change': true,
          'controls': [
            for (var i = 0; i < 4; i++)
              {'_c': 'Text', '_i': 30 + i, 'value': 'Page $i'}
          ],
        },
      ]);
      final pageView = backend.controlsIndex.get(21)!;
      double page() =>
          tester.widget<PageView>(find.byType(PageView)).controller!.page!;

      // Page#invoke sends "args" => nil when a method has no arguments.
      await invoke(tester, pageView, 'next_page');
      expect(page(), 1);
      expect(pageView.get('selected_index'), 1);

      await invoke(tester, pageView, 'go_to_page',
          {'index': 3, 'duration': 120, 'curve': 'easeInOut'});
      expect(page(), 3);
      expect(find.text('Page 3'), findsOneWidget);

      await invoke(tester, pageView, 'previous_page', null);
      expect(page(), 2);

      await invoke(tester, pageView, 'previous_page',
          {'duration': 10, 'curve': 'easeOut'});
      expect(page(), 1);

      await invoke(tester, pageView, 'jump_to_page', {'index': 0});
      expect(page(), 0);

      final width = tester.getSize(find.byType(PageView)).width;
      await invoke(tester, pageView, 'jump_to', {'value': width * 2});
      expect(page(), 2);

      // Missing index/value is a no-op rather than a crash.
      await invoke(tester, pageView, 'go_to_page');
      await invoke(tester, pageView, 'jump_to_page', const {});
      await invoke(tester, pageView, 'jump_to');
      expect(page(), 2);

      // Every landing page is reported (animations may skip intermediates).
      expect(backend.events.where((e) => e.$2 == 'change').map((e) => e.$3),
          containsAllInOrder([1, 3, 2, 1, 0, 2]));
      expect(backend.events.last, (21, 'change', 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform Tabs move_to selects tabs, negative from the end',
        (tester) async {
      final backend = _Backend(platform);
      await pump(tester, backend, [
        {
          '_c': 'Tabs',
          '_i': 41,
          'length': 3,
          'selected_index': 0,
          'on_change': true,
          'content': {
            '_c': 'Column',
            '_i': 42,
            'controls': [
              {
                '_c': 'TabBar',
                '_i': 43,
                'tabs': [
                  for (var i = 0; i < 3; i++)
                    {
                      '_c': 'Tab',
                      '_i': 50 + i,
                      'label': {'_c': 'Text', '_i': 60 + i, 'value': 'Tab $i'}
                    }
                ],
              },
              {
                '_c': 'TabBarView',
                '_i': 44,
                'height': 120,
                'controls': [
                  for (var i = 0; i < 3; i++)
                    {'_c': 'Text', '_i': 70 + i, 'value': 'Body $i'}
                ],
              },
            ],
          },
        },
      ]);
      final tabs = backend.controlsIndex.get(41)!;

      await invoke(tester, tabs, 'move_to',
          {'index': 2, 'duration': 50, 'curve': 'easeOut'});
      expect(tabs.get('selected_index'), 2);
      expect(find.text('Body 2'), findsOneWidget);

      await invoke(tester, tabs, 'move_to', {'index': 0});
      expect(tabs.get('selected_index'), 0);

      // Negative indexes count from the end on both designs.
      await invoke(tester, tabs, 'move_to', {'index': -2});
      expect(tabs.get('selected_index'), 1);
      expect(find.text('Body 1'), findsOneWidget);

      // Out-of-range indexes clamp instead of asserting.
      await invoke(tester, tabs, 'move_to', {'index': 9});
      expect(tabs.get('selected_index'), 2);

      expect(backend.events.where((e) => e.$2 == 'change').map((e) => e.$3),
          [2, 0, 1, 2]);
      expect(tester.takeException(), isNull);
    });
  }
}
