import 'package:ruflet/ruflet.dart';
import 'package:ruflet_code_editor/src/code_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class RecordingBackend extends RufletBackend {
  final events = <List<dynamic>>[];
  RecordingBackend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }
  @override
  void triggerControlEventById(int id, String name, [dynamic data]) =>
      events.add([id, name, data]);
  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    if (dart) controlsIndex.get(id)?.update(props, shouldNotify: notify);
  }
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        '$platform shared CodeEditor wire events and properties stay compatible',
        (tester) async {
      final backend = RecordingBackend(platform);
      final control = Control.fromMap({
        '_i': 1,
        '_c': 'CodeEditor',
        'value': 'hello',
        'language': 'javascript',
        'on_change': true,
        'on_selection_change': true,
        'on_focus': true,
        'on_blur': true,
      }, backend);
      final child = Center(
          child: SizedBox(
              width: 600,
              height: 350,
              child: CodeEditorControl(control: control)));
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: platform == TargetPlatform.iOS
              ? CupertinoApp(home: CupertinoPageScaffold(child: child))
              : material.MaterialApp(home: material.Scaffold(body: child))));
      await tester.pump();
      final field = platform == TargetPlatform.iOS
          ? find.byType(CupertinoTextField)
          : find.byType(material.TextField);
      await tester.tap(field);
      await tester.pump();
      expect(backend.events, contains(equals([1, 'focus', null])));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();
      final selectionEvent =
          backend.events.lastWhere((e) => e[1] == 'selection_change');
      expect(selectionEvent[2]['selected_text'], 'hello');
      await tester.enterText(field, 'changed');
      await tester.pump();
      expect(control.getString('value'), 'changed');
      expect(backend.events, contains(equals([1, 'change', 'changed'])));
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(material.Theme), findsNothing);
        expect(find.byType(material.Material), findsNothing);
        expect(find.byType(material.TextField), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    });
  }
}
