import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart' as fce;
import 'package:highlight/languages/all.dart';

import 'utils/code_editor.dart';
import 'utils/ruflet_code_controller.dart';
import 'cupertino_code_editor.dart';
import 'material_code_editor.dart';

class CodeEditorControl extends StatefulWidget {
  final Control control;

  const CodeEditorControl({super.key, required this.control});

  @override
  State<CodeEditorControl> createState() => _CodeEditorControlState();
}

class _CodeEditorControlState extends State<CodeEditorControl> {
  late RufletCodeController _controller;
  late final FocusNode _focusNode;
  bool _didAutoFocus = false;
  TextSelection? _selection;
  String _value = "";
  String? _languageName;
  bool _applyingRubyChange = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _controller = _createController();
    _value = _readValue();
    _selection = _controller.selection;
    _controller.addListener(_handleControllerChange);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("CodeEditor.$name($args)");
    switch (name) {
      case "focus":
        _focusNode.requestFocus();
        break;
      case "fold_comment_at_line_zero":
        _controller.foldCommentAtLineZero();
        break;
      case "fold_imports":
        _controller.foldImports();
        break;
      case "fold_at":
        final line = parseInt(args["line_number"]);
        if (line != null) {
          _controller.foldAt(line);
        }
        break;
      default:
        throw Exception("Unknown CodeEditor method: $name");
    }
  }

  void _onFocusChange() {
    widget.control.triggerEvent(_focusNode.hasFocus ? "focus" : "blur");
  }

  RufletCodeController _createController() {
    _languageName = widget.control.get("language", "")!;
    return RufletCodeController(
      text: _initialValueFromControl(),
      language: highlightEntry(allLanguages, _languageName),
    );
  }

  String _initialValueFromControl() {
    return widget.control.getString("value") ?? "";
  }

  List<String>? _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  String _readValue() => _controller.fullText;

  void _setValue(String value) {
    _controller.fullText = value;
  }

  /// Applies a value, selection or language Ruby set. It is Ruby's own
  /// change, not the user's, so it is not reported as on_change or
  /// on_selection_change and the value is not written back. (The core
  /// TextField also does not report a Ruby value as on_change, but it does
  /// report a selection Ruby sets as on_selection_change.)
  void _applyRubyChange(VoidCallback change) {
    _applyingRubyChange = true;
    try {
      change();
    } finally {
      _applyingRubyChange = false;
      _value = _readValue();
      _selection = _controller.selection;
    }
  }

  /// Writes back the selection the editor uses when Ruby's copy no longer
  /// matches it, so Ruby does not keep offsets past the end of its own value.
  void _writeBackSelection() {
    final selection =
        _controller.selection.isValid ? _controller.selection : null;
    if (widget.control.getTextSelection("selection") != selection) {
      widget.control.updateProperties({"selection": selection?.toMap()});
    }
  }

  void _handleControllerChange() {
    if (_applyingRubyChange) return;
    final value = _readValue();
    final selection = _controller.selection;
    final selectionChanged = selection != _selection;
    final valueChanged = value != _value;

    if (!valueChanged && !selectionChanged) {
      return;
    }

    _value = value;
    _selection = selection;

    final updates = <String, dynamic>{};

    if (valueChanged) {
      updates["value"] = value;
    }

    if (selectionChanged) {
      if (selection.isValid) {
        updates["selection"] = selection.toMap();
      } else {
        updates["selection"] = null;
      }
    }

    if (updates.isNotEmpty) {
      widget.control.updateProperties(updates);
    }

    if (valueChanged && widget.control.getBool("on_change", false)!) {
      widget.control.triggerEvent("change", value);
    }

    if (selectionChanged && selection.isValid) {
      final visibleText = _controller.text;
      widget.control.triggerEvent("selection_change", {
        "selected_text": visibleText.substring(selection.start, selection.end),
        "selection": selection.toMap(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CodeEditor build: ${widget.control.id}");

    final languageName = widget.control.get("language", "")!;
    if (languageName != _languageName) {
      final previousSelection = _controller.selection;
      _controller.removeListener(_handleControllerChange);
      _controller.dispose();
      _controller = _createController();
      _controller.addListener(_handleControllerChange);
      _applyRubyChange(() {
        if (previousSelection.isValid) {
          _controller.selection = previousSelection;
        }
      });
    }

    final value = widget.control.getString("value");
    final controllerValue = _readValue();
    final valueChanged = value != null && value != controllerValue;
    if (valueChanged) {
      _applyRubyChange(() => _setValue(value));
    }

    final explicitSelection = widget.control.getTextSelection(
      "selection",
      minOffset: 0,
      maxOffset: _controller.text.length,
    );
    if (explicitSelection != null &&
        explicitSelection != _controller.selection) {
      _applyRubyChange(() => _controller.selection = explicitSelection);
    }
    // Ruby's selection had to be clamped to the text: Ruby set a shorter
    // value or a selection past the end. (Setting a value clears the
    // controller's selection, so the cursor after a Ruby value is always
    // Ruby's selection, clamped.)
    if (explicitSelection != widget.control.getTextSelection("selection")) {
      _writeBackSelection();
    }

    final autofocus = widget.control.getBool("autofocus", false)!;
    if (!_didAutoFocus && autofocus) {
      _didAutoFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).autofocus(_focusNode);
        }
      });
    }

    final themeData = parseCodeThemeData(widget.control, context);
    final gutterStyle = parseGutterStyle(widget.control, context);
    final autocompleteEnabled = widget.control.getBool("autocomplete", false)!;
    final autocompleteWords =
        _stringList(widget.control.get("autocomplete_words")) ?? const [];
    _controller.autocompletionEnabled = autocompleteEnabled;
    if (autocompleteEnabled) {
      _controller.autocompleter.setCustomWords(autocompleteWords);
    } else {
      _controller.autocompleter.setCustomWords(const []);
      _controller.popupController.hide();
    }

    Widget editor = PlatformControlRenderer(
      material: (_) => MaterialCodeEditorRenderer(
        control: widget.control,
        controller: _controller,
        focusNode: _focusNode,
        gutterStyle: gutterStyle,
      ),
      cupertino: (_) => CupertinoCodeEditorRenderer(
        control: widget.control,
        controller: _controller,
        focusNode: _focusNode,
        gutterStyle: gutterStyle,
      ),
    );

    if (themeData != null) {
      editor = fce.CodeTheme(data: themeData, child: editor);
    }

    return LayoutControl(control: widget.control, child: editor);
  }
}
