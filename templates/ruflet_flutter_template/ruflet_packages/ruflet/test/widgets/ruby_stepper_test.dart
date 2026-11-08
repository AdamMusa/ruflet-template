import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <List<dynamic>>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://stepper-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    // Mirror the real backend: only subscribed events reach Ruby.
    if (control.get("on_$name") == true) events.add([name, data]);
  }
}

bool _materialOnly(Widget widget) =>
    widget is material.Material ||
    widget is material.Theme ||
    widget is material.InkResponse ||
    widget is material.ButtonStyleButton ||
    widget is material.Stepper;

Widget _host(RufletBackend backend, Widget child,
    {bool unboundedHeight = false}) {
  final body = unboundedHeight
      ? SingleChildScrollView(child: child)
      : Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 420, height: 560, child: child));
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

int _nextId = 100;
Map<String, dynamic> _text(String value) =>
    {'_c': 'Text', '_i': ++_nextId, 'value': value};
Map<String, dynamic> _step(String title, String body,
        [Map<String, dynamic> extra = const {}]) =>
    {
      '_c': 'Step',
      '_i': ++_nextId,
      'title': title,
      'content': _text(body),
      ...extra,
    };

Control _stepper(RufletBackend backend, Map<String, dynamic> props) =>
    Control.fromMap({
      '_c': 'Stepper',
      '_i': 1,
      'current_step': 0,
      'type': 'vertical',
      'steps': [
        _step('One', 'Body 1', {'is_active': true}),
        _step('Two', 'Body 2'),
        _step('Three', 'Body 3'),
      ],
      ...props,
    }, backend);

Future<Control> _pump(
    WidgetTester tester, _Backend backend, Map<String, dynamic> props,
    {bool unboundedHeight = false}) async {
  final control = _stepper(backend, props);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control),
      unboundedHeight: unboundedHeight));
  await tester.pumpAndSettle();
  return control;
}

Finder _button(String label, TargetPlatform platform) => find.ancestor(
    of: find.text(label).hitTestable(),
    matching: platform == TargetPlatform.iOS
        ? find.byType(CupertinoButton)
        : find.byWidgetPredicate((w) => w is material.ButtonStyleButton));

