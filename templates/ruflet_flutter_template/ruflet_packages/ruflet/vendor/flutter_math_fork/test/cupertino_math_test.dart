import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, SelectableText, Theme;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('valid and malformed display math require no Material subtree',
      (tester) async {
    for (final expression in [r'\frac{a}{b}', r'\frac{']) {
      await tester
          .pumpWidget(CupertinoApp(home: Center(child: Math.tex(expression))));
      await tester.pump();
      expect(find.byType(Material), findsNothing);
      expect(find.byType(Theme), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
