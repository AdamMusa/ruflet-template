// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'pasted_file.dart';

/// Listens to the browser's paste events, which reach every browser
/// (Safari included) with no clipboard permission prompt: a paste that
/// carries files while [isFocused] is reported to [onFiles] and not
/// inserted as text. Returns the handle [stopListeningForPastedFiles] takes.
Object? listenForPastedFiles(
    bool Function() isFocused, void Function(List<PastedFile>) onFiles) {
  final listener = ((web.ClipboardEvent event) {
    if (!isFocused()) return;
    final fileList = event.clipboardData?.files;
    if (fileList == null || fileList.length == 0) return;
    event.preventDefault();
    final files = <web.File>[
      for (var i = 0; i < fileList.length; i++)
        if (fileList.item(i) case final file?) file
    ];
    _read(files).then(onFiles);
  }).toJS;
  // Capture, so the field's own text input does not see the paste first.
  web.document.addEventListener('paste', listener, true.toJS);
  return listener;
}

void stopListeningForPastedFiles(Object? handle) {
  if (handle is JSFunction) {
    web.document.removeEventListener('paste', handle, true.toJS);
  }
}

Future<List<PastedFile>> _read(List<web.File> files) async {
  final result = <PastedFile>[];
  for (final file in files) {
    final buffer = await file.arrayBuffer().toDart;
    result.add(PastedFile(
        name: file.name,
        mimeType: file.type,
        bytes: buffer.toDart.asUint8List()));
  }
  return result;
}
