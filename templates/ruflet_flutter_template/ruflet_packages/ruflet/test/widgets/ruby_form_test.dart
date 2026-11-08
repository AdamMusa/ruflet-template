// Ruby's `form`: a Column-like layout of its fields inside a
// FocusTraversalGroup, on both designs. Validation runs in Ruby; the client
// shows the error props Ruby patches and sends the events Ruby asked for.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/src/controls/form.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _box(int id, String key, double height,
        [Map<String, dynamic> props = const {}]) =>
    {
      '_c': 'Container',
      '_i': id,
      'key': key,
      'width': 100,
      'height': height,
      'bgcolor': '#336699',
      ...props,
    };

Map<String, dynamic> _field(int id, String key,
        [Map<String, dynamic> props = const {}]) =>
    {
      '_c': 'TextField',
      '_i': id,
      'key': key,
      'label': key,
      'width': 200,
      ...props,
    };

/// A Ruby key also lands on the ControlWidget around the control; the
/// innermost match is the control itself.
Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<Object>(key)).last);

/// The FocusTraversalGroup the form renders (the app has its own above it).
final _formGroup = find.descendant(
    of: find.byType(FormControl), matching: find.byType(FocusTraversalGroup));

EditableText _editable(WidgetTester tester, String key) =>
    tester.widget<EditableText>(find.descendant(
        of: find.byKey(ValueKey<Object>(key)).first,
        matching: find.byType(EditableText)));

