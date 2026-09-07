import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/widgets/selectable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android
  ]) {
    testWidgets(
        '$platform selectable math retains native styles, select-all and copy toolbar',
        (tester) async {
      final cupertino = platform != TargetPlatform.android;
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings')
            return {'value': clipboard != null};
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final focus = FocusNode();
      final math = MathSelectionPlatform(
          platform: platform,
          child: Center(
              child: SelectableMath.tex(
            r'a+b',
            focusNode: focus,
            textStyle: const TextStyle(fontSize: 24, color: Color(0xFF000000)),
          )));
      await tester.pumpWidget(cupertino
          ? CupertinoApp(
              theme: const CupertinoThemeData(primaryColor: Color(0xFF123456)),
              home: math)
          : material.MaterialApp(
              theme:
                  material.ThemeData(colorSchemeSeed: const Color(0xFF654321)),
              home: math));
      await tester.pump();
      final state = tester.state<InternalSelectableMathState>(
          find.byType(InternalSelectableMath));
      if (cupertino) {
        expect(state.widget.cursorColor, const Color(0xFF123456));
        expect(
            state.textSelectionControls,
            same(platform == TargetPlatform.macOS
                ? cupertinoDesktopTextSelectionControls
                : cupertinoTextSelectionControls));
        expect(find.byType(material.Theme), findsNothing);
        expect(find.byType(material.Material), findsNothing);
      } else {
        expect(state.textSelectionControls,
            same(material.materialTextSelectionControls));
      }
      state.textSelectionControls.handleSelectAll(state);
      await tester.pump();
      expect(state.controller.selection.isCollapsed, isFalse);
      expect(state.showToolbar(), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      if (cupertino) {
        expect(find.byType(material.Theme), findsNothing);
        expect(find.byType(material.Material), findsNothing);
      }
      state.textSelectionControls.handleCopy(state);
      await tester.pump();
      expect(clipboard, contains('a'));
      expect(clipboard, isNot(contains('THIS MARKUP')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    });
  }

  testWidgets('malformed selectable math uses native selectable error text',
      (tester) async {
    await tester.pumpWidget(CupertinoApp(
        home: MathSelectionPlatform(
      platform: TargetPlatform.iOS,
      child: SelectableMath.tex(r'\frac{'),
    )));
    await tester.pump();
    expect(find.byType(SelectableRegion), findsOneWidget);
    expect(find.byType(material.SelectableText), findsNothing);
    expect(find.byType(material.Material), findsNothing);
    expect(find.byType(material.Theme), findsNothing);
    await tester.pumpWidget(material.MaterialApp(
        home: MathSelectionPlatform(
      platform: TargetPlatform.android,
      child: SelectableMath.tex(r'\frac{'),
    )));
    await tester.pump();
    expect(find.byType(material.SelectableText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
