import 'dart:math' as math;

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/adaptive_form_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;
import 'ruby_layout_attributes_test.dart' show backendFor, host;

Map<String, dynamic> _row(Map<String, dynamic> props) => {
      '_c': 'FormRow',
      '_i': 1,
      'content': {'_c': 'Text', '_i': 2, 'value': 'Value'},
      ...props,
    };

Future<void> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> map) async {
  final backend = backendFor(platform);
  final control = Control.fromMap(map, backend);
  // Rows normally live in a full-width ListSection or Column.
  await tester.pumpWidget(host(
      backend, SizedBox(width: 800, child: ControlWidget(control: control))));
}

Color? _textColor(WidgetTester tester, String text) => tester
    .widget<RichText>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)))
    .text
    .style
    ?.color;

void main() {
  group('iOS renders CupertinoFormRow', () {
    const platform = TargetPlatform.iOS;

    testWidgets('prefix label, trailing content, helper and red error',
        (tester) async {
      await _pump(
          tester,
          platform,
          _row({
            'prefix': 'Name',
            'helper': 'Shown on receipts',
            'error': 'Required'
          }));

      final row =
          tester.widget<CupertinoFormRow>(find.byType(CupertinoFormRow));
      expect(row.padding, isNull);
      final prefix = tester.getRect(find.text('Name'));
      final value = tester.getRect(find.text('Value'));
      // SDK default padding STEB(20, 6, 6, 6); content is end-aligned.
      expect(prefix.left, 20);
      expect(value.left, greaterThan(prefix.right));
      expect(value.right, 800 - 6);
      expect(value.center.dy, closeTo(prefix.center.dy, 0.5));
      final helper = tester.getRect(find.text('Shown on receipts'));
      final error = tester.getRect(find.text('Required'));
      expect(helper.left, 20);
      expect(helper.top, greaterThanOrEqualTo(prefix.bottom));
      expect(error.top, greaterThanOrEqualTo(helper.bottom));
      expect(_textColor(tester, 'Required'), CupertinoColors.destructiveRed);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ruby padding replaces the SDK default', (tester) async {
      await _pump(
          tester,
          platform,
          _row({
            'prefix': 'Name',
            'padding': {'left': 30, 'top': 10, 'right': 12, 'bottom': 10},
          }));

      final prefix = tester.getRect(find.text('Name'));
      final value = tester.getRect(find.text('Value'));
      expect(prefix.left, 30);
      expect(math.min(prefix.top, value.top), 10);
      expect(value.right, 800 - 12);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing content reports an error, alias renders',
        (tester) async {
      await _pump(tester, platform, {'_c': 'FormRow', '_i': 1, 'prefix': 'x'});
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.byType(CupertinoFormRow), findsNothing);

      await _pump(tester, platform, {
        ..._row({'prefix': 'Alias'}),
        '_c': 'CupertinoFormRow'
      });
      expect(find.byType(AdaptiveFormRowControl), findsOneWidget);
      expect(find.byType(CupertinoFormRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Android renders a Material form row', () {
    const platform = TargetPlatform.android;

    testWidgets('prefix label, trailing content, helper and error colors',
        (tester) async {
      await _pump(
          tester,
          platform,
          _row({
            'prefix': 'Name',
            'helper': 'Shown on receipts',
            'error': 'Required'
          }));

      expect(find.byType(CupertinoFormRow), findsNothing);
      final prefix = tester.getRect(find.text('Name'));
      final value = tester.getRect(find.text('Value'));
      // Padding h16 v8; 16 px gap after the label; content end-aligned.
      expect(prefix.left, 16);
      expect(math.min(prefix.top, value.top), 8);
      expect(value.left, greaterThanOrEqualTo(prefix.right + 16));
      expect(value.right, 800 - 16);
      expect(value.center.dy, closeTo(prefix.center.dy, 0.5));
      final helper = tester.getRect(find.text('Shown on receipts'));
      final error = tester.getRect(find.text('Required'));
      expect(helper.left, 16);
      expect(helper.top, greaterThanOrEqualTo(prefix.bottom));
      expect(error.top, greaterThanOrEqualTo(helper.bottom));

      final scheme =
          material.Theme.of(tester.element(find.text('Name'))).colorScheme;
      expect(_textColor(tester, 'Required'), scheme.error);
      expect(_textColor(tester, 'Shown on receipts'), scheme.onSurfaceVariant);
      expect(
          find.byWidgetPredicate((w) =>
              w is CupertinoButton ||
              w is CupertinoTextField ||
              w is CupertinoFormRow),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ruby padding replaces the Material default', (tester) async {
      await _pump(
          tester,
          platform,
          _row({
            'prefix': 'Name',
            'padding': {'left': 30, 'top': 10, 'right': 12, 'bottom': 10},
          }));

      final prefix = tester.getRect(find.text('Name'));
      final value = tester.getRect(find.text('Value'));
      expect(prefix.left, 30);
      expect(math.min(prefix.top, value.top), 10);
      expect(value.right, 800 - 12);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a prefix the content still ends the row',
        (tester) async {
      await _pump(tester, platform, _row({}));

      expect(tester.getRect(find.text('Value')).right, 800 - 16);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing content reports an error', (tester) async {
      await _pump(tester, platform, {'_c': 'FormRow', '_i': 1, 'prefix': 'x'});
      expect(find.byType(ErrorControl), findsOneWidget);
    });
  });
}
