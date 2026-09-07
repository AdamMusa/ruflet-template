import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_markdown.dart';
import 'package:ruflet/src/controls/material_markdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';

final backend = RufletBackend(
  pageUri: Uri.parse('ruflet://test'),
  assetsDir: '',
  extensions: [],
  multiView: false,
);

Control markdownControl({String value = '# Native Markdown\n\nSelect me'}) =>
    Control(
      id: 10,
      type: 'Markdown',
      properties: {
        'value': value,
        'selectable': true,
      },
      backend: backend,
    );

Widget withBackend(Widget child) =>
    ChangeNotifierProvider.value(value: backend, child: child);

void main() {
  testWidgets('Cupertino Markdown has a Cupertino-only selection region',
      (tester) async {
    await tester.pumpWidget(withBackend(CupertinoApp(
      home: CupertinoPageScaffold(
        child: CupertinoMarkdownControl(control: markdownControl()),
      ),
    )));
    await tester.pump();

    expect(find.byType(SelectableRegion), findsOneWidget);
    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('Material Markdown uses Material selection', (tester) async {
    await tester.pumpWidget(withBackend(MaterialApp(
      home: MaterialMarkdownControl(control: markdownControl()),
    )));
    await tester.pump();

    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets('vendored design-neutral LaTeX builder renders equations',
      (tester) async {
    await tester.pumpWidget(withBackend(CupertinoApp(
      home: CupertinoPageScaffold(
        child: CupertinoMarkdownControl(
          control: markdownControl(value: r'The result is $x^2$.'),
        ),
      ),
    )));
    await tester.pump();

    expect(find.byType(Math), findsOneWidget);
  });
}
