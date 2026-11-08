import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pasteboard/pasteboard.dart';

import '../utils/paste_files_web.dart'
    if (dart.library.io) '../utils/paste_files_io.dart';
import '../utils/pasted_file.dart';

/// Reports files pasted into the text field below it (Ruby's and Flet's
/// TextField.on_paste_files) to [onPaste] while [enabled]:
///
/// - Web: the browser's paste event while [focusNode] has focus. A paste
///   that carries files is not also inserted as text.
/// - Elsewhere: the keyboard paste shortcut (Ctrl/Cmd+V, PasteTextIntent)
///   pastes text as usual and reports an image on the clipboard. The text
///   selection toolbar's Paste button pastes text only.
///
/// The child keeps its place in the tree whether or not [enabled] is set,
/// so attaching the handler later keeps the field's state.
class PasteFilesScope extends StatefulWidget {
  final bool enabled;
  final FocusNode focusNode;
  final ValueChanged<List<PastedFile>> onPaste;
  final Widget child;

  const PasteFilesScope(
      {super.key,
      required this.enabled,
      required this.focusNode,
      required this.onPaste,
      required this.child});

  @override
  State<PasteFilesScope> createState() => _PasteFilesScopeState();
}

class _PasteFilesScopeState extends State<PasteFilesScope> {
  late final _PasteFilesAction _action = _PasteFilesAction(_reportImage);
  Object? _webListener;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _syncWebListener();
  }

  @override
  void didUpdateWidget(covariant PasteFilesScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWebListener();
  }

  @override
  void dispose() {
    _stopWebListener();
    super.dispose();
  }

  void _syncWebListener() {
    final listen = kIsWeb && widget.enabled;
    if (listen == _listening) return;
    if (listen) {
      _webListener = listenForPastedFiles(
          () => mounted && widget.focusNode.hasFocus, _report);
      _listening = true;
    } else {
      _stopWebListener();
    }
  }

  void _stopWebListener() {
    if (!_listening) return;
    stopListeningForPastedFiles(_webListener);
    _webListener = null;
    _listening = false;
  }

  void _report(List<PastedFile> files) {
    if (mounted && widget.enabled && files.isNotEmpty) widget.onPaste(files);
  }

  Future<void> _reportImage() async {
    Uint8List? bytes;
    try {
      bytes = await Pasteboard.image;
    } catch (e) {
      // No clipboard image support (or plugin) on this platform.
      debugPrint("PasteFilesScope: cannot read the clipboard image: $e");
      return;
    }
    if (bytes != null && bytes.isNotEmpty) _report([PastedFile.image(bytes)]);
  }

  @override
  Widget build(BuildContext context) => Actions(
        actions: widget.enabled && !kIsWeb
            ? <Type, Action<Intent>>{PasteTextIntent: _action}
            : const <Type, Action<Intent>>{},
        child: widget.child,
      );
}

/// Overrides the text field's paste action: runs it (the text pastes as
/// usual), then reports a clipboard image.
class _PasteFilesAction extends Action<PasteTextIntent> {
  final Future<void> Function() reportImage;

  _PasteFilesAction(this.reportImage);

  @override
  Object? invoke(PasteTextIntent intent) {
    final result = callingAction?.invoke(intent);
    reportImage();
    return result;
  }

  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? false;

  @override
  bool consumesKey(PasteTextIntent intent) =>
      callingAction?.consumesKey(intent) ?? false;
}
