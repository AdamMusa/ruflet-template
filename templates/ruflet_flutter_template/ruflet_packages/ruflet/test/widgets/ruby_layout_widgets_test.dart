// Ruby's fractionally_sized_box, intrinsic_height, intrinsic_width,
// ignore_pointer, absorb_pointer and sliver_padding: geometry and pointer
// behaviour on both designs.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _box(String key, double width, double height) => {
      '_c': 'Container',
      '_i': key.hashCode & 0xffff,
      'key': key,
      'width': width,
      'height': height,
      'bgcolor': '#336699',
    };

/// A Ruby key also lands on the wrappers around the control (its
/// ControlWidget, or the SliverToBoxAdapter of a box among slivers); the
/// innermost match is the control itself.
Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<Object>(key)).last);

/// A 400x200 Container whose content is [child].
Map<String, dynamic> _frame(Map<String, dynamic> child) => {
      '_c': 'Container',
      '_i': 1,
      'width': 400,
      'height': 200,
      'content': child,
    };

List<String> _clicks(HarnessMount mount) => [
      for (final m in mount.backend.sent)
        if (m.props == null && m.name == 'click') '${m.id}',
    ];

void main() {
  for (final design in HarnessDesign.values) {
    final name = design.name;

    group('$name FractionallySizedBox', () {
      testWidgets('sizes its content to a fraction of the space',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'FractionallySizedBox',
              '_i': 2,
              'width_factor': 0.5,
              'height_factor': 0.25,
              'alignment': {'x': -1, 'y': -1},
              'content': {'_c': 'Container', '_i': 3, 'key': 'inner'},
            }));
        expect(tester.takeException(), isNull);
        final frame = tester.getTopLeft(find.byType(FractionallySizedBox));
        final inner = _rect(tester, 'inner').shift(-frame);
        expect(inner, const Rect.fromLTWH(0, 0, 200, 50));
      });

      testWidgets(
          'a missing or negative factor leaves that axis to the content',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'FractionallySizedBox',
              '_i': 2,
              'width_factor': -1,
              'height_factor': 0.5,
              'content': {'_c': 'Container', '_i': 3, 'key': 'inner'},
            }));
        final box = tester
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
        expect(box.widthFactor, isNull);
        expect(box.heightFactor, 0.5);
        expect(box.alignment, Alignment.center);
      });

      testWidgets('reports an unbounded axis instead of failing layout',
          (tester) async {
        // A Column does not bound its children's height.
        await mountWire(tester, design, {
          '_c': 'Column',
          '_i': 1,
          'controls': [
            {
              '_c': 'FractionallySizedBox',
              '_i': 2,
              'height_factor': 0.5,
              'content': {'_c': 'Text', '_i': 3, 'value': 'half'},
            }
          ],
        });
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsOneWidget);
        expect(find.textContaining('height is unbounded'), findsOneWidget);
      });
    });

    group('$name IntrinsicHeight and IntrinsicWidth', () {
      testWidgets('a stretched Row takes its tallest child\'s height',
          (tester) async {
        await mountWire(tester, design, {
          '_c': 'Column',
          '_i': 1,
          'controls': [
            {
              '_c': 'IntrinsicHeight',
              '_i': 2,
              'content': {
                '_c': 'Row',
                '_i': 3,
                'vertical_alignment': 'stretch',
                'controls': [
                  {
                    '_c': 'Container',
                    '_i': 4,
                    'key': 'short',
                    'width': 50,
                    'height': 40
                  },
                  {
                    '_c': 'Container',
                    '_i': 5,
                    'key': 'tall',
                    'width': 50,
                    'height': 90
                  },
                  {'_c': 'Container', '_i': 6, 'key': 'free', 'width': 50},
                ],
              },
            }
          ],
        });
        expect(tester.takeException(), isNull);
        expect(_rect(tester, 'tall').height, 90);
        // A child without a height stretches to the row's intrinsic height.
        expect(_rect(tester, 'free').height, 90);
      });

      testWidgets('a stretched Column takes its widest child\'s width',
          (tester) async {
        await mountWire(tester, design, {
          '_c': 'Row',
          '_i': 1,
          'controls': [
            {
              '_c': 'IntrinsicWidth',
              '_i': 2,
              'step_width': 25,
              'content': {
                '_c': 'Column',
                '_i': 3,
                'horizontal_alignment': 'stretch',
                'controls': [
                  {
                    '_c': 'Container',
                    '_i': 4,
                    'key': 'narrow',
                    'width': 40,
                    'height': 20
                  },
                  {
                    '_c': 'Container',
                    '_i': 5,
                    'key': 'wide',
                    'width': 110,
                    'height': 20
                  },
                  {'_c': 'Container', '_i': 6, 'key': 'free', 'height': 20},
                ],
              },
            }
          ],
        });
        expect(tester.takeException(), isNull);
        // 110 rounded up to a multiple of step_width (25).
        expect(_rect(tester, 'free').width, 125);
        expect(
            tester
                .widget<IntrinsicWidth>(find.byType(IntrinsicWidth))
                .stepWidth,
            25);
      });
    });

    group('$name IgnorePointer and AbsorbPointer', () {
      Map<String, dynamic> stack(Map<String, dynamic> overlay) => {
            '_c': 'Stack',
            '_i': 1,
            'width': 300,
            'height': 120,
            'controls': [
              {
                '_c': 'GestureDetector',
                '_i': 10,
                'on_tap': true,
                'content': {
                  '_c': 'Container',
                  '_i': 11,
                  'width': 300,
                  'height': 120
                },
              },
              overlay,
            ],
          };
      Map<String, dynamic> button(int id) => {
            '_c': 'Button',
            '_i': id,
            'content': 'Press',
            'on_click': true,
          };
      List<String> taps(HarnessMount mount) => [
            for (final m in mount.backend.sent)
              if (m.props == null) '${m.id}:${m.name}',
          ];

      testWidgets('ignoring lets a tap through to what lies behind',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            stack({
              '_c': 'IgnorePointer',
              '_i': 20,
              'ignoring': true,
              'content': button(21),
            }));
        await tester.tap(find.text('Press'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(_clicks(mount), isEmpty);
        expect(taps(mount), contains('10:tap'));
      });

      testWidgets('ignoring: false delivers the tap to the content',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            stack({
              '_c': 'IgnorePointer',
              '_i': 20,
              'ignoring': false,
              'content': button(21),
            }));
        await tester.tap(find.text('Press'));
        await tester.pumpAndSettle();
        expect(_clicks(mount), ['21']);
      });

      testWidgets('absorbing stops the tap for the content and what is behind',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            stack({
              '_c': 'AbsorbPointer',
              '_i': 20,
              'content': button(21),
            }));
        await tester.tap(find.text('Press'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(taps(mount), isEmpty);
      });

      testWidgets('a Ruby patch turns absorbing off', (tester) async {
        final mount = await mountWire(
            tester,
            design,
            stack({
              '_c': 'AbsorbPointer',
              '_i': 20,
              'absorbing': true,
              'content': button(21),
            }));
        mount.control(20).update({'absorbing': false}, shouldNotify: true);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Press'));
        await tester.pumpAndSettle();
        expect(_clicks(mount), ['21']);
      });
    });

    group('$name SliverPadding', () {
      testWidgets('insets every sliver it groups', (tester) async {
        await mountWire(tester, design, {
          '_c': 'CustomScrollView',
          '_i': 1,
          'width': 400,
          'height': 400,
          'controls': [
            {
              '_c': 'SliverPadding',
              '_i': 2,
              'padding': {'left': 20, 'top': 30, 'right': 10, 'bottom': 0},
              'controls': [
                {
                  '_c': 'SliverList',
                  '_i': 3,
                  'controls': [_box('first', 50, 40)],
                },
                _box('box', 50, 20),
              ],
            },
            _box('after', 50, 10),
          ],
        });
        expect(tester.takeException(), isNull);
        final origin = tester.getTopLeft(find.byType(CustomScrollView));
        expect(_rect(tester, 'first').topLeft - origin, const Offset(20, 30));
        // The list item fills the padded cross axis: 400 - 20 - 10.
        expect(_rect(tester, 'first').width, 370);
        // A box among the slivers scrolls as a box inside the padding.
        expect(_rect(tester, 'box').topLeft - origin, const Offset(20, 70));
        // The next CustomScrollView entry starts after the padded group.
        expect(_rect(tester, 'after').top - origin.dy, 90);
      });

      testWidgets('reads `slivers:` as well as block children', (tester) async {
        await mountWire(tester, design, {
          '_c': 'CustomScrollView',
          '_i': 1,
          'width': 400,
          'height': 400,
          'slivers': [
            {
              '_c': 'SliverPadding',
              '_i': 2,
              'padding': 16,
              'slivers': [
                {
                  '_c': 'SliverList',
                  '_i': 3,
                  'controls': [_box('item', 50, 40)],
                },
              ],
            },
          ],
        });
        final origin = tester.getTopLeft(find.byType(CustomScrollView));
        expect(_rect(tester, 'item').topLeft - origin, const Offset(16, 16));
      });
    });
  }
}
