import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

Future<void> _pumpDropdown(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> props,
) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://dropdown-keys-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = platform;
  final control = Control.fromMap({
    '_c': 'Dropdown',
    '_i': 1,
    'options': [
      {'_c': 'DropdownOption', '_i': 2, 'key': 'a', 'text': 'Apples'},
      {'_c': 'DropdownOption', '_i': 3, 'key': 'b', 'text': 'Bananas'},
    ],
    ...props,
  }, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, child: ControlWidget(control: control)),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

const _suffix = {'_c': 'Text', '_i': 9, 'value': 'kg'};

void main() {
  testWidgets('Material Dropdown honors Ruby expanded_insets', (tester) async {
    await _pumpDropdown(tester, TargetPlatform.android, {
      'expanded_insets': {'left': 8, 'top': 0, 'right': 16, 'bottom': 0},
    });
    final menu = tester.widget<material.DropdownMenu<String>>(
      find.byType(material.DropdownMenu<String>),
    );
    expect(menu.expandedInsets, const EdgeInsets.only(left: 8, right: 16));
    // Expanded menus fill the parent minus the insets.
    expect(tester.getSize(find.byType(material.TextField)).width, 376);
  });

  testWidgets('Material Dropdown honors Ruby hover_color', (tester) async {
    await _pumpDropdown(tester, TargetPlatform.android, {
      'filled': true,
      'hover_color': '#ff0000',
    });
    final field = tester.widget<material.TextField>(
      find.byType(material.TextField),
    );
    expect(field.decoration?.hoverColor, const Color(0xffff0000));
  });

  testWidgets('Material Dropdown honors Ruby selected_suffix', (tester) async {
    await _pumpDropdown(tester, TargetPlatform.android, {
      'value': 'a',
      'label': 'Fruit',
      'helper_text': 'Pick one',
      'selected_suffix': _suffix,
    });
    final field = tester.widget<material.TextField>(
      find.byType(material.TextField),
    );
    expect(field.decoration?.suffix, isNotNull);
    expect(find.text('kg'), findsOneWidget);
    // The decoration still carries the Ruby label and helper text.
    // (DropdownMenu also lays the decoration out offstage to size itself.)
    expect(field.decoration?.label, isNotNull);
    expect(field.decoration?.helperText, 'Pick one');
    expect(find.text('Fruit'), findsWidgets);
    expect(
      field.decoration?.suffixIcon,
      isNotNull,
      reason: 'the menu arrow button is kept',
    );
  });

  testWidgets('Cupertino Dropdown shows Ruby selected_suffix after a choice', (
    tester,
  ) async {
    await _pumpDropdown(tester, TargetPlatform.iOS, {
      'value': 'a',
      'selected_suffix': _suffix,
    });
    expect(find.text('Apples'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('kg')).dx,
      greaterThan(tester.getTopRight(find.text('Apples')).dx),
    );
  });

  testWidgets('Cupertino Dropdown hides selected_suffix without a choice', (
    tester,
  ) async {
    await _pumpDropdown(tester, TargetPlatform.iOS, {
      'selected_suffix': _suffix,
    });
    expect(find.text('kg'), findsNothing);
  });
}
