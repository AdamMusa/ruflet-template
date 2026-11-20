// Ruby writes highlight theme and language names as symbols, so
// `code_theme: :atom_one_dark` and `language: :clojure_repl` reach the
// renderer in snake_case; highlight.js names them with hyphens.
// ruflet-coverage: CodeEditor
import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart' as fce;
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/all.dart';
import 'package:ruflet_code_editor/ruflet_code_editor.dart';

import 'support/harness.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      Future<void> mount(WidgetTester tester, Map<String, dynamic> props) =>
          mountWire(tester, platform,
              {'_c': 'CodeEditor', '_i': 1, 'value': '(+ 1 2)', ...props},
              extensions: [Extension()]);

      fce.CodeController controller(WidgetTester tester) =>
          tester.widget<EditableText>(find.byType(EditableText)).controller
              as fce.CodeController;

      Map<String, TextStyle> themeStyles(WidgetTester tester) =>
          tester.widget<fce.CodeTheme>(find.byType(fce.CodeTheme)).data!.styles;

      for (final (sent, theme) in [
        ('atom_one_dark', 'atom-one-dark'),
        ('ATOM_ONE_DARK', 'atom-one-dark'),
        ('atom-one-dark', 'atom-one-dark'),
        ('monokai_sublime', 'monokai-sublime'),
        ('qtcreator_dark', 'qtcreator_dark'),
      ]) {
        testWidgets('code_theme "$sent" selects $theme', (tester) async {
          await mount(tester, {'code_theme': sent});
          expect(themeStyles(tester), same(themeMap[theme]));
          await tester.pumpWidget(const SizedBox());

          await mount(tester, {
            'code_theme': {'name': sent}
          });
          expect(themeStyles(tester), same(themeMap[theme]));
          await tester.pumpWidget(const SizedBox());
        });
      }

      for (final (sent, language) in [
        ('clojure_repl', 'clojure-repl'),
        ('Clojure-REPL', 'clojure-repl'),
        ('vbscript_html', 'vbscript-html'),
        ('ruby', 'ruby'),
      ]) {
        testWidgets('language "$sent" selects $language', (tester) async {
          await mount(tester, {'language': sent});
          expect(controller(tester).language, same(allLanguages[language]));
          await tester.pumpWidget(const SizedBox());
        });
      }

      testWidgets('unknown names keep the plain editor', (tester) async {
        await mount(
            tester, {'code_theme': 'no_such_theme', 'language': 'nope'});
        expect(find.byType(fce.CodeTheme), findsNothing);
        expect(controller(tester).language, isNull);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
