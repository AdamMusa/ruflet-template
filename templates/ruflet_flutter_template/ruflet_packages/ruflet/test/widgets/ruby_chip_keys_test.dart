import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
  pageUri: Uri.parse('inprocess://chip-keys-test'),
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

Future<void> _pumpChip(WidgetTester tester, TargetPlatform platform) async {
  final backend = _backend(platform);
  final control = Control.fromMap({
    '_c': 'Chip',
    '_i': 1,
    'label': {'_c': 'Text', '_i': 2, 'value': 'tag'},
    'on_delete': true,
    'delete_icon_tooltip': 'Remove tag',
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Material Chip honors Ruby delete_icon_tooltip', (tester) async {
    await _pumpChip(tester, TargetPlatform.android);
    final chip = tester.widget<material.RawChip>(find.byType(material.RawChip));
    expect(chip.deleteButtonTooltipMessage, 'Remove tag');
    expect(find.byTooltip('Remove tag'), findsOneWidget);
  });

  testWidgets('Cupertino Chip exposes Ruby delete_icon_tooltip to semantics', (
    tester,
  ) async {
    await _pumpChip(tester, TargetPlatform.iOS);
    final deleteButton = find.ancestor(
      of: find.byIcon(CupertinoIcons.xmark_circle_fill),
      matching: find.byType(CupertinoButton),
    );
    expect(
      find.ancestor(
        of: deleteButton,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.tooltip == 'Remove tag',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(material.Tooltip), findsNothing);
  });
}
