// Ruby's column, row, stack and responsive_row: spacing, alignment, sizing,
// wrapping and positioned children, measured on both designs.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';

// ruflet-coverage: Column Row Stack ResponsiveRow

var _ids = 100;

// What Ruflet::Control#to_patch adds for a row, column, view or form
// (children may `expand`) and for a stack (children may be positioned).
const _hostExpanded = {
  '_internals': {'host_expanded': true}
};
const _hostPositioned = {
  '_internals': {'host_positioned': true}
};

Map<String, dynamic> _box(String key, double width, double height,
        [Map<String, dynamic> extra = const {}]) =>
    {
      '_c': 'Container',
      '_i': ++_ids,
      'key': key,
      'width': width,
      'height': height,
      'bgcolor': '#336699',
      ...extra,
    };

/// A [width]x[height] Container whose content is [child].
Map<String, dynamic> _frame(Map<String, dynamic> child,
        {double width = 200, double height = 200}) =>
    {
      '_c': 'Container',
      '_i': 1,
      'key': 'frame',
      'width': width,
      'height': height,
      'content': child,
    };

/// A keyed control's rect relative to the frame. The Ruby key also lands on
/// the control's wrappers; the innermost match is the control itself.
Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<Object>(key)).last).shift(
        -tester.getTopLeft(find.byKey(const ValueKey<Object>('frame')).last));

/// The Stack the Ruby stack renders (the first one inside the frame).
Stack _stack(WidgetTester tester) => tester.widget<Stack>(find
    .descendant(
        of: find.byKey(const ValueKey<Object>('frame')).last,
        matching: find.byType(Stack))
    .first);

