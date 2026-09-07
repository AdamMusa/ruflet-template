import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/error.dart';
import 'package:ruflet/src/widgets/loading_page.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_startup_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

Widget scoped(PageDesign design, Widget child) => PageContext(
      themeMode: null,
      brightness: null,
      widgetsDesign: design,
      child: design == PageDesign.cupertino
          ? CupertinoApp(home: child)
          : material.MaterialApp(home: child),
    );

void main() {
  for (final design in PageDesign.values) {
    final cupertino = design == PageDesign.cupertino;
    testWidgets('$design loading uses the matching scaffold and indicator',
        (tester) async {
      await tester.pumpWidget(scoped(
          design, const LoadingPage(isLoading: true, message: 'Starting')));
      expect(find.text('Starting'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator),
          cupertino ? findsOneWidget : findsNothing);
      expect(find.byType(CupertinoPageScaffold),
          cupertino ? findsOneWidget : findsNothing);
      expect(find.byType(material.CircularProgressIndicator),
          cupertino ? findsNothing : findsOneWidget);
      expect(find.byType(material.Scaffold),
          cupertino ? findsNothing : findsOneWidget);
    });

    testWidgets('$design errors use native selection', (tester) async {
      await tester.pumpWidget(scoped(design,
          const LoadingPage(isLoading: false, message: 'Connection failed')));
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.byType(SelectableRegion), findsOneWidget);
      expect(find.byType(material.SelectionArea),
          cupertino ? findsNothing : findsOneWidget);
      await tester.pumpWidget(scoped(
          design,
          const ErrorControl('Invalid control',
              description: 'Missing content')));
      expect(find.text('Missing content'), findsOneWidget);
      expect(find.byType(SelectableRegion), findsOneWidget);
      expect(find.byType(material.SelectionArea),
          cupertino ? findsNothing : findsOneWidget);
    });

    testWidgets('$design startup chooses native app before a backend exists',
        (tester) async {
      await tester.pumpWidget(const PlatformStartupApp(title: 'Ruflet'));
      expect(
          find.byType(CupertinoApp), cupertino ? findsOneWidget : findsNothing);
      expect(find.byType(material.MaterialApp),
          cupertino ? findsNothing : findsOneWidget);
      await tester.pumpWidget(const PlatformStartupApp(
          title: 'Ruflet', isLoading: false, message: 'Runtime failed'));
      expect(find.text('Ruflet'), findsOneWidget);
      expect(find.text('Runtime failed'), findsOneWidget);
      expect(find.byType(material.Scaffold),
          cupertino ? findsNothing : findsOneWidget);
      expect(find.byType(material.SelectionArea),
          cupertino ? findsNothing : findsOneWidget);
    },
        variant: TargetPlatformVariant(
            {cupertino ? TargetPlatform.iOS : TargetPlatform.android}));
  }
}
