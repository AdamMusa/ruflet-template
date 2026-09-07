import 'package:ruflet_spinkit/src/cupertino_pumping_heart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pumping heart uses Cupertino artwork and preserves animation',
      (tester) async {
    await tester.pumpWidget(const CupertinoApp(
        home: Center(
            child: CupertinoPumpingHeart(
      color: CupertinoColors.systemRed,
      size: 40,
      duration: Duration(seconds: 2),
    ))));
    expect(find.byIcon(CupertinoIcons.heart_fill), findsOneWidget);
    expect(tester.widget<Icon>(find.byType(Icon)).size, 40);
    final before = tester
        .widget<ScaleTransition>(find.byType(ScaleTransition).last)
        .scale
        .value;
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester
        .widget<ScaleTransition>(find.byType(ScaleTransition).last)
        .scale
        .value;
    expect(after, isNot(before));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
