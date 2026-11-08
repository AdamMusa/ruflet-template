import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
      pageUri: Uri.parse('inprocess://expansion-panel-keys-test'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    )..platform = platform;

Widget _host(RufletBackend backend, Widget child) {
  // Material ExpansionPanelList is a ListBody: it needs an unbounded height.
  final body = SingleChildScrollView(child: child);
  return ChangeNotifierProvider.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

Future<void> _pumpPanels(WidgetTester tester, TargetPlatform platform) async {
  final backend = _backend(platform);
  final control = Control.fromMap({
    '_c': 'ExpansionPanelList',
    '_i': 1,
    'width': 300,
    'expand_icon_color': '#ff0000',
    'controls': [
      {
        '_c': 'ExpansionPanel',
        '_i': 2,
        'header': {'_c': 'Text', '_i': 3, 'value': 'Header'},
        'content': {'_c': 'Text', '_i': 4, 'value': 'Body'},
      },
    ],
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
  expect(tester.takeException(), isNull);
}

const _red = Color(0xffff0000);

void main() {
  testWidgets('Material ExpansionPanelList honors Ruby expand_icon_color', (
    tester,
  ) async {
    await _pumpPanels(tester, TargetPlatform.android);
    final list = tester.widget<material.ExpansionPanelList>(
      find.byType(material.ExpansionPanelList),
    );
    expect(list.expandIconColor, _red);
    final icon = tester.widget<material.ExpandIcon>(
      find.byType(material.ExpandIcon),
    );
    expect(icon.color, _red);
  });

  testWidgets('Cupertino ExpansionPanelList honors Ruby expand_icon_color', (
    tester,
  ) async {
    await _pumpPanels(tester, TargetPlatform.iOS);
    final chevron = tester.widget<Icon>(
      find.byIcon(CupertinoIcons.chevron_down),
    );
    expect(chevron.color, _red);
  });
}
