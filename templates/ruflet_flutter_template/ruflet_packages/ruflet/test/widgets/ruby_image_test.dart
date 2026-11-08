import 'dart:convert';
import 'dart:typed_data';

import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Two different 1x1 PNGs, so a test can tell which source was rendered.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
const _otherPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1EAAAAASUVORK5CYII=';

Future<void> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> props) async {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://image-test'),
      assetsDir: '',
      extensions: [],
      multiView: false)
    ..platform = platform;
  final control = Control.fromMap(
      {'_c': 'Image', '_i': 1, 'width': 10, 'height': 10, ...props}, backend);
  final body = Center(child: ControlWidget(control: control));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  await tester.pump();
}

Uint8List _renderedBytes(WidgetTester tester) {
  final provider = tester.widget<Image>(find.byType(Image)).image;
  expect(provider, isA<MemoryImage>());
  return (provider as MemoryImage).bytes;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final design = platform == TargetPlatform.iOS ? 'Cupertino' : 'Material';

    testWidgets('$design Image renders Ruby src_base64 without src',
        (tester) async {
      await _pump(tester, platform, {'src_base64': _png});
      expect(find.byType(ErrorControl), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(_renderedBytes(tester), base64Decode(_png));
      expect(tester.getSize(find.byType(Image)), const Size(10, 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design Image accepts a data URI and raw bytes in src_base64',
        (tester) async {
      await _pump(
          tester, platform, {'src_base64': 'data:image/png;base64,$_png'});
      expect(find.byType(ErrorControl), findsNothing);
      expect(_renderedBytes(tester), base64Decode(_png));

      await _pump(tester, platform, {'src_base64': base64Decode(_png)});
      expect(find.byType(ErrorControl), findsNothing);
      expect(_renderedBytes(tester), base64Decode(_png));
    });

    testWidgets('$design Image prefers src over src_base64', (tester) async {
      await _pump(tester, platform, {'src': _otherPng, 'src_base64': _png});
      expect(_renderedBytes(tester), base64Decode(_otherPng));
    });

    testWidgets('$design Image without src or src_base64 shows an error',
        (tester) async {
      await _pump(tester, platform, {});
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  }
}
