import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform shows and clears server-side field validation',
        (tester) async {
      final backend = RufletBackend(
        pageUri: Uri.parse('inprocess://validation-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      )..platform = platform;
      final control = Control.fromMap({
        '_c': 'TextField',
        '_i': 10,
        'value': '',
        'hint_text': 'Server URL',
        'error_style': {'color': '#BA1A1A'},
        'error_max_lines': 2,
      }, backend);
      final field = Center(
        child: SizedBox(width: 320, child: ControlWidget(control: control)),
      );
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: backend,
        child: platform == TargetPlatform.iOS
            ? CupertinoApp(home: CupertinoPageScaffold(child: field))
            : MaterialApp(home: Scaffold(body: field)),
      ));
      await tester.enterText(find.byType(EditableText), 'invalid');
      final editingState =
          tester.state<EditableTextState>(find.byType(EditableText));
      control.update({'error': 'Server URL is required.'}, shouldNotify: true);
      await tester.pumpAndSettle();

      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue);
      expect(tester.state<EditableTextState>(find.byType(EditableText)),
          same(editingState));
      final error = find.text('Server URL is required.');
      expect(error.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(error).dy,
          greaterThan(tester.getBottomLeft(find.byType(EditableText)).dy));
      expect(tester.widget<Text>(error).style?.color, const Color(0xFFBA1A1A));
      expect(tester.widget<Text>(error).maxLines, 2);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'invalid');

      control.update({'error': null}, shouldNotify: true);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue);
      expect(tester.state<EditableTextState>(find.byType(EditableText)),
          same(editingState));
      expect(tester.takeException(), isNull);
    });
  }
}
