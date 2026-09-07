import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final variant in [
      'Button',
      'FilledButton',
      'FilledTonalButton',
      'OutlinedButton',
      'TextButton',
      'IconButton',
      'FloatingActionButton'
    ]) {
      for (final height in [32.0, 48.0, 64.0]) {
        testWidgets('$platform $variant paints explicit 160 x $height bounds',
            (tester) async {
          final backend = RufletBackend(
              pageUri: Uri.parse('inprocess://size-test'),
              assetsDir: '',
              extensions: [],
              multiView: false)
            ..platform = platform;
          final control = Control.fromMap({
            '_c': variant,
            '_i': 10,
            'width': 160,
            'height': height,
            'icon': 71571,
            if (variant != 'IconButton') 'content': 'Action',
          }, backend);
          final subject = ControlWidget(control: control);
          await tester.pumpWidget(ChangeNotifierProvider.value(
            value: backend,
            child: platform == TargetPlatform.iOS
                ? CupertinoApp(home: Center(child: subject))
                : material.MaterialApp(home: Center(child: subject)),
          ));
          final outer = tester.getRect(find.byWidget(subject));
          expect(outer.size, Size(160, height));
          // The outlined renderer paints its border outside CupertinoButton.
          // Compare the painted surface, not only the outer layout wrapper.
          final surface = platform == TargetPlatform.iOS
              ? find.descendant(
                  of: find.byWidget(subject),
                  matching: variant == 'OutlinedButton'
                      ? find.byWidgetPredicate((widget) =>
                          widget is DecoratedBox &&
                          widget.decoration is ShapeDecoration &&
                          (widget.decoration as ShapeDecoration).shape
                              is RoundedRectangleBorder)
                      : find.byType(CupertinoButton))
              : find.descendant(
                  of: find.byWidget(subject),
                  matching: find.byType(material.Material));
          expect(surface, findsOneWidget);
          expect(tester.getRect(surface), outer);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
