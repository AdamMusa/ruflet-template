import 'package:flet/flet.dart';
import 'package:flet/src/controls/cupertino_control_theme.dart';
import 'package:flet/src/controls/material_control_theme.dart';
import 'package:flet/src/widgets/platform_control_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final backend = FletBackend(
  pageUri: Uri.parse('flet://test'),
  assetsDir: '',
  extensions: [],
  multiView: false,
);

Control themedControl() => Control(
      id: 30,
      type: 'Container',
      properties: {
        'theme': <String, dynamic>{},
        'theme_mode': 'light',
      },
      backend: backend,
    );

Widget withBackend(Widget child) =>
    ChangeNotifierProvider.value(value: backend, child: child);

void main() {
  testWidgets('Cupertino per-control theme creates no Material Theme',
      (tester) async {
    backend.platform = TargetPlatform.iOS;
    backend.notifyListeners();
    await tester.pumpWidget(withBackend(CupertinoApp(
      home: CupertinoPageScaffold(
        child: PlatformControlTheme(
          control: themedControl(),
          child: const SizedBox(key: Key('themed-child')),
        ),
      ),
    )));

    final child = find.byKey(const Key('themed-child'));
    expect(find.ancestor(of: child, matching: find.byType(CupertinoTheme)),
        findsWidgets);
    expect(
        find.ancestor(of: child, matching: find.byType(Theme)), findsNothing);
    expect(find.byType(CupertinoControlTheme), findsOneWidget);
    expect(find.byType(MaterialControlTheme), findsNothing);
  });

  testWidgets('Material per-control theme creates no CupertinoTheme',
      (tester) async {
    backend.platform = TargetPlatform.android;
    backend.notifyListeners();
    await tester.pumpWidget(withBackend(MaterialApp(
      home: PlatformControlTheme(
        control: themedControl(),
        child: const SizedBox(key: Key('themed-child')),
      ),
    )));

    final child = find.byKey(const Key('themed-child'));
    expect(
        find.ancestor(of: child, matching: find.byType(Theme)), findsWidgets);
    expect(find.byType(MaterialControlTheme), findsOneWidget);
    expect(find.byType(CupertinoControlTheme), findsNothing);
  });
}
