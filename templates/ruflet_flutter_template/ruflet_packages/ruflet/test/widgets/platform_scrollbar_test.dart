import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/scrollable_control.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final design in PageDesign.values) {
    testWidgets('$design scrollbar keeps controller and scroll commands',
        (tester) async {
      final backend = RufletBackend(
          pageUri: Uri.parse('ruflet://test'),
          assetsDir: '',
          extensions: [],
          multiView: false);
      backend.platform = design == PageDesign.cupertino
          ? TargetPlatform.iOS
          : TargetPlatform.android;
      final control = Control(
          id: 1,
          type: 'Column',
          properties: {'scroll': 'always'},
          backend: backend);
      final controller = ScrollController();
      Widget child() => Center(
              child: SizedBox(
            width: 200,
            height: 100,
            child: ScrollableControl(
              control: control,
              scrollController: controller,
              scrollDirection: Axis.vertical,
              wrapIntoScrollableView: true,
              child: const SizedBox(height: 1000),
            ),
          ));
      Widget app() => ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: PageContext(
              themeMode: null,
              brightness: null,
              widgetsDesign: design,
              child: design == PageDesign.cupertino
                  ? CupertinoApp(home: child())
                  : material.MaterialApp(home: child())));
      await tester.pumpWidget(app());
      expect(find.byType(CupertinoScrollbar),
          design == PageDesign.cupertino ? findsOneWidget : findsNothing);
      expect(find.byType(material.Scrollbar),
          design == PageDesign.material ? findsOneWidget : findsNothing);
      await control.invokeMethod(
          'scroll_to', {'offset': 120}, const Duration(seconds: 1));
      expect(controller.offset, 120);
      await control.invokeMethod(
          'scroll_to', {'delta': 30}, const Duration(seconds: 1));
      expect(controller.offset, 150);
      await control.invokeMethod(
          'scroll_to', {'offset': -1}, const Duration(seconds: 1));
      expect(controller.offset, controller.position.maxScrollExtent);
      control.update({'auto_scroll': true}, shouldNotify: false);
      controller.jumpTo(0);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      await tester.pumpWidget(const SizedBox());
      expect(controller.hasClients, isFalse);
      controller.dispose();
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.iOS}));
  }

  testWidgets('unattached autoscroll and scroll commands are safe',
      (tester) async {
    final backend = RufletBackend(
        pageUri: Uri.parse('ruflet://test'),
        assetsDir: '',
        extensions: [],
        multiView: false);
    final control = Control(
        id: 2,
        type: 'Column',
        properties: {'scroll': 'none', 'auto_scroll': true},
        backend: backend);
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: material.MaterialApp(
            home: ScrollableControl(
                control: control,
                scrollDirection: Axis.vertical,
                child: const SizedBox()))));
    await control.invokeMethod(
        'scroll_to', {'offset': 10}, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
