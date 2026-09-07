import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_text.dart';
import 'package:ruflet/src/controls/material_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final backend = RufletBackend(
  pageUri: Uri.parse('ruflet://test'),
  assetsDir: '',
  extensions: [],
  multiView: false,
);

Control textControl({required bool selectable}) => Control(
      id: selectable ? 2 : 1,
      type: 'Text',
      properties: {'value': 'Native text', 'selectable': selectable},
      backend: backend,
    );

Widget withBackend(Widget child) =>
    ChangeNotifierProvider.value(value: backend, child: child);

void main() {
  testWidgets('Cupertino selectable text has no Material SelectableText',
      (tester) async {
    await tester.pumpWidget(withBackend(CupertinoApp(
      home: CupertinoPageScaffold(
        child: CupertinoTextControl(control: textControl(selectable: true)),
      ),
    )));

    expect(find.byType(SelectableRegion), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('Material selectable text uses Material renderer',
      (tester) async {
    await tester.pumpWidget(withBackend(MaterialApp(
      home: MaterialTextControl(control: textControl(selectable: true)),
    )));

    expect(find.byType(SelectableText), findsOneWidget);
  });
}
