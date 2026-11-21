// A value, selection or language Ruby sets is Ruby's own change: the editor
// applies it without firing Ruby's on_change / on_selection_change or writing
// the value back. (The core TextField does not fire on_change for a Ruby
// value either, but it does fire on_selection_change for a Ruby selection.)
// A selection the editor clamps to the text is written back, so Ruby's copy
// does not stay past the end of its value.
// ruflet-coverage: CodeEditor
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_code_editor/ruflet_code_editor.dart';

import 'support/harness.dart';

const _subscribed = {
  'on_change': true,
  'on_selection_change': true,
  'on_focus': true,
  'on_blur': true,
};

/// The selection map the editor writes back for a cursor at [offset].
Map<String, dynamic> _collapsed(int offset) => {
      'base_offset': offset,
      'extent_offset': offset,
      'affinity': 'downstream',
      'directional': false,
    };

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      Future<Mounted> mount(WidgetTester tester,
              [Map<String, dynamic> props = const {}]) =>
          mountWire(tester, platform, {
            '_c': 'CodeEditor',
            '_i': 1,
            'value': 'puts :ok',
            'language': 'ruby',
            ..._subscribed,
            ...props,
          }, extensions: [
            Extension()
          ]);

      EditableText editable(WidgetTester tester) =>
          tester.widget<EditableText>(find.byType(EditableText));

      testWidgets('a Ruby value is applied without change or write-back',
          (tester) async {
        final m = await mount(tester);
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        m.backend.updateControl(1, {'value': 'puts :from_ruby'}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.text, 'puts :from_ruby');
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        // The user's next keystroke (at the end) still reaches Ruby.
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        await tester.enterText(find.byType(EditableText), 'puts :from_ruby!');
        await tester.pump();
        expect(m.backend.events.where((e) => e.name == 'change').toList(),
            [(id: 1, name: 'change', data: 'puts :from_ruby!')]);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a Ruby selection is applied without selection_change',
          (tester) async {
        final m = await mount(tester, {
          'selection': {'base_offset': 0, 'extent_offset': 4}
        });
        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 0, extentOffset: 4));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        m.backend.updateControl(
            1,
            {
              'selection': {'base_offset': 5, 'extent_offset': 8}
            },
            notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 5, extentOffset: 8));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        // The user's next selection still reaches Ruby.
        editable(tester).controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 4);
        await tester.pump();
        expect(m.backend.events.single.name, 'selection_change');
        expect((m.backend.events.single.data as Map)['selected_text'], 'puts');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a Ruby language change keeps the selection silently',
          (tester) async {
        final m = await mount(tester);
        editable(tester).controller.selection =
            const TextSelection(baseOffset: 5, extentOffset: 8);
        await tester.pump();
        m.backend.events.clear();
        m.backend.updates.clear();

        m.backend.updateControl(1, {'language': 'python'}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.text, 'puts :ok');
        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 5, extentOffset: 8));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets(
          'a Ruby value shorter than the selection writes back the clamped '
          'selection only', (tester) async {
        final m = await mount(tester, {'value': 'puts :hello_world'});
        editable(tester).controller.selection =
            const TextSelection.collapsed(offset: 10);
        await tester.pump();
        expect(m.root.get('selection'), _collapsed(10));
        m.backend.events.clear();
        m.backend.updates.clear();

        m.backend.updateControl(1, {'value': 'x = 1'}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        const clamped = TextSelection.collapsed(offset: 5);
        expect(editable(tester).controller.text, 'x = 1');
        expect(editable(tester).controller.selection, clamped);
        expect(m.backend.events, isEmpty);
        expect([
          for (final (id, props) in m.backend.updates) [id, props]
        ], [
          [
            1,
            {'selection': _collapsed(5)}
          ]
        ]);
        expect(m.root.get('selection'), _collapsed(5));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets(
          'a Ruby selection past the end writes back the clamped selection '
          'only', (tester) async {
        // 'puts :ok' has 8 characters.
        final m = await mount(tester, {
          'selection': {'base_offset': 20, 'extent_offset': 20}
        });
        const clamped = TextSelection.collapsed(offset: 8);
        List<List<Object>> writeBacks() => [
              for (final (id, props) in m.backend.updates) [id, props]
            ];
        expect(editable(tester).controller.selection, clamped);
        expect(m.backend.events, isEmpty);
        expect(writeBacks(), [
          [
            1,
            {'selection': _collapsed(8)}
          ]
        ]);
        expect(m.root.get('selection'), _collapsed(8));

        // Past the end again, where the cursor already is.
        m.backend.updates.clear();
        m.backend.updateControl(
            1,
            {
              'selection': {'base_offset': 30, 'extent_offset': 30}
            },
            notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();
        expect(editable(tester).controller.selection, clamped);
        expect(m.backend.events, isEmpty);
        expect(writeBacks(), [
          [
            1,
            {'selection': _collapsed(8)}
          ]
        ]);
        expect(m.root.get('selection'), _collapsed(8));

        // Once Ruby's copy matches, other updates write nothing back.
        m.backend.updates.clear();
        m.backend.updateControl(1, {'read_only': true}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();
        expect(m.backend.updates, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets(
          'a Ruby selection of nil keeps the editor selection and writes '
          'nothing back', (tester) async {
        final m = await mount(tester);
        editable(tester).controller.selection =
            const TextSelection.collapsed(offset: 7);
        await tester.pump();
        m.backend.events.clear();
        m.backend.updates.clear();

        m.backend.updateControl(1, {'selection': null}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.selection,
            const TextSelection.collapsed(offset: 7));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a Ruby value and selection sent together both apply',
          (tester) async {
        final m = await mount(tester, {'value': 'puts :hello_world'});
        editable(tester).controller.selection =
            const TextSelection.collapsed(offset: 10);
        await tester.pump();
        m.backend.events.clear();
        m.backend.updates.clear();

        m.backend.updateControl(
            1,
            {
              'value': 'x = 1',
              'selection': {'base_offset': 0, 'extent_offset': 1},
            },
            notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 0, extentOffset: 1));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