bool _enabled(WidgetTester tester, Finder button) {
  final widget = tester.widget(button);
  return widget is CupertinoButton
      ? widget.onPressed != null
      : (widget as material.ButtonStyleButton).onPressed != null;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final name = platform.name;

    testWidgets('$name: vertical Stepper shows only the current step content',
        (tester) async {
      final backend = _Backend(platform);
      final control = await _pump(tester, backend, {});

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      for (final title in ['One', 'Two', 'Three']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Body 1').hitTestable(), findsOneWidget);
      expect(find.text('Body 2').hitTestable(), findsNothing);
      expect(find.text('Body 3').hitTestable(), findsNothing);
      // Content sits below its own header and indented past the step icon.
      expect(tester.getTopLeft(find.text('Body 1')).dy,
          greaterThan(tester.getBottomLeft(find.text('One')).dy));
      expect(tester.getTopLeft(find.text('Two')).dy,
          greaterThan(tester.getBottomLeft(find.text('Body 1')).dy));
      expect(tester.getTopLeft(find.text('Body 1')).dx,
          greaterThanOrEqualTo(tester.getTopLeft(find.text('One')).dx));

      // Ruby moves the stepper; Dart never changes current_step itself.
      backend.updateControl(control.id, {'current_step': 1}, notify: true);
      await tester.pumpAndSettle();
      expect(find.text('Body 1').hitTestable(), findsNothing);
      expect(find.text('Body 2').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('Body 2')).dy,
          greaterThan(tester.getBottomLeft(find.text('Two')).dy));
      expect(tester.takeException(), isNull);
      if (platform == TargetPlatform.iOS) {
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      } else {
        expect(find.byType(material.Stepper), findsOneWidget);
        expect(find.byType(CupertinoButton), findsNothing);
      }
    });

    testWidgets('$name: tapping a step header fires step_tap with its index',
        (tester) async {
      final backend = _Backend(platform);
      final control = await _pump(tester, backend, {'on_step_tap': true});

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(backend.events, [
        ['step_tap', 1]
      ]);
      // Controlled: the tap alone does not move the stepper.
      expect(control.getInt('current_step'), 0);
      expect(find.text('Body 1').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Three'));
      await tester.pumpAndSettle();
      expect(backend.events.last, ['step_tap', 2]);
    });

    testWidgets('$name: taps are ignored without a handler or when disabled',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'on_step_tap': true,
        'steps': [
          _step('One', 'Body 1'),
          _step('Two', 'Body 2', {'state': 'disabled'}),
        ],
      });
      await tester.tap(find.text('Two'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(backend.events, isEmpty);

      final quiet = _Backend(platform);
      await _pump(tester, quiet, {});
      await tester.tap(find.text('Two'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(quiet.events, isEmpty);
    });

    testWidgets('$name: continue and cancel fire with the current step',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'current_step': 1,
        'continue_text': 'Next',
        'cancel_text': 'Back',
        'on_step_continue': true,
        'on_step_cancel': true,
      });

      expect(_button('Next', platform), findsOneWidget);
      expect(_button('Back', platform), findsOneWidget);
      expect(_enabled(tester, _button('Next', platform)), isTrue);
      expect(_enabled(tester, _button('Back', platform)), isTrue);
      // The controls belong to the current step: below its content.
      expect(tester.getTopLeft(find.text('Next').hitTestable()).dy,
          greaterThan(tester.getBottomLeft(find.text('Body 2')).dy));

      await tester.tap(find.text('Next').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back').hitTestable());
      await tester.pumpAndSettle();
      expect(backend.events, [
        ['step_continue', 1],
        ['step_cancel', 1],
      ]);
    });

    testWidgets('$name: buttons without handlers are disabled, default labels',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {'on_step_cancel': true});

      expect(_button('Continue', platform), findsOneWidget);
      expect(_button('Cancel', platform), findsOneWidget);
      expect(_enabled(tester, _button('Continue', platform)), isFalse);
      expect(_enabled(tester, _button('Cancel', platform)), isTrue);

      await tester.tap(find.text('Continue').hitTestable(),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(backend.events, isEmpty);
    });

    testWidgets('$name: show_controls false hides continue and cancel',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(
          tester, backend, {'show_controls': false, 'on_step_continue': true});
      expect(find.text('Continue', skipOffstage: false), findsNothing);
      expect(find.text('Cancel', skipOffstage: false), findsNothing);
      expect(find.text('Body 1').hitTestable(), findsOneWidget);
    });

    testWidgets('$name: step states render their glyphs', (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'steps': [
          _step('Done', 'Body 1', {'state': 'complete', 'is_active': true}),
          _step('Editing', 'Body 2', {'state': 'editing'}),
          _step('Broken', 'Body 3', {'state': 'error'}),
          _step('Fourth', 'Body 4'),
        ],
      });
      expect(tester.takeException(), isNull);
      if (platform == TargetPlatform.iOS) {
        expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.exclamationmark), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        // 24 px step circles, connector centred on them (x = 12).
        final circle = find.ancestor(
            of: find.text('4'), matching: find.byType(AnimatedContainer));
        expect(tester.getSize(circle), const Size(24, 24));
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      } else {
        expect(find.byIcon(material.Icons.check), findsOneWidget);
        expect(find.byIcon(material.Icons.edit), findsOneWidget);
        expect(find.text('!'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        final stepper =
            tester.widget<material.Stepper>(find.byType(material.Stepper));
        expect(stepper.steps.map((s) => s.state), [
          material.StepState.complete,
          material.StepState.editing,
          material.StepState.error,
          material.StepState.indexed,
        ]);
        expect(
            stepper.steps.map((s) => s.isActive), [true, false, false, false]);
      }
    });

    testWidgets('$name: subtitles render under titles', (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'steps': [
          _step('One', 'Body 1', {'subtitle': 'First things'}),
          _step('Two', 'Body 2', {'subtitle': _text('Second things')}),
        ],
      });
      expect(find.text('First things'), findsOneWidget);
      expect(find.text('Second things'), findsOneWidget);
      expect(tester.getTopLeft(find.text('First things')).dy,
          greaterThan(tester.getTopLeft(find.text('One')).dy));
    });

    testWidgets('$name: horizontal Stepper needs a bounded height',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {'type': 'horizontal'},
          unboundedHeight: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.textContaining('bounded height'), findsOneWidget);
    });

    testWidgets('$name: bounded horizontal Stepper puts content below header',
        (tester) async {
      final backend = _Backend(platform);
      final control = await _pump(tester, backend, {
        'type': 'horizontal',
        'on_step_tap': true,
        'on_step_continue': true,
      });
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      final titleY = tester.getTopLeft(find.text('One')).dy;
      expect(tester.getTopLeft(find.text('Two')).dy, titleY);
      expect(tester.getTopLeft(find.text('Three')).dy, titleY);
      expect(tester.getTopLeft(find.text('Two')).dx,
          greaterThan(tester.getTopRight(find.text('One')).dx));
      expect(find.text('Body 1').hitTestable(), findsOneWidget);
      expect(find.text('Body 2').hitTestable(), findsNothing);
      expect(tester.getTopLeft(find.text('Body 1')).dy,
          greaterThan(tester.getBottomLeft(find.text('One')).dy));

      await tester.tap(find.text('Three'));
      await tester.tap(find.text('Continue').hitTestable());
      await tester.pumpAndSettle();
      expect(backend.events, [
        ['step_tap', 2],
        ['step_continue', 0],
      ]);

      backend.updateControl(control.id, {'current_step': 2}, notify: true);
      await tester.pumpAndSettle();
      expect(find.text('Body 3').hitTestable(), findsOneWidget);
      expect(find.text('Body 1').hitTestable(), findsNothing);
      if (platform == TargetPlatform.iOS) {
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      }
    });

    testWidgets('$name: horizontal Stepper renders step labels',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'type': 'horizontal',
        'steps': [
          _step('One', 'Body 1', {'label': 'First'}),
          _step('Two', 'Body 2', {'label': _text('Second')}),
        ],
      });
      expect(tester.takeException(), isNull);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    if (platform == TargetPlatform.iOS) {
      testWidgets('iOS: horizontal header fits many long titles',
          (tester) async {
        final backend = _Backend(platform);
        await _pump(tester, backend, {
          'type': 'horizontal',
          'steps': [
            for (var i = 0; i < 6; i++)
              _step('A rather long step title $i', 'Body $i',
                  {'subtitle': 'and a subtitle that keeps going $i'}),
          ],
        });
        // Equal-width columns with ellipsised titles: no RenderFlex overflow.
        expect(tester.takeException(), isNull);
        final first = tester.getRect(find.text('A rather long step title 0'));
        final last = tester.getRect(find.text('A rather long step title 5'));
        expect(last.right, lessThanOrEqualTo(420));
        expect(first.left, greaterThanOrEqualTo(0));
      });
    }

    testWidgets('$name: connector color and thickness are honoured',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'connector_color': '#ff0000',
        'connector_thickness': 3,
        'elevation': 4,
        'clip_behavior': 'hardEdge',
      });
      if (platform == TargetPlatform.iOS) {
        final lines = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where((box) => box.color == const Color(0xffff0000));
        expect(lines, isNotEmpty);
        final line = find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xffff0000));
        expect(tester.getSize(line.first).width, 3);
      } else {
        final stepper =
            tester.widget<material.Stepper>(find.byType(material.Stepper));
        expect(stepper.connectorThickness, 3);
        expect(stepper.elevation, 4);
        expect(stepper.clipBehavior, Clip.hardEdge);
        expect(stepper.connectorColor!.resolve({WidgetState.selected}),
            const Color(0xffff0000));
      }
    });

    testWidgets('$name: current_step is clamped and the step list may grow',
        (tester) async {
      final backend = _Backend(platform);
      final control = await _pump(tester, backend, {'current_step': 9});
      expect(tester.takeException(), isNull);
      expect(find.text('Body 3').hitTestable(), findsOneWidget);

      backend.updateControl(
          control.id,
          {
            'steps': [
              _step('One', 'Body 1'),
              _step('Two', 'Body 2'),
              _step('Three', 'Body 3'),
              _step('Four', 'Body 4'),
            ],
            'current_step': 3,
          },
          notify: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Four'), findsOneWidget);
      expect(find.text('Body 4').hitTestable(), findsOneWidget);
    });

    testWidgets('$name: steps may come from block children (controls)',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'Stepper',
        '_i': 1,
        'current_step': 0,
        'controls': [_step('One', 'Body 1'), _step('Two', 'Body 2')],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorControl), findsNothing);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Body 1').hitTestable(), findsOneWidget);
    });

    testWidgets('$name: empty or non-Step children render an ErrorControl',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {'steps': <dynamic>[]});
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsOneWidget);

      await _pump(tester, _Backend(platform), {
        'steps': [_text('Not a step')]
      });
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.textContaining('stepper_step', findRichText: true),
          findsOneWidget);
    });
  }
}
