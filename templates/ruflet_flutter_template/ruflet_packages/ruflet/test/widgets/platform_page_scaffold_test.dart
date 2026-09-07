import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/platform_page_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cupertino shell does not contain a Material Scaffold',
      (tester) async {
    final controller = PlatformPageScaffoldController();

    await tester.pumpWidget(CupertinoApp(
      home: PlatformPageScaffold(
        design: PageDesign.cupertino,
        controller: controller,
        appBar: const SizedBox(key: Key('canonical-app-bar')),
        body: const Text('body'),
        drawer: const Text('drawer'),
      ),
    ));

    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(Scaffold), findsNothing);
    expect(find.byKey(const Key('canonical-app-bar')), findsOneWidget);

    controller.showDrawer();
    await tester.pump();
    expect(find.text('drawer'), findsOneWidget);

    controller.closeDrawer();
    await tester.pump();
    expect(find.text('drawer'), findsNothing);
  });

  testWidgets('Material shell does not contain a CupertinoPageScaffold',
      (tester) async {
    final controller = PlatformPageScaffoldController();

    await tester.pumpWidget(MaterialApp(
      home: PlatformPageScaffold(
        design: PageDesign.material,
        controller: controller,
        appBar: const SizedBox(key: Key('canonical-app-bar')),
        body: const Text('body'),
      ),
    ));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsNothing);
    expect(find.byKey(const Key('canonical-app-bar')), findsOneWidget);
  });

  for (final opaque in [false, true]) {
    testWidgets(
        'Cupertino body clears ${opaque ? 'opaque' : 'translucent'} '
        'navigation chrome exactly once', (tester) async {
      const bodyKey = Key('inset-body');
      await tester.pumpWidget(CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 54, bottom: 34),
          ),
          child: PlatformPageScaffold(
            design: PageDesign.cupertino,
            controller: PlatformPageScaffoldController(),
            appBar: CupertinoNavigationBar(
              backgroundColor:
                  opaque ? const Color(0xFFFFFFFF) : const Color(0xCCFFFFFF),
              middle: const Text('Navigation'),
            ),
            body: const SizedBox.expand(key: bodyKey),
          ),
        ),
      ));

      expect(tester.getTopLeft(find.byKey(bodyKey)).dy, 54 + 44);
      expect(tester.getBottomLeft(find.byKey(bodyKey)).dy, 600 - 34);
      expect(find.byType(Scaffold), findsNothing);
    });
  }
}
