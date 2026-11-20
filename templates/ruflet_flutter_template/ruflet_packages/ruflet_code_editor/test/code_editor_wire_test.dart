// CodeEditor mounted from the map Ruby sends, under both designs: the
// properties reach the rendered editor, events reach Ruby only when it
// subscribed, edits write back, and every Ruby method acts on the editor.
// ruflet-coverage: CodeEditor
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_code_editor/flutter_code_editor.dart' as fce;
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/all.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_code_editor/ruflet_code_editor.dart';
import 'package:ruflet_code_editor/src/code_editor.dart';
import 'package:ruflet_code_editor/src/cupertino_editor/src/code_field/code_field.dart';
import 'package:ruflet_code_editor/src/utils/ruflet_code_controller.dart';

import 'support/harness.dart';

const _timeout = Duration(seconds: 2);

const _rubySource = '# frozen_string_literal: true\n'
    'require "json"\n'
    'require "set"\n'
    '\n'
    'class Greeter\n'
    '  def hello\n'
    '    puts "hi"\n'
    '  end\n'
    'end\n';

const _javaSource = 'import java.util.List;\n'
    'import java.util.Map;\n'
    '\n'
    'class Main {\n'
    '  void run() {\n'
    '    int x = 1;\n'
    '  }\n'
    '}\n';

Map<String, dynamic> _editor([Map<String, dynamic> props = const {}]) => {
      '_c': 'CodeEditor',
      '_i': 1,
      'value': 'puts :ok',
      'language': 'ruby',
      ...props,
    };

Future<Mounted> _mount(WidgetTester tester, TargetPlatform platform,
        [Map<String, dynamic> props = const {}]) =>
    mountWire(tester, platform, _editor(props), extensions: [Extension()]);

Finder _field(TargetPlatform platform) => platform == TargetPlatform.iOS
    ? find.byType(CupertinoTextField)
    : find.byType(material.TextField);

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

RufletCodeController _controller(WidgetTester tester) =>
    _editable(tester).controller as RufletCodeController;

/// The gutter style the design's code field was built with.
fce.GutterStyle _gutterStyle(WidgetTester tester, TargetPlatform platform) =>
    platform == TargetPlatform.iOS
        ? tester
            .widget<CupertinoCodeField>(find.byType(CupertinoCodeField))
            .gutterStyle
        : tester.widget<fce.CodeField>(find.byType(fce.CodeField)).gutterStyle;

Finder get _gutter => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'GutterWidget');

/// The line numbers the gutter shows, top to bottom.
List<String> _lineNumbers(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: _gutter, matching: find.byType(Text)))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .where((label) => int.tryParse(label) != null)
    .toList();

