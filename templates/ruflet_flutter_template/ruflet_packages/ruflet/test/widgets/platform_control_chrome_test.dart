import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_control_chrome.dart';
import 'package:ruflet/src/controls/material_control_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final backend = RufletBackend(
  pageUri: Uri.parse('ruflet://test'),
  assetsDir: '',
  extensions: [],
  multiView: false,
);

Control chromeControl() => Control(
      id: 20,
      type: 'Text',
      properties: {'tooltip': 'Native help', 'badge': '3'},
      backend: backend,
    );

void main() {
  testWidgets('Cupertino badge does not build Material Badge', (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        child: CupertinoControlBadge(
          control: chromeControl(),
          child: const Text('Inbox'),
        ),
      ),
    ));

    expect(find.text('3'), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('Cupertino tooltip uses a Cupertino overlay', (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: CupertinoControlTooltip(
            control: chromeControl(),
            child: const Text('Target'),
          ),
        ),
      ),
    ));

    expect(find.byType(Tooltip), findsNothing);
    await tester.longPress(find.text('Target'));
    await tester.pump();
    expect(find.text('Native help'), findsOneWidget);
  });

  testWidgets('Material chrome keeps native Material primitives',
      (tester) async {
    final control = chromeControl();
    await tester.pumpWidget(MaterialApp(
      home: MaterialControlBadge(
        control: control,
        child: MaterialControlTooltip(
          control: control,
          child: const Text('Inbox'),
        ),
      ),
    ));

    expect(find.byType(Badge), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
  });
}
