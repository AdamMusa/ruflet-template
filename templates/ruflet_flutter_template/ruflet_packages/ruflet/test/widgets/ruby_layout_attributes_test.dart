import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/container.dart';
import 'package:ruflet/src/controls/cupertino_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RufletBackend backendFor(TargetPlatform platform) => RufletBackend(
      pageUri: Uri.parse('inprocess://attribute-test'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    )..platform = platform;

Widget host(RufletBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: body),
  );
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final animation in [
      <String, dynamic>{},
      {'animate': 200},
      {'animate_size': 200, 'animate_margin': 200}
    ]) {
      for (final ink in [false, true]) {
        testWidgets(
            '$platform: Ruby container geometry applies once ($animation, ink=$ink)',
            (tester) async {
          final backend = backendFor(platform);
          final control = Control.fromMap({
            '_c': 'Container',
            '_i': 1,
            ...animation,
            'ink': ink,
            'on_click': ink,
            'width': 200,
            'height': 80,
            'margin': {'left': 12, 'top': 18, 'right': 16, 'bottom': 22},
            'padding': {'left': 8, 'top': 6, 'right': 4, 'bottom': 2},
            'alignment': {'x': -1, 'y': -1},
            'bgcolor': '#123456',
            'content': {'_c': 'Text', '_i': 2, 'value': 'Ruby layout'},
          }, backend);
          await tester
              .pumpWidget(host(backend, ControlWidget(control: control)));
          final decoration = find
              .descendant(
                of: find.byType(ContainerControl),
                matching: find.byType(DecoratedBox),
              )
              .first;
          expect(
              tester.getRect(decoration), const Rect.fromLTWH(12, 18, 200, 80));
          expect(tester.getTopLeft(find.text('Ruby layout')),
              const Offset(20, 24));
          expect(tester.getSize(find.byType(ContainerControl)),
              const Size(228, 120));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('Cupertino reads the canonical Ruby text input attributes',
      (tester) async {
    final backend = backendFor(TargetPlatform.iOS);
    final control = Control.fromMap({
      '_c': 'TextField',
      '_i': 1,
      'value': '',
      'hint_text': 'https://example.test',
      'hint_style': {'size': 19, 'color': '#123456'},
      'prefix_icon': {'_c': 'Text', '_i': 2, 'value': 'prefix'},
      'suffix_icon': {'_c': 'Text', '_i': 3, 'value': 'suffix'},
      'content_padding': {'left': 17, 'top': 11, 'right': 13, 'bottom': 7},
      'keyboard_type': 'url',
      'autocorrect': false,
      'text_align': 'right',
    }, backend);
    await tester.pumpWidget(host(backend, ControlWidget(control: control)));
    expect(find.byType(CupertinoTextFieldControl), findsOneWidget);
    final field =
        tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(field.placeholder, 'https://example.test');
    expect(field.placeholderStyle?.fontSize, 19);
    expect(field.placeholderStyle?.color, const Color(0xff123456));
    expect(field.padding, const EdgeInsets.fromLTRB(17, 11, 13, 7));
    expect(field.keyboardType, TextInputType.url);
    expect(field.autocorrect, isFalse);
    expect(field.textAlign, TextAlign.right);
    expect(find.text('prefix'), findsOneWidget);
    expect(find.text('suffix'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
