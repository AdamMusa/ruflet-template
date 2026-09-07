import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_button.dart';
import 'package:ruflet/src/widgets/constrained_default_padding.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final variant in ['FilledButton', 'OutlinedButton']) {
    testWidgets('$variant respects Ruby height and clip_behavior none',
        (tester) async {
      final backend = RufletBackend(
        pageUri: Uri.parse('inprocess://button-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      )..platform = TargetPlatform.iOS;
      final control = Control.fromMap({
        '_c': variant,
        '_i': 10,
        'width': 166,
        'height': 48,
        'clip_behavior': 'none',
        'icon': 71571,
        'content': 'Scan QR',
      }, backend);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: backend,
        child:
            CupertinoApp(home: Center(child: ControlWidget(control: control))),
      ));
      final button = find.byType(CupertinoButtonControl);
      expect(tester.getSize(button), const Size(166, 48));
      final paragraph =
          tester.renderObject<RenderParagraph>(find.text('Scan QR'));
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      addTearDown(painter.dispose);
      expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
      final clips = tester.widgetList<ClipPath>(
          find.descendant(of: button, matching: find.byType(ClipPath)));
      expect(clips.every((clip) => clip.clipBehavior == Clip.none), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$variant keeps explicit padding and clipping', (tester) async {
      final backend = RufletBackend(
          pageUri: Uri.parse('inprocess://button-test'),
          assetsDir: '',
          extensions: [],
          multiView: false)
        ..platform = TargetPlatform.iOS;
      final control = Control.fromMap({
        '_c': variant,
        '_i': 10,
        'width': 240,
        'height': 60,
        'content': 'Scan QR',
        'clip_behavior': 'antiAlias',
        'style': {
          'padding': {'left': 7, 'top': 3, 'right': 11, 'bottom': 5}
        },
      }, backend);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: backend,
          child: CupertinoApp(
              home: Center(child: ControlWidget(control: control)))));
      final button =
          tester.widget<CupertinoButton>(find.byType(CupertinoButton));
      expect(button.padding, const EdgeInsets.fromLTRB(7, 3, 11, 5));
      expect(find.byType(ConstrainedDefaultPadding), findsNothing);
      if (variant == 'OutlinedButton') {
        expect(tester.widget<ClipPath>(find.byType(ClipPath)).clipBehavior,
            Clip.antiAlias);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unconstrained default spacing stays native', (tester) async {
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: ConstrainedDefaultPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: SizedBox(width: 100, height: 24)))));
    expect(tester.getSize(find.byType(ConstrainedDefaultPadding)),
        const Size(140, 56));
    final outer = tester.getTopLeft(find.byType(ConstrainedDefaultPadding));
    expect(
        tester.getTopLeft(find.byType(SizedBox)), outer + const Offset(20, 16));
  });
}