void main() {
  for (final design in HarnessDesign.values) {
    final name = design.name;

    group('$name Column', () {
      testWidgets('places children with spacing and both alignments',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Column',
              '_i': 2,
              ..._hostExpanded,
              'spacing': 8,
              'alignment': 'end',
              'horizontal_alignment': 'center',
              'controls': [_box('a', 50, 20), _box('b', 30, 20)],
            }));
        expect(tester.takeException(), isNull);
        expect(_rect(tester, 'a'), const Rect.fromLTWH(75, 152, 50, 20));
        expect(_rect(tester, 'b'), const Rect.fromLTWH(85, 180, 30, 20));
      });

      testWidgets('defaults to 10 spacing, top-start, filling the height',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Column',
              '_i': 2,
              ..._hostExpanded,
              'key': 'column',
              'controls': [_box('a', 50, 20), _box('b', 30, 20)],
            }));
        expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 50, 20));
        expect(_rect(tester, 'b'), const Rect.fromLTWH(0, 30, 30, 20));
        final column = tester.widget<Column>(find.byType(Column).last);
        expect(column.mainAxisSize, MainAxisSize.max);
        expect(column.spacing, 10);
      });

      testWidgets('space_between spreads children; tight shrinks to them',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Column',
              '_i': 2,
              ..._hostExpanded,
              'alignment': 'spaceBetween',
              'controls': [_box('a', 50, 20), _box('b', 30, 20)],
            }));
        expect(_rect(tester, 'b').top, 180);

        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Column',
              '_i': 2,
              ..._hostExpanded,
              'tight': true,
              'alignment': 'end',
              'controls': [_box('a', 50, 20), _box('b', 30, 20)],
            }));
        expect(tester.widget<Column>(find.byType(Column).last).mainAxisSize,
            MainAxisSize.min);
      });

      testWidgets('wrap flows children into a new run', (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Column',
              '_i': 2,
              ..._hostExpanded,
              'wrap': true,
              'spacing': 0,
              'run_spacing': 5,
              'controls': [
                _box('a', 40, 120),
                _box('b', 40, 120),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(Wrap), findsOneWidget);
        expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 40, 120));
        // 240 does not fit in 200: the second box starts a run to the right.
        expect(_rect(tester, 'b'), const Rect.fromLTWH(45, 0, 40, 120));
      });

      testWidgets(
          'scroll makes an overflowing column scroll, and on_scroll '
          'reaches Ruby', (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Column',
              '_i': 2,
              ..._hostExpanded,
              'scroll': 'auto',
              'on_scroll': true,
              'scroll_interval': 0,
              'controls': [
                for (var i = 0; i < 6; i++) _box('item$i', 50, 60),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsWidgets);
        await tester.drag(find.byKey(const ValueKey<Object>('item1')).last,
            const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(_rect(tester, 'item0').top, lessThan(0));
        expect(mount.backend.sent.where((m) => m.id == 2 && m.name == 'scroll'),
            isNotEmpty);
      });
    });

    group('$name Row', () {
      testWidgets('places children with spacing and both alignments',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Row',
              '_i': 2,
              ..._hostExpanded,
              'spacing': 6,
              'alignment': 'center',
              'vertical_alignment': 'end',
              'controls': [_box('a', 40, 30), _box('b', 60, 10)],
            }));
        expect(tester.takeException(), isNull);
        // 40 + 6 + 60 = 106 wide, centered in 200: starts at 47.
        expect(_rect(tester, 'a'), const Rect.fromLTWH(47, 170, 40, 30));
        expect(_rect(tester, 'b'), const Rect.fromLTWH(93, 190, 60, 10));
      });

      testWidgets('defaults to 10 spacing, start, vertically centered',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Row',
              '_i': 2,
              ..._hostExpanded,
              'controls': [_box('a', 40, 30), _box('b', 60, 10)],
            }));
        expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 85, 40, 30));
        expect(_rect(tester, 'b'), const Rect.fromLTWH(50, 95, 60, 10));
      });

      testWidgets('an expand child takes the remaining width', (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Row',
              '_i': 2,
              ..._hostExpanded,
              'spacing': 0,
              'controls': [
                _box('a', 40, 30),
                {
                  '_c': 'Container',
                  '_i': 3,
                  'key': 'grow',
                  'height': 30,
                  'expand': true,
                },
              ],
            }));
        expect(_rect(tester, 'grow'), const Rect.fromLTWH(40, 85, 160, 30));
      });

      testWidgets('wrap moves an overflowing child to the next run',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Row',
              '_i': 2,
              ..._hostExpanded,
              'wrap': true,
              'spacing': 4,
              'run_spacing': 6,
              'controls': [
                _box('a', 120, 20),
                _box('b', 120, 20),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 120, 20));
        expect(_rect(tester, 'b'), const Rect.fromLTWH(0, 26, 120, 20));
      });
    });

    group('$name Stack', () {
      testWidgets('aligns children and positions left/top/right/bottom ones',
          (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Stack',
              '_i': 2,
              ..._hostPositioned,
              'key': 'stack',
              'width': 200,
              'height': 200,
              'alignment': {'x': 1, 'y': 1},
              'controls': [
                _box('aligned', 50, 40),
                _box('pinned', 30, 20, {'left': 10, 'top': 15}),
                _box('far', 20, 20, {'right': 5, 'bottom': 5}),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(_rect(tester, 'aligned'), const Rect.fromLTWH(150, 160, 50, 40));
        expect(_rect(tester, 'pinned'), const Rect.fromLTWH(10, 15, 30, 20));
        expect(_rect(tester, 'far'), const Rect.fromLTWH(175, 175, 20, 20));
      });

      testWidgets(
          'fit expand stretches unpositioned children; clip_behavior '
          'and the hard-edge default reach the Stack', (tester) async {
        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Stack',
              '_i': 2,
              ..._hostPositioned,
              'fit': 'expand',
              'clip_behavior': 'none',
              'controls': [
                {'_c': 'Container', '_i': 3, 'key': 'fill'},
              ],
            }));
        expect(_rect(tester, 'fill'), const Rect.fromLTWH(0, 0, 200, 200));
        final stack = _stack(tester);
        expect(stack.fit, StackFit.expand);
        expect(stack.clipBehavior, Clip.none);

        await mountWire(
            tester,
            design,
            _frame({
              '_c': 'Stack',
              '_i': 2,
              ..._hostPositioned,
              'controls': [_box('a', 10, 10)],
            }));
        final plain = _stack(tester);
        expect(plain.fit, StackFit.loose);
        expect(plain.clipBehavior, Clip.hardEdge);
        expect(plain.alignment, AlignmentDirectional.topStart);
      });
    });

    group('$name ResponsiveRow', () {
      Map<String, dynamic> row(Map<String, dynamic> props) => _frame({
            '_c': 'ResponsiveRow',
            '_i': 2,
            ...props,
          }, width: 400, height: 300);
      Map<String, dynamic> cell(String key, Object col, [double height = 20]) =>
          {
            '_c': 'Container',
            '_i': ++_ids,
            'key': key,
            'height': height,
            'col': col,
          };

      testWidgets('col sizes each child in twelfths of the row, less spacing',
          (tester) async {
        await mountWire(
            tester,
            design,
            row({
              'controls': [
                cell('half', 6),
                cell('quarter', 3),
                cell('rest', 3),
              ],
            }));
        expect(tester.takeException(), isNull);
        // (400 - 11 * 10) / 12 per column, plus the spacing it spans.
        const column = 290 / 12;
        expect(_rect(tester, 'half').width, closeTo(column * 6 + 50, 0.01));
        expect(_rect(tester, 'quarter').width, closeTo(column * 3 + 20, 0.01));
        expect(_rect(tester, 'rest').right, closeTo(400, 0.3));
        expect(_rect(tester, 'quarter').left,
            closeTo(_rect(tester, 'half').right + 10, 0.11));
      });

      testWidgets('spacing 0 packs the columns edge to edge', (tester) async {
        // The row shaved 0.1 off the spacing, so 0 became a negative Flex
        // spacing: an assertion in debug builds, an overlap in release.
        await mountWire(
            tester,
            design,
            row({
              'spacing': 0,
              'controls': [
                cell('half', 6),
                cell('quarter', 3),
                cell('rest', 3),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsNothing);
        expect(_rect(tester, 'half'), const Rect.fromLTWH(0, 0, 200, 20));
        expect(_rect(tester, 'quarter'), const Rect.fromLTWH(200, 0, 100, 20));
        expect(_rect(tester, 'rest'), const Rect.fromLTWH(300, 0, 100, 20));

        // Wrapped runs too: two halves share the first run edge to edge (a
        // -0.1 Wrap spacing slid the second one 0.1 over the first) and the
        // third starts the next run.
        await mountWire(
            tester,
            design,
            row({
              'spacing': 0,
              'run_spacing': 0,
              'controls': [cell('a', 6), cell('b', 6), cell('c', 6)],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(Wrap), findsOneWidget);
        expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 200, 20));
        expect(_rect(tester, 'b'), const Rect.fromLTWH(200, 0, 200, 20));
        expect(_rect(tester, 'c'), const Rect.fromLTWH(0, 20, 200, 20));
      });

      testWidgets('spacing under 0.1 never becomes a negative gap',
          (tester) async {
        // 0.05 - 0.1 was a negative gap too: the Row's flex.dart assertion in
        // debug builds, a 0.05 overlap in release.
        await mountWire(
            tester,
            design,
            row({
              'spacing': 0.05,
              'controls': [
                cell('half', 6),
                cell('quarter', 3),
                cell('rest', 3),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsNothing);
        // (400 - 11 * 0.05) / 12 per column, plus the spacing it spans.
        const column = 399.45 / 12;
        expect(_rect(tester, 'half').width, closeTo(column * 6 + 0.25, 1e-6));
        expect(_rect(tester, 'quarter').left,
            closeTo(_rect(tester, 'half').right, 1e-6));
        expect(_rect(tester, 'rest').left,
            closeTo(_rect(tester, 'quarter').right, 1e-6));

        await mountWire(
            tester,
            design,
            row({
              'spacing': 0.05,
              'controls': [cell('a', 6), cell('b', 6), cell('c', 6)],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(Wrap), findsOneWidget);
        expect(_rect(tester, 'b').left, closeTo(column * 6 + 0.25, 1e-6));
        expect(_rect(tester, 'b').top, 0);
        expect(_rect(tester, 'c').top, 30);
      });

      testWidgets('negative spacing overlaps the columns like Flet',
          (tester) async {
        // Ruby sends a negative spacing as is. The child widths are sized for
        // it, so the gap keeps Flet's spacing - 0.1 and two halves still
        // share a run.
        await mountWire(
            tester,
            design,
            row({
              'spacing': -3,
              'controls': [cell('a', 6), cell('b', 6), cell('c', 6)],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(Wrap), findsOneWidget);
        // (400 + 11 * 3) / 12 per column, less the spacing it spans.
        const half = 433 / 12 * 6 - 15;
        expect(_rect(tester, 'a').left, 0);
        expect(_rect(tester, 'a').width, closeTo(half, 1e-6));
        expect(_rect(tester, 'b').left, closeTo(half - 3.1, 1e-6));
        expect(_rect(tester, 'b').top, 0);
        expect(_rect(tester, 'c').left, 0);
        expect(_rect(tester, 'c').top, 30);
      });

      testWidgets('columns and per-breakpoint col follow the page width',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            row({
              'columns': 4,
              'controls': [
                cell('a', {'xs': 4, 'md': 1}),
                cell('b', {'xs': 4, 'md': 3}),
              ],
            }));
        expect(tester.takeException(), isNull);
        // Before the first resize the page is 0 wide: "xs" applies.
        expect(_rect(tester, 'a').width, closeTo(400, 0.01));
        expect(_rect(tester, 'b').top, 30);
        // An 800-wide page selects "md" (>= 768).
        mount.backend.pageSize = const Size(800, 600);
        mount.backend.notifyListeners();
        await tester.pumpAndSettle();
        // (400 - 3 * 10) / 4 = 92.5 per column.
        expect(_rect(tester, 'a').width, closeTo(92.5, 0.01));
        expect(_rect(tester, 'b').width, closeTo(92.5 * 3 + 20, 0.01));
        expect(_rect(tester, 'b').left, closeTo(102.5, 0.11));
        expect(_rect(tester, 'b').top, 0);
      });

      testWidgets('custom breakpoints select run_spacing like the rest',
          (tester) async {
        // run_spacing was resolved against the page's default breakpoints,
        // so a Ruby-named breakpoint never matched and it stayed 10.
        final mount = await mountWire(
            tester,
            design,
            row({
              'breakpoints': {'narrow': 0, 'wide': 600},
              'spacing': {'narrow': 0, 'wide': 10},
              'run_spacing': {'narrow': 4, 'wide': 16},
              'controls': [cell('a', 8), cell('b', 8)],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsNothing);
        expect(_rect(tester, 'b').top, 24);

        mount.backend.pageSize = const Size(800, 600);
        mount.backend.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.byType(ErrorControl), findsNothing);
        expect(_rect(tester, 'b').top, 36);
      });

      testWidgets('children past the columns wrap into a run below',
          (tester) async {
        await mountWire(
            tester,
            design,
            row({
              'run_spacing': 8,
              'vertical_alignment': 'end',
              'controls': [
                cell('a', 8),
                cell('b', 8, 30),
              ],
            }));
        expect(tester.takeException(), isNull);
        expect(find.byType(Wrap), findsOneWidget);
        expect(_rect(tester, 'b').top, 28);
        expect(_rect(tester, 'b').left, 0);
      });
    });
  }
}
