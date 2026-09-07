import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

const source = '''
# Example

- [x] Finished
- [ ] Pending

```
long code line to scroll
```

| Name | Value |
| ---- | ----- |
| Test | Data  |
''';

void main() {
  testWidgets(
      'Cupertino code, tables, checkboxes and rich selection use native chrome',
      (tester) async {
    await tester.pumpWidget(CupertinoApp(
        home: SingleChildScrollView(
            child: MarkdownBody(
      data: source,
      selectable: true,
      styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
      styleSheet:
          MarkdownStyleSheet(tableColumnWidth: const IntrinsicColumnWidth()),
    ))));
    await tester.pump();
    expect(find.byType(CupertinoScrollbar), findsNWidgets(2));
    expect(find.byType(SelectableRegion), findsWidgets);
    expect(find.byIcon(CupertinoIcons.checkmark_square), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.square), findsOneWidget);
    expect(find.byType(material.Material), findsNothing);
    expect(find.byType(material.Theme), findsNothing);
    expect(find.byType(material.SelectableText), findsNothing);
    expect(find.byType(material.Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Material retains its selection and scrollbar renderers',
      (tester) async {
    await tester.pumpWidget(material.MaterialApp(
        home: SingleChildScrollView(
            child: MarkdownBody(
      data: source,
      selectable: true,
      styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
    ))));
    await tester.pump();
    expect(find.byType(material.SelectableText), findsWidgets);
    expect(find.byType(material.Scrollbar), findsOneWidget);
    expect(find.byType(CupertinoScrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Cupertino rich selection preserves exact offsets and native toolbar',
      (tester) async {
    TextSelection? selection;
    await tester.pumpWidget(CupertinoApp(
        home: Center(
            child: MarkdownBody(
      data: 'Alpha **beta** gamma',
      selectable: true,
      styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
      onSelectionChanged: (_, value, __) => selection = value,
    ))));
    await tester.pump();
    final region =
        tester.state<SelectableRegionState>(find.byType(SelectableRegion));
    region.selectAll(SelectionChangedCause.toolbar);
    await tester.pump();
    expect(selection?.start, 0);
    expect(selection?.end, 'Alpha beta gamma'.length);
    final toolbar = region.widget.contextMenuBuilder!(region.context, region);
    expect(toolbar, isA<CupertinoAdaptiveTextSelectionToolbar>());
    expect(tester.takeException(), isNull);
  });
}