/// The Ruby keys of the fields, in the order Tab focuses them from [first].
Future<List<String>> _tabOrder(
    WidgetTester tester, List<String> keys, String first) async {
  await tester.tap(find.descendant(
      of: find.byKey(ValueKey<Object>(first)).first,
      matching: find.byType(EditableText)));
  await tester.pump();
  final order = <String>[];
  for (var i = 0; i < keys.length; i++) {
    order.add(keys.firstWhere((k) => _editable(tester, k).focusNode.hasFocus));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  return order;
}

void main() {
  for (final design in HarnessDesign.values) {
    final name = design.name;

    group('$name Form layout', () {
      testWidgets('lays out its controls like a Column', (tester) async {
        await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'width': 300,
          'spacing': 20,
          'horizontal_alignment': 'center',
          'controls': [_box(2, 'a', 50), _box(3, 'b', 30)],
        });
        expect(tester.takeException(), isNull);
        final origin = tester.getTopLeft(find.byType(FormControl));
        expect(_rect(tester, 'a').shift(-origin),
            const Rect.fromLTWH(100, 0, 100, 50));
        expect(_rect(tester, 'b').shift(-origin),
            const Rect.fromLTWH(100, 70, 100, 30));
        expect(_formGroup, findsOneWidget);
        expect(
            find.descendant(
                of: _formGroup,
                matching: find.byKey(const ValueKey<Object>('b'))),
            findsWidgets);
      });

      testWidgets('an expanded control takes the remaining height',
          (tester) async {
        // Ruby marks Form as a host of expanded children, like Column.
        await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'height': 300,
          'spacing': 10,
          '_internals': {'host_expanded': true},
          'controls': [
            _box(2, 'top', 50),
            {
              '_c': 'Container',
              '_i': 3,
              'key': 'rest',
              'width': 100,
              'expand': true,
              'bgcolor': '#336699',
            },
          ],
        });
        expect(tester.takeException(), isNull);
        expect(_rect(tester, 'rest').height, 240);
      });

      testWidgets('scrolls a form taller than its height', (tester) async {
        await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'height': 200,
          'scroll': 'auto',
          'controls': [
            for (var i = 0; i < 6; i++) _box(10 + i, 'box$i', 80),
          ],
        });
        expect(tester.takeException(), isNull);
        expect(
            find.descendant(
                of: find.byType(FormControl),
                matching: find.byType(SingleChildScrollView)),
            findsOneWidget);
      });

      testWidgets('the layout keywords apply around the form',
          (tester) async {
        await mountWire(tester, design, {
          '_c': 'Column',
          '_i': 1,
          'controls': [
            {
              '_c': 'Form',
              '_i': 2,
              'key': 'form',
              'margin': 16,
              'opacity': 0.5,
              'controls': [_box(3, 'a', 40)],
            },
          ],
        });
        expect(tester.takeException(), isNull);
        final origin = tester.getTopLeft(find.byType(Column).first);
        expect(_rect(tester, 'a').topLeft - origin, const Offset(16, 16));
        // LayoutControl stays outermost: the opacity wraps the group.
        expect(
            tester
                .widgetList<Opacity>(find.ancestor(
                    of: _formGroup, matching: find.byType(Opacity)))
                .map((o) => o.opacity),
            contains(0.5));
      });
    });

    group('$name Form focus traversal', () {
      testWidgets('Tab moves through the fields in order', (tester) async {
        await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'controls': [_field(2, 'a'), _field(3, 'b'), _field(4, 'c')],
        });
        expect(await _tabOrder(tester, ['a', 'b', 'c'], 'a'), ['a', 'b', 'c']);
      });

      testWidgets('Tab finishes the form before the fields beside it',
          (tester) async {
        // Reading order alone would go a, c, b, d (row by row).
        await mountWire(tester, design, {
          '_c': 'Row',
          '_i': 1,
          'vertical_alignment': 'start',
          'controls': [
            {
              '_c': 'Form',
              '_i': 2,
              'width': 250,
              'spacing': 10,
              'controls': [_field(3, 'a'), _field(4, 'b')],
            },
            {
              '_c': 'Column',
              '_i': 5,
              'width': 250,
              'spacing': 10,
              'controls': [_field(6, 'c'), _field(7, 'd')],
            },
          ],
        });
        expect(_rect(tester, 'a').top, _rect(tester, 'c').top);
        expect(await _tabOrder(tester, ['a', 'b', 'c', 'd'], 'a'),
            ['a', 'b', 'c', 'd']);
      });

      testWidgets('leaving a field by Tab sends the blur Ruby asked for',
          (tester) async {
        // on_unfocus: the Ruby form sets on_blur on its fields.
        final mount = await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'controls': [
            _field(2, 'a', {'on_blur': true}),
            _field(3, 'b'),
          ],
        });
        await _tabOrder(tester, ['a', 'b'], 'a');
        expect(
            [
              for (final m in mount.backend.sent)
                if (m.props == null) '${m.id}:${m.name}'
            ],
            ['2:blur']);
      });
    });

    group('$name Form fields', () {
      testWidgets('Enter in a field sends the submit Ruby routes to on_submit',
          (tester) async {
        // The Ruby form sets on_submit on its text fields when the form has
        // an on_submit handler, and routes the field's submit to it.
        final mount = await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'on_submit': true,
          'controls': [
            _field(2, 'email', {'value': 'ada@example.com', 'on_submit': true}),
          ],
        });
        await tester.showKeyboard(find.byType(EditableText));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        final events = [
          for (final m in mount.backend.sent)
            if (m.props == null) (m.id, m.name, m.data)
        ];
        expect(events, [(2, 'submit', 'ada@example.com')]);
      });

      testWidgets('shows the error a Ruby validation patches onto a field',
          (tester) async {
        final mount = await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'controls': [_field(2, 'email')],
        });
        expect(find.text('Required'), findsNothing);

        mount.control(2).update({'error': 'Required'}, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsOneWidget);

        mount.control(2).update({'error': null}, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsNothing);
      });

      testWidgets('a Ruby reset puts the typed text back', (tester) async {
        final mount = await mountWire(tester, design, {
          '_c': 'Form',
          '_i': 1,
          'controls': [_field(2, 'name', {'value': 'Ada'})],
        });
        await tester.enterText(find.byType(EditableText), 'Grace');
        await tester.pump();
        expect(_editable(tester, 'name').controller.text, 'Grace');

        mount.control(2).update({'value': 'Ada'}, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(_editable(tester, 'name').controller.text, 'Ada');
      });
    });
  }
}
