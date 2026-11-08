import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/adaptive_list_section.dart';
import 'package:ruflet/src/controls/cupertino_list_tile.dart';
import 'package:ruflet/src/controls/list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;
import 'ruby_layout_attributes_test.dart' show backendFor, host;

Map<String, dynamic> _tile(int id, String title) => {
      '_c': 'ListTile',
      '_i': id,
      'title': {'_c': 'Text', '_i': id + 1, 'value': title},
    };

Map<String, dynamic> _section(Map<String, dynamic> props, {int rows = 2}) => {
      '_c': 'ListSection',
      '_i': 1,
      'controls': [
        for (var i = 0; i < rows; i++) _tile(10 + i * 10, 'Row ${i + 1}')
      ],
      ...props,
    };

Future<RufletBackend> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> map) async {
  final backend = backendFor(platform);
  final control = Control.fromMap(map, backend);
  await tester.pumpWidget(host(backend, ControlWidget(control: control)));
  return backend;
}

Finder _rows(TargetPlatform platform) =>
    find.byType(platform == TargetPlatform.iOS
        ? CupertinoListTileSkin
        : MaterialListTileSkin);

Finder get _card => find.byWidgetPredicate(
    (w) => w is material.Material && w.type == material.MaterialType.card);

void main() {
  group('iOS renders CupertinoListSection', () {
    const platform = TargetPlatform.iOS;

    testWidgets('inset grouped rows, header, footer and short separators',
        (tester) async {
      await _pump(tester, platform,
          _section({'header': 'Account', 'footer': 'Signed in'}));

      final section = tester
          .widget<CupertinoListSection>(find.byType(CupertinoListSection));
      expect(section.type, CupertinoListSectionType.insetGrouped);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Signed in'), findsOneWidget);

      final row1 = tester.getRect(_rows(platform).at(0));
      final row2 = tester.getRect(_rows(platform).at(1));
      // SDK _kDefaultInsetGroupedRowsMargin start/end: 20.
      expect(row1.left, 20);
      expect(row1.right, 800 - 20);
      // Row 2 starts right below row 1 and its hairline separator.
      expect(row2.top - row1.bottom, inInclusiveRange(0.0, 1.0));
      expect(row2.left, row1.left);
      // Header and footer sit above and below the rows.
      expect(tester.getRect(find.text('Account')).bottom,
          lessThanOrEqualTo(row1.top));
      expect(tester.getRect(find.text('Signed in')).top,
          greaterThanOrEqualTo(row2.bottom));

      // Rows are clipped to the SDK's rounded inset shape (radius 10).
      final shape = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<ShapeDecoration>()
          .single
          .shape as RoundedSuperellipseBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));
      expect(find.byType(ClipRSuperellipse), findsOneWidget);

      // One short separator between the rows. It starts under the titles of
      // Ruflet's iOS tiles (20 + 44 with leading), not at the SDK's notched
      // tile default (14 + 42).
      final separator = find.byWidgetPredicate((w) =>
          w is Container &&
          w.margin == const EdgeInsetsDirectional.only(start: 64));
      expect(separator, findsOneWidget);
      final line = tester.getRect(
          find.descendant(of: separator, matching: find.byType(ColoredBox)));
      expect(line.top, row1.bottom);
      expect(line.left, row1.left + 64);
      expect(line.right, row1.right);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('base variant is edge to edge with long top/bottom dividers',
        (tester) async {
      await _pump(tester, platform,
          _section({'variant': 'base', 'has_leading': false}));

      final section = tester
          .widget<CupertinoListSection>(find.byType(CupertinoListSection));
      expect(section.type, CupertinoListSectionType.base);
      final row1 = tester.getRect(_rows(platform).at(0));
      expect(row1.left, 0);
      expect(row1.width, 800);
      // SDK base topMargin 22 plus the long divider above the first row.
      expect(row1.top, inInclusiveRange(22.0, 23.0));
      // Two long dividers + one short divider inset by 20 + 0 (no leading),
      // which starts exactly under the row titles.
      final separator = find.byWidgetPredicate((w) =>
          w is Container &&
          w.margin == const EdgeInsetsDirectional.only(start: 20));
      expect(separator, findsOneWidget);
      expect(
          tester
              .getRect(find.descendant(
                  of: separator, matching: find.byType(ColoredBox)))
              .left,
          tester.getRect(find.text('Row 1')).left);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('margin is applied by the section, once', (tester) async {
      await _pump(
          tester,
          platform,
          _section({
            'margin': {'left': 40, 'top': 0, 'right': 40, 'bottom': 0}
          }));

      expect(tester.getRect(find.byType(AdaptiveListSectionControl)).left, 0);
      final row1 = tester.getRect(_rows(platform).at(0));
      expect(row1.left, 40);
      expect(row1.right, 800 - 40);
      expect(row1.top, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ruby colors, radius and divider margins reach the SDK',
        (tester) async {
      await _pump(
          tester,
          platform,
          _section({
            'bgcolor': '#102030',
            'rows_bgcolor': '#405060',
            'separator_color': '#708090',
            'border_radius': 16,
            'divider_margin': 10,
            'additional_divider_margin': 5,
            'top_margin': 12,
          }));

      final section = tester
          .widget<CupertinoListSection>(find.byType(CupertinoListSection));
      expect(section.backgroundColor, const Color(0xff102030));
      expect(section.separatorColor, const Color(0xff708090));
      expect(section.dividerMargin, 10);
      expect(section.additionalDividerMargin, 5);
      expect(section.decoration?.color, const Color(0xff405060));
      expect(section.decoration?.borderRadius, BorderRadius.circular(16));
      // The edge rows are clipped to the Ruby radius, not the SDK's 10.
      expect(section.clipBehavior, Clip.none);
      final clips = tester
          .widgetList<ClipRRect>(find.byType(ClipRRect))
          .map((clip) => clip.borderRadius)
          .toList();
      expect(clips, [
        const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        const BorderRadius.only(
            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ]);
      // top_margin adds grouped-background space above the inset section.
      expect(tester.getRect(_rows(platform).at(0)).top, 12 + 20);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header-only section renders; empty section reports an error',
        (tester) async {
      await _pump(tester, platform, _section({'header': 'Only'}, rows: 0));
      expect(find.byType(CupertinoListSection), findsOneWidget);
      expect(find.text('Only'), findsOneWidget);
      expect(find.byType(ErrorControl), findsNothing);

      await _pump(tester, platform, _section({}, rows: 0));
      expect(find.byType(CupertinoListSection), findsNothing);
      expect(find.byType(ErrorControl), findsOneWidget);
    });

    testWidgets('legacy CupertinoListSection wire name is an alias',
        (tester) async {
      await _pump(tester, platform, {
        ..._section({'header': 'Alias'}),
        '_c': 'CupertinoListSection'
      });
      expect(find.byType(CupertinoListSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Android renders a Material card section', () {
    const platform = TargetPlatform.android;

    testWidgets('inset card, header, footer and rows-1 dividers',
        (tester) async {
      await _pump(tester, platform,
          _section({'header': 'Account', 'footer': 'Signed in'}, rows: 3));

      expect(find.byType(CupertinoListSection), findsNothing);
      final card = tester.widget<material.Material>(_card);
      expect((card.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(12));
      expect(card.clipBehavior, Clip.antiAlias);
      final context = tester.element(_card);
      expect(card.color,
          material.Theme.of(context).colorScheme.surfaceContainerLow);

      final cardRect = tester.getRect(_card);
      expect(cardRect.left, 16);
      expect(cardRect.right, 800 - 16);
      final dividers = find.byType(material.Divider);
      expect(dividers, findsNWidgets(2));
      final divider = tester.widget<material.Divider>(dividers.first);
      expect(divider.indent, 72);
      expect(divider.height, 1);

      final row1 = tester.getRect(_rows(platform).at(0));
      final row2 = tester.getRect(_rows(platform).at(1));
      expect(row1.left, cardRect.left);
      expect(row1.width, cardRect.width);
      expect(row2.top - row1.bottom, 1);
      expect(tester.getRect(dividers.first).top, row1.bottom);

      final header = tester.getRect(find.text('Account'));
      expect(header.left, 16 + 16);
      expect(header.bottom, lessThanOrEqualTo(cardRect.top));
      expect(tester.getRect(find.text('Signed in')).top,
          greaterThanOrEqualTo(cardRect.bottom));
      final headerStyle = tester
          .widget<RichText>(find.descendant(
              of: find.text('Account'), matching: find.byType(RichText)))
          .text
          .style;
      expect(
          headerStyle?.color, material.Theme.of(context).colorScheme.primary);
      expect(
          find.byWidgetPredicate((w) =>
              w is CupertinoButton ||
              w is CupertinoTextField ||
              w is CupertinoListSection),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('base variant is a full-bleed square card', (tester) async {
      await _pump(tester, platform,
          _section({'variant': 'base', 'has_leading': false}));

      final card = tester.widget<material.Material>(_card);
      expect((card.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.zero);
      expect(card.clipBehavior, Clip.none);
      expect(tester.getRect(_card).left, 0);
      expect(tester.getRect(_card).width, 800);
      expect(
          tester.widget<material.Divider>(find.byType(material.Divider)).indent,
          16);
      // The divider line starts exactly under the row titles.
      final line = find.descendant(
          of: find.byType(material.Divider),
          matching: find.byType(DecoratedBox));
      expect(
          tester.getRect(line).left, tester.getRect(find.text('Row 1')).left);
      expect(tester.takeException(), isNull);
    });

    testWidgets('margin is applied by the section, once', (tester) async {
      await _pump(
          tester,
          platform,
          _section({
            'margin': {'left': 40, 'top': 0, 'right': 40, 'bottom': 0}
          }));

      expect(tester.getRect(find.byType(AdaptiveListSectionControl)).left, 0);
      final cardRect = tester.getRect(_card);
      expect(cardRect.left, 40);
      expect(cardRect.right, 800 - 40);
      expect(cardRect.top, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ruby colors, radius and divider margins reach the card',
        (tester) async {
      await _pump(
          tester,
          platform,
          _section({
            'bgcolor': '#102030',
            'rows_bgcolor': '#405060',
            'separator_color': '#708090',
            'border_radius': 16,
            'clip_behavior': 'hard_edge',
            'divider_margin': 10,
            'additional_divider_margin': 5,
            'top_margin': 12,
          }));

      final card = tester.widget<material.Material>(_card);
      expect(card.color, const Color(0xff405060));
      expect((card.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
      expect(card.clipBehavior, Clip.hardEdge);
      final divider =
          tester.widget<material.Divider>(find.byType(material.Divider));
      expect(divider.color, const Color(0xff708090));
      expect(divider.indent, 15);
      expect(
          tester
              .widgetList<ColoredBox>(find.byType(ColoredBox))
              .any((box) => box.color == const Color(0xff102030)),
          isTrue);
      expect(tester.getRect(_card).top, 8 + 12);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header-only section renders; empty section reports an error',
        (tester) async {
      await _pump(tester, platform, _section({'header': 'Only'}, rows: 0));
      expect(find.text('Only'), findsOneWidget);
      expect(_card, findsNothing);
      expect(find.byType(ErrorControl), findsNothing);

      await _pump(tester, platform, _section({}, rows: 0));
      expect(find.byType(ErrorControl), findsOneWidget);
    });
  });
}
