import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

PlatformAppConfig config({required Widget home}) => PlatformAppConfig(
      title: 'test',
      showSemanticsDebugger: false,
      home: home,
      routerDelegate: null,
      routeInformationParser: null,
      routeInformationProvider: null,
      themeMode: RufletThemeMode.system,
      localizationsDelegates: const [],
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
    );

void main() {
  testWidgets('Cupertino app root excludes MaterialApp', (tester) async {
    await tester.pumpWidget(PlatformApp(
      design: PageDesign.cupertino,
      config: config(home: const Text('home')),
    ));

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsNothing);
  });

  testWidgets('Material app root excludes CupertinoApp', (tester) async {
    await tester.pumpWidget(PlatformApp(
      design: PageDesign.material,
      config: config(home: const Text('home')),
    ));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CupertinoApp), findsNothing);
  });

  testWidgets(
      'Material renderer stays Material when previewed on an Apple host',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      TargetPlatform? observed;
      await tester.pumpWidget(PlatformApp(
        design: PageDesign.material,
        config: config(home: Builder(builder: (context) {
          observed = Theme.of(context).platform;
          return const SizedBox();
        })),
      ));
      expect(observed, TargetPlatform.android);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
