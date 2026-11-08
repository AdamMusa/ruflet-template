// Ruby's TextField on_paste_files (Flet 1.0.3): on native platforms the
// keyboard paste shortcut pastes text as usual and reports an image on the
// clipboard as a paste_files event, on both TextField renderers.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/utils/pasted_file.dart';

import '../support/control_harness.dart';

final _png = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D]);

/// The system clipboard: [text] for Clipboard.getData and [image] for the
/// pasteboard plugin. Returns the number of image reads so far.
int Function() _clipboard(WidgetTester tester,
    {String? text, Uint8List? image}) {
  var imageReads = 0;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    switch (call.method) {
      case 'Clipboard.getData':
        return text == null ? null : {'text': text};
      case 'Clipboard.hasStrings':
        return {'value': text != null};
    }
    return null;
  });
  const pasteboard = MethodChannel('pasteboard');
  messenger.setMockMethodCallHandler(pasteboard, (call) async {
    if (call.method == 'image') {
      imageReads++;
      return image;
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(pasteboard, null);
  });
  return () => imageReads;
}

Map<String, dynamic> _field(
        {bool onPasteFiles = true, bool shiftEnter = false}) =>
    {
      '_c': 'TextField',
      '_i': 1,
      'width': 300,
      'value': '',
      'on_change': true,
      if (onPasteFiles) 'on_paste_files': true,
      if (shiftEnter) 'shift_enter': true,
    };

Future<void> _focus(WidgetTester tester) async {
  await tester.tap(find.byType(EditableText));
  await tester.pumpAndSettle();
}

Future<void> _pasteShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

List<SentMessage> _pastes(HarnessMount mount) => [
      for (final m in mount.backend.sent)
        if (m.name == 'paste_files') m
    ];

String _text(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  test('a clipboard image is named and typed from its bytes', () {
    PastedFile image(List<int> bytes) =>
        PastedFile.image(Uint8List.fromList([...bytes, 0, 0, 0, 0, 0, 0, 0]));
    expect(image([0x89, 0x50, 0x4E, 0x47]).name, 'image.png');
    expect(image([0x89, 0x50, 0x4E, 0x47]).mimeType, 'image/png');
    expect(image([0xFF, 0xD8, 0xFF]).mimeType, 'image/jpeg');
    expect(image([0x47, 0x49, 0x46, 0x38]).name, 'image.gif');
    expect(
        image([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50])
            .mimeType,
        'image/webp');
    expect(image([0x4D, 0x4D, 0x00, 0x2A]).mimeType, 'image/tiff');
    expect(image([0x42, 0x4D]).mimeType, 'image/bmp');
    expect(image([1, 2, 3]).name, 'image.png', reason: 'PNG by default');
    final file = PastedFile.image(_png);
    expect(file.toMap(),
        {'name': 'image.png', 'mime_type': 'image/png', 'bytes': _png});
  });

  for (final design in HarnessDesign.values) {
    testWidgets(
        '${design.name}: pasting reports the clipboard image and the text',
        (tester) async {
      _clipboard(tester, text: 'hello', image: _png);
      final mount = await mountWire(tester, design, _field());
      await _focus(tester);

      await _pasteShortcut(tester);

      expect(_text(tester), 'hello', reason: 'text pastes as usual');
      expect(mount.control(1).getString('value'), 'hello');
      final pastes = _pastes(mount);
      expect(pastes, hasLength(1));
      expect(pastes.single.id, 1);
      expect(pastes.single.data, {
        'files': [
          {'name': 'image.png', 'mime_type': 'image/png', 'bytes': _png}
        ]
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets('${design.name}: a paste without an image reports nothing',
        (tester) async {
      final imageReads = _clipboard(tester, text: 'plain');
      final mount = await mountWire(tester, design, _field());
      await _focus(tester);

      await _pasteShortcut(tester);

      expect(_text(tester), 'plain');
      expect(imageReads(), 1);
      expect(_pastes(mount), isEmpty);
    });

    testWidgets('${design.name}: an image alone is reported, nothing typed',
        (tester) async {
      _clipboard(tester, image: _png);
      final mount = await mountWire(tester, design, _field(shiftEnter: true));
      await _focus(tester);

      await _pasteShortcut(tester);

      expect(_text(tester), isEmpty);
      expect(_pastes(mount), hasLength(1));
    });

    testWidgets('${design.name}: unsubscribed fields only paste text',
        (tester) async {
      final imageReads = _clipboard(tester, text: 'hello', image: _png);
      final mount =
          await mountWire(tester, design, _field(onPasteFiles: false));
      await _focus(tester);

      await _pasteShortcut(tester);

      expect(_text(tester), 'hello');
      expect(imageReads(), 0, reason: 'the clipboard image is not read');
      expect(_pastes(mount), isEmpty);
    });

    testWidgets('${design.name}: subscribing later keeps the focused field',
        (tester) async {
      _clipboard(tester, text: 'x', image: _png);
      final mount =
          await mountWire(tester, design, _field(onPasteFiles: false));
      await _focus(tester);
      final editable = tester.state(find.byType(EditableText));

      mount.control(1).update({'on_paste_files': true}, shouldNotify: true);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(editable));
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      await _pasteShortcut(tester);
      expect(_pastes(mount), hasLength(1));
    });
  }
}
