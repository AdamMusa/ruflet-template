import 'dart:io';

import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as upstream;
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
            child: SingleChildScrollView(
                child: SizedBox(width: 350, child: child))),
      ),
    );

void expectNativeTree() {
  expect(find.byType(material.Material), findsNothing);
  expect(find.byType(material.Theme), findsNothing);
  expect(find.byType(material.TextField), findsNothing);
  expect(find.byType(material.InkWell), findsNothing);
  expect(find.byType(material.DropdownButton<native.ColorLabelType>),
      findsNothing);
}

void main() {
  testWidgets('hex editing, labels and history retain picker behavior',
      (tester) async {
    Color? color;
    HSVColor? hsv;
    List<Color>? history;
    await tester.pumpWidget(host(native.ColorPicker(
      pickerColor: const Color(0xffff0000),
      onColorChanged: (value) => color = value,
      onHsvColorChanged: (value) => hsv = value,
      onHistoryChanged: (value) => history = value,
      portraitOnly: true,
      hexInputBar: true,
      enableAlpha: true,
    )));
    expectNativeTree();
    await tester.enterText(find.byType(CupertinoTextField), '#12345680');
    await tester.pump();
    expect(color, const Color(0x80123456));
    expect(hsv?.toColor(), color);
    await tester.tap(find.byType(native.ColorIndicator).first);
    await tester.pump();
    expect(history, [const Color(0x80123456)]);
    await tester.tap(find.text('RGB'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('HSL').last);
    await tester.pumpAndSettle();
    expect(find.text('HSL'), findsOneWidget);
    expectNativeTree();
  });

  testWidgets(
      'block and multiple-choice pickers select the same palette values',
      (tester) async {
    const red = Color(0xffff0000);
    const blue = Color(0xff0000ff);
    Color? color;
    await tester.pumpWidget(host(native.BlockPicker(
      pickerColor: red,
      availableColors: const [red, blue],
      onColorChanged: (value) => color = value,
    )));
    await tester.tap(find.byType(CupertinoButton).at(1));
    await tester.pump();
    expect(color, blue);
    expectNativeTree();
    List<Color>? colors;
    await tester.pumpWidget(host(native.MultipleChoiceBlockPicker(
      pickerColors: [red],
      availableColors: const [red, blue],
      onColorsChanged: (value) => colors = value,
    )));
    await tester.tap(find.byType(CupertinoButton).at(1));
    await tester.pump();
    expect(colors, [red, blue]);
    await tester.tap(find.byType(CupertinoButton).first);
    await tester.pump();
    expect(colors, [blue]);
    expectNativeTree();
  });

  testWidgets('ring, sliders and swatches build without Material descendants',
      (tester) async {
    final pickers = <Widget>[
      native.HueRingPicker(
          pickerColor: const Color(0xff123456), onColorChanged: (_) {}),
      native.SlidePicker(
          pickerColor: const Color(0xff123456), onColorChanged: (_) {}),
      native.CupertinoSwatchPicker(
          pickerColor: const Color(0xff123456), onColorChanged: (_) {}),
    ];
    for (final picker in pickers) {
      await tester.pumpWidget(host(picker));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expectNativeTree();
    }
  });

  testWidgets('Material renderer retains the upstream input and dropdown',
      (tester) async {
    await tester.pumpWidget(material.MaterialApp(
        home: material.Scaffold(
      body: SingleChildScrollView(
          child: upstream.ColorPicker(
        pickerColor: const Color(0xffff0000),
        onColorChanged: (_) {},
        portraitOnly: true,
        hexInputBar: true,
      )),
    )));
    expect(find.byType(material.TextField), findsOneWidget);
    expect(find.byType(material.DropdownButton<upstream.ColorLabelType>),
        findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
  });

  test('native picker source has no Material library or theme dependency', () {
    final source = Directory('lib/src/cupertino_picker')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in source) {
      final contents = file.readAsStringSync();
      expect(
          contents, isNot(contains("import 'package:flutter/material.dart'")),
          reason: file.path);
      expect(contents, isNot(matches(r'(?<!Cupertino)Theme\.of\(context\)')),
          reason: file.path);
    }
  });
}
