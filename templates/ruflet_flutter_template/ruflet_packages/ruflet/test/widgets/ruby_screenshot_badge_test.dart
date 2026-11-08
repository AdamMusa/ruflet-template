import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform Screenshot renders its Ruby badge', (tester) async {
      final backend = RufletBackend(
        pageUri: Uri.parse('inprocess://screenshot-badge-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      )..platform = platform;
      // Ruflet.screenshot(container(text("Body content"), width: 200, height: 60), badge: "7")
      final control = Control.fromMap({
        '_c': 'Screenshot',
        '_i': 1,
        'badge': '7',
        'content': {
          '_c': 'Container',
          '_i': 2,
          'width': 200,
          'height': 60,
          'content': {'_c': 'Text', '_i': 3, 'value': 'Body content'},
        },
      }, backend);
      final body = Center(child: ControlWidget(control: control));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: backend,
          child: platform == TargetPlatform.iOS
              ? CupertinoApp(home: body)
              : material.MaterialApp(home: material.Scaffold(body: body)),
        ),
      );
      expect(tester.takeException(), isNull);

      expect(find.text('Body content'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      // The badge sits on the content's top-end corner.
      final content = tester.getRect(find.byWidgetPredicate(
          (widget) => widget is ControlWidget && widget.control.id == 2));
      final badge = tester.getCenter(find.text('7'));
      expect(badge.dx, greaterThan(content.center.dx));
      expect(badge.dy, lessThan(content.center.dy));
    });
  }
}
