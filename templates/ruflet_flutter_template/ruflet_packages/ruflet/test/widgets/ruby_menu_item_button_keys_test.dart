import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
  pageUri: Uri.parse('inprocess://menu-item-button-keys-test'),
  assetsDir: '',
  extensions: [],
  multiView: false,
)..platform = platform;

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

Future<void> _pumpItem(WidgetTester tester, TargetPlatform platform) async {
  final backend = _backend(platform);
  // Mirrors Ruflet.menu_item_button("Save", semantic_label:, trailing:).
  final control = Control.fromMap({
    '_c': 'MenuItemButton',
    '_i': 1,
    'content': 'Save',
    'semantic_label': 'Save file',
    'trailing': {'_c': 'Text', '_i': 2, 'value': 'Ctrl+S'},
    'on_click': true,
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
  expect(tester.takeException(), isNull);
}

Finder _labelled(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform MenuItemButton renders Ruby trailing', (
      tester,
    ) async {
      await _pumpItem(tester, platform);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Ctrl+S'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Ctrl+S')).dx,
        greaterThan(tester.getTopRight(find.text('Save')).dx),
      );
    });

    testWidgets('$platform MenuItemButton honors Ruby semantic_label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpItem(tester, platform);
      expect(_labelled('Save file'), findsOneWidget);
      expect(find.bySemanticsLabel('Save file'), findsOneWidget);
      if (platform == TargetPlatform.android) {
        final item = tester.widget<material.MenuItemButton>(
          find.byType(material.MenuItemButton),
        );
        expect(item.semanticsLabel, 'Save file');
        expect(item.trailingIcon, isNotNull);
      }
      handle.dispose();
    });
  }
}
