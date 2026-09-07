// The renderer fork intentionally shares the pinned upstream controllers.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:io';

import 'package:ruflet_code_editor/src/cupertino_editor/src/code_field/code_field.dart';
import 'package:ruflet_code_editor/src/utils/ruflet_code_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_code_editor/flutter_code_editor.dart' as upstream;
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/javascript.dart';

Widget host(Widget child) => CupertinoApp(
    home: CupertinoPageScaffold(
        child: Center(child: SizedBox(width: 600, height: 350, child: child))));

void expectNativeTree() {
  expect(find.byType(material.Material), findsNothing);
  expect(find.byType(material.Theme), findsNothing);
  expect(find.byType(material.TextField), findsNothing);
  expect(find.byType(material.InkWell), findsNothing);
  expect(find.byType(material.ToggleButtons), findsNothing);
}

void main() {
  testWidgets('Cupertino field edits, selects and folds the shared document',
      (tester) async {
    final controller = RufletCodeController(
        text: 'function hello() {\n  return 1;\n}\n', language: javascript);
    final focus = FocusNode();
    await tester.pumpWidget(
        host(CupertinoCodeField(controller: controller, focusNode: focus)));
    expectNativeTree();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.enterText(find.byType(CupertinoTextField),
        'function hello() {\n  return 2;\n}\n');
    await tester.pump();
    expect(controller.fullText, contains('return 2'));
    controller.selection = const TextSelection(baseOffset: 9, extentOffset: 14);
    await tester.pump();
    expect(controller.selection.textInside(controller.text), 'hello');
    controller.foldAt(0);
    await tester.pump();
    expect(controller.text.length, lessThan(controller.fullText.length));
    expect(controller.fullText, contains('return 2'));
    expectNativeTree();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });

  testWidgets(
      'search and completion overlays stay Cupertino and retain actions',
      (tester) async {
    final controller =
        RufletCodeController(text: 'alpha beta alpha', language: javascript);
    final focus = FocusNode();
    await tester.pumpWidget(
        host(CupertinoCodeField(controller: controller, focusNode: focus)));
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    controller.searchController.showSearch();
    await tester.pump();
    final search = find.widgetWithText(CupertinoTextField, 'Search…');
    await tester.enterText(search, 'alpha');
    await tester.pump();
    expect(
        controller.searchController.navigationController.value.totalMatchCount,
        2);
    await tester.tap(find.text('Aa'));
    await tester.pump();
    expect(controller.searchController.settingsController.value.isCaseSensitive,
        isTrue);
    expectNativeTree();
    controller.searchController.hideSearch(returnFocusToCodeField: true);
    await tester.pump();
    controller.fullText = 'al';
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    controller.popupController.show(['alpha', 'alphabet']);
    await tester.pump();
    expect(find.text('alphabet'), findsOneWidget);
    expectNativeTree();
    await tester.tap(find.text('alphabet'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('alphabet'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.fullText, 'alphabet');
    expect(controller.selection.baseOffset, 8);
    expectNativeTree();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });

  testWidgets('Material field retains the upstream Material editor',
      (tester) async {
    final controller =
        RufletCodeController(text: 'original', language: javascript);
    await tester.pumpWidget(material.MaterialApp(
        home: material.Scaffold(
      body: upstream.CodeField(controller: controller),
    )));
    expect(find.byType(material.TextField), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
    await tester.tap(find.byType(material.TextField));
    await tester.pump();
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    await tester.pump();
    await tester.enterText(find.byType(material.TextField), 'updated');
    await tester.pump();
    expect(controller.fullText, 'updated');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('native renderer files import no Material widget library', () {
    for (final file in Directory('lib/src/cupertino_editor')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      expect(file.readAsStringSync(),
          isNot(contains("package:flutter/material.dart")),
          reason: file.path);
    }
  });
}