List<String> _eventNames(Mounted m) =>
    [for (final e in m.backend.events) e.name];

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      testWidgets('renders the design editor with Ruby value and language',
          (tester) async {
        await _mount(tester, platform, {'value': _rubySource});

        expect(find.byType(CodeEditorControl), findsOneWidget);
        expect(_field(platform), findsOneWidget);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(material.Material), findsNothing);
          expect(find.byType(material.TextField), findsNothing);
          expect(find.byType(fce.CodeField), findsNothing);
        } else {
          expect(find.byType(fce.CodeField), findsOneWidget);
          expect(find.byType(CupertinoTextField), findsNothing);
        }

        final controller = _controller(tester);
        expect(controller.fullText, _rubySource);
        expect(controller.text, _rubySource);
        expect(controller.language, same(allLanguages['ruby']));
        // Highlighting splits the source into styled token spans.
        final span = controller.buildTextSpan(
            context: tester.element(find.byType(EditableText)),
            withComposing: false);
        final tokens = <String>[];
        span.visitChildren((child) {
          if (child is TextSpan && child.text != null) tokens.add(child.text!);
          return true;
        });
        expect(tokens.length, greaterThan(5));
        expect(tokens.join(), _rubySource);

        // Every line is numbered in the gutter, 1-based.
        expect(_lineNumbers(tester),
            ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10']);
        expect(_editable(tester).readOnly, isFalse);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });

      testWidgets('read_only, disabled, text_style and padding reach the field',
          (tester) async {
        await _mount(tester, platform, {
          'read_only': true,
          'text_style': {'size': 21, 'color': '#123456'},
          'padding': 12,
        });
        var editable = _editable(tester);
        expect(editable.readOnly, isTrue);
        expect(editable.style.fontSize, 21);
        expect(editable.style.color, const Color(0xFF123456));
        expect(editable.scrollPadding, const EdgeInsets.all(12));
        final field = tester.widget(_field(platform));
        expect(
            field is CupertinoTextField
                ? field.enabled
                : (field as material.TextField).enabled,
            isNot(false));
        await _unmount(tester);

        await _mount(tester, platform, {'disabled': true});
        final disabled = tester.widget(_field(platform));
        expect(
            disabled is CupertinoTextField
                ? disabled.enabled
                : (disabled as material.TextField).enabled,
            isFalse);
        await _unmount(tester);
      });

      testWidgets('width and height size the editor', (tester) async {
        await _mount(tester, platform, {'width': 420, 'height': 180});
        expect(tester.getSize(find.byType(CodeEditorControl)),
            const Size(420, 180));
        expect(tester.getSize(_field(platform)).width, lessThan(420));
        await _unmount(tester);
      });

      testWidgets('gutter_style sets gutter width, colors and columns',
          (tester) async {
        await _mount(tester, platform, {
          'value': 'a\nb\nc',
          'gutter_style': {
            'width': 90,
            'margin': 6,
            'background_color': '#ff0000',
            'text_style': {'color': '#00ff00', 'size': 11},
          },
        });
        expect(tester.getSize(_gutter).width, 90);
        expect(_lineNumbers(tester), ['1', '2', '3']);
        final number = tester.widget<Text>(
            find.descendant(of: _gutter, matching: find.text('2')));
        expect(number.style?.color, const Color(0xFF00FF00));
        // Line numbers keep the code's font size so rows stay aligned.
        expect(number.style?.fontSize, _editable(tester).style.fontSize);
        final gutterBox = tester.widget<Container>(find
            .descendant(of: _gutter, matching: find.byType(Container))
            .first);
        expect(gutterBox.padding, const EdgeInsets.only(right: 6));
        // flutter_code_editor 0.3.5 carries the gutter background in its
        // GutterStyle but never paints it, so assert what the field receives.
        final style = _gutterStyle(tester, platform);
        expect(style.background, const Color(0xFFFF0000));
        expect(style.width, 90);
        expect(style.margin, 6);
        await _unmount(tester);

        // Hiding the error and folding columns narrows the gutter; hiding
        // line numbers removes them.
        await _mount(tester, platform, {
          'value': 'a\nb\nc',
          'gutter_style': {
            'width': 90,
            'show_errors': false,
            'show_folding_handles': false,
          },
        });
        expect(tester.getSize(_gutter).width, 90 - 16 - 16);
        expect(_lineNumbers(tester), ['1', '2', '3']);
        await _unmount(tester);

        await _mount(tester, platform, {
          'value': 'a\nb\nc',
          'gutter_style': {'show_line_numbers': false},
        });
        expect(_lineNumbers(tester), isEmpty);
        await _unmount(tester);
      });

      testWidgets('code_theme applies a named or custom highlight theme',
          (tester) async {
        await _mount(tester, platform, {'code_theme': 'monokai-sublime'});
        var theme = tester.widget<fce.CodeTheme>(find.byType(fce.CodeTheme));
        expect(theme.data!.styles, same(themeMap['monokai-sublime']));
        final root = themeMap['monokai-sublime']!['root']!;
        expect(_editable(tester).style.color, root.color);
        await _unmount(tester);

        await _mount(tester, platform, {
          'code_theme': {'name': 'github'}
        });
        theme = tester.widget<fce.CodeTheme>(find.byType(fce.CodeTheme));
        expect(theme.data!.styles, same(themeMap['github']));
        await _unmount(tester);

        await _mount(tester, platform, {
          'code_theme': {
            'root': {'color': '#101010'},
            'keyword': {'color': '#ff0000', 'weight': 'bold'},
          }
        });
        theme = tester.widget<fce.CodeTheme>(find.byType(fce.CodeTheme));
        expect(theme.data!.styles['keyword']?.color, const Color(0xFFFF0000));
        expect(theme.data!.styles['keyword']?.fontWeight, FontWeight.bold);
        expect(_editable(tester).style.color, const Color(0xFF101010));
        await _unmount(tester);

        await _mount(tester, platform, {
          'code_theme': {
            'styles': {
              'string': {'color': '#00ff00'}
            }
          }
        });
        theme = tester.widget<fce.CodeTheme>(find.byType(fce.CodeTheme));
        expect(theme.data!.styles['string']?.color, const Color(0xFF00FF00));
        await _unmount(tester);

        await _mount(tester, platform);
        expect(find.byType(fce.CodeTheme), findsNothing);
        await _unmount(tester);
      });

      testWidgets('focus and blur reach Ruby only when subscribed',
          (tester) async {
        var m =
            await _mount(tester, platform, {'on_focus': true, 'on_blur': true});
        await tester.tap(_field(platform));
        await tester.pump();
        expect(m.backend.events.single, (id: 1, name: 'focus', data: null));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        expect(_eventNames(m), ['focus', 'blur']);
        await _unmount(tester);

        m = await _mount(tester, platform);
        await tester.tap(_field(platform));
        await tester.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        expect(m.backend.events, isEmpty);
        await _unmount(tester);
      });

      testWidgets('typing writes value back and sends change when subscribed',
          (tester) async {
        var m = await _mount(tester, platform, {'on_change': true});
        await tester.tap(_field(platform));
        await tester.pump();
        await tester.enterText(_field(platform), 'puts :changed');
        await tester.pump();
        expect(m.root.getString('value'), 'puts :changed');
        expect(m.backend.updates.map((u) => u.$2['value']),
            contains('puts :changed'));
        expect(m.backend.events.where((e) => e.name == 'change').toList(),
            [(id: 1, name: 'change', data: 'puts :changed')]);
        await _unmount(tester);

        m = await _mount(tester, platform);
        await tester.tap(_field(platform));
        await tester.pump();
        await tester.enterText(_field(platform), 'puts :quiet');
        await tester.pump();
        expect(m.root.getString('value'), 'puts :quiet');
        expect(m.backend.events, isEmpty);
        await _unmount(tester);
      });

      testWidgets(
          'selecting sends selection_change with the selected text and range',
          (tester) async {
        final m = await _mount(tester, platform,
            {'value': 'hello world', 'on_selection_change': true});
        await tester.tap(_field(platform));
        await tester.pump();
        _controller(tester).selection =
            const TextSelection(baseOffset: 6, extentOffset: 11);
        await tester.pump();
        final event =
            m.backend.events.lastWhere((e) => e.name == 'selection_change');
        expect(event.data, {
          'selected_text': 'world',
          'selection': {
            'base_offset': 6,
            'extent_offset': 11,
            'affinity': 'downstream',
            'directional': false,
          },
        });
        expect(m.root.get('selection'), {
          'base_offset': 6,
          'extent_offset': 11,
          'affinity': 'downstream',
          'directional': false,
        });
        await _unmount(tester);

        final quiet = await _mount(tester, platform, {'value': 'hello world'});
        await tester.tap(_field(platform));
        await tester.pump();
        _controller(tester).selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);
        await tester.pump();
        expect(quiet.backend.events, isEmpty);
        expect((quiet.root.get('selection') as Map)['extent_offset'], 5);
        await _unmount(tester);
      });

      testWidgets('Ruby selection and value updates apply to the editor',
          (tester) async {
        final m = await _mount(tester, platform, {
          'value': 'puts :ok',
          'selection': {'base_offset': 0, 'extent_offset': 4},
        });
        expect(_controller(tester).selection,
            const TextSelection(baseOffset: 0, extentOffset: 4));

        m.backend.updateControl(1, {'value': 'puts :updated'}, notify: true);
        await tester.pumpAndSettle();
        expect(_controller(tester).fullText, 'puts :updated');
        expect(_editable(tester).controller.text, 'puts :updated');

        m.backend.updateControl(
            1,
            {
              'selection': {'base_offset': 5, 'extent_offset': 13}
            },
            notify: true);
        await tester.pumpAndSettle();
        expect(_controller(tester).selection.textInside('puts :updated'),
            ':updated');
        await _unmount(tester);
      });

      testWidgets('a Ruby language change rehighlights the same text',
          (tester) async {
        final m = await _mount(tester, platform, {'value': _javaSource});
        final before = _controller(tester);
        expect(before.language, same(allLanguages['ruby']));

        m.backend.updateControl(1, {'language': 'java'}, notify: true);
        await tester.pumpAndSettle();
        final after = _controller(tester);
        expect(after, isNot(same(before)));
        expect(after.language, same(allLanguages['java']));
        expect(after.fullText, _javaSource);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });

      testWidgets('autofocus focuses the editor and tells Ruby',
          (tester) async {
        final m = await _mount(
            tester, platform, {'autofocus': true, 'on_focus': true});
        await tester.pump();
        expect(_editable(tester).focusNode.hasFocus, isTrue);
        expect(_eventNames(m), ['focus']);
        await _unmount(tester);

        await _mount(tester, platform);
        expect(_editable(tester).focusNode.hasFocus, isFalse);
        await _unmount(tester);
      });

      testWidgets('autocomplete suggests Ruby autocomplete_words',
          (tester) async {
        await _mount(tester, platform, {
          'value': '',
          'autocomplete': true,
          'autocomplete_words': ['ruflet_button', 'ruflet_text'],
        });
        expect(_controller(tester).autocompletionEnabled, isTrue);
        await tester.tap(_field(platform));
        await tester.pump();
        await tester.enterText(_field(platform), 'ruf');
        await tester.pumpAndSettle();
        final popup = _controller(tester).popupController;
        expect(popup.shouldShow, isTrue);
        expect(
            popup.suggestions, containsAll(['ruflet_button', 'ruflet_text']));
        await _unmount(tester);

        await _mount(tester, platform, {
          'value': '',
          'autocomplete_words': ['ruflet_button'],
        });
        expect(_controller(tester).autocompletionEnabled, isFalse);
        await tester.tap(_field(platform));
        await tester.pump();
        await tester.enterText(_field(platform), 'ruf');
        await tester.pumpAndSettle();
        expect(_controller(tester).popupController.shouldShow, isFalse);
        await _unmount(tester);
      });

      testWidgets('focus method focuses the editor', (tester) async {
        final m = await _mount(tester, platform, {'on_focus': true});
        expect(_editable(tester).focusNode.hasFocus, isFalse);
        final result = await tester
            .runAsync(() => m.root.invokeMethod('focus', null, _timeout));
        await tester.pump();
        expect(result, isNull);
        expect(_editable(tester).focusNode.hasFocus, isTrue);
        expect(_eventNames(m), ['focus']);
        await _unmount(tester);
      });

      testWidgets('fold methods fold comment, imports and a given line',
          (tester) async {
        var m = await _mount(
            tester, platform, {'value': _javaSource, 'language': 'java'});
        expect(_lineNumbers(tester),
            ['1', '2', '3', '4', '5', '6', '7', '8', '9']);
        final folded = await tester.runAsync(
            () => m.root.invokeMethod('fold_at', {'line_number': 4}, _timeout));
        await tester.pumpAndSettle();
        expect(folded, isNull);
        // Folding `void run() {` (0-based line 4) hides its body only.
        expect(_controller(tester).text.contains('int x = 1;'), isFalse);
        expect(_controller(tester).text, contains('void run() {'));
        expect(_controller(tester).fullText, _javaSource);
        expect(_lineNumbers(tester), isNot(contains('6')));
        expect(_lineNumbers(tester).take(5), ['1', '2', '3', '4', '5']);
        await _unmount(tester);

        m = await _mount(
            tester, platform, {'value': _javaSource, 'language': 'java'});
        await tester.runAsync(
            () => m.root.invokeMethod('fold_imports', null, _timeout));
        await tester.pumpAndSettle();
        expect(_controller(tester).text.contains('java.util.Map'), isFalse);
        expect(_controller(tester).fullText, _javaSource);
        await _unmount(tester);

        m = await _mount(tester, platform, {
          'value': '/*\n * License\n * text\n */\nclass A {}\n',
          'language': 'java',
        });
        await tester.runAsync(() =>
            m.root.invokeMethod('fold_comment_at_line_zero', null, _timeout));
        await tester.pumpAndSettle();
        expect(_controller(tester).text.contains('License'), isFalse);
        expect(_controller(tester).text, contains('class A {}'));
        await _unmount(tester);
      });

      testWidgets('fold_at without a line and unknown methods', (tester) async {
        final m = await _mount(tester, platform, {'value': _rubySource});
        await tester
            .runAsync(() => m.root.invokeMethod('fold_at', null, _timeout));
        await tester.pumpAndSettle();
        expect(_controller(tester).text, _rubySource);

        Object? error;
        await tester.runAsync(() => m.root
            .invokeMethod('select_all', null, _timeout)
            .catchError((Object e) => error = e));
        expect(error.toString(), contains('Unknown CodeEditor method'));
        await _unmount(tester);
      });
    });
  }
}
