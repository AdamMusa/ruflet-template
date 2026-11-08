import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/autofill.dart';
import '../utils/borders.dart';
import '../utils/box.dart';
import '../utils/colors.dart';
import '../utils/cupertino_enums.dart';
import '../utils/cupertino_theme.dart';
import '../utils/edge_insets.dart';
import '../utils/input.dart';
import '../utils/gradient.dart';
import '../utils/images.dart';
import '../utils/layout.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../utils/platform.dart';
import '../utils/style_theme.dart';
import '../utils/text.dart';
import '../utils/pasted_file.dart';
import '../utils/textfield.dart';
import '../utils/platform_theme.dart';
import '../widgets/paste_files_scope.dart';
import 'base_controls.dart';

class CupertinoTextFieldControl extends StatefulWidget {
  final Control control;

  CupertinoTextFieldControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CupertinoTextFieldControl> createState() =>
      _CupertinoTextFieldControlState();
}

class _CupertinoTextFieldControlState extends State<CupertinoTextFieldControl> {
  Widget? _inputAffix(String side) {
    final icon = widget.control.buildIconOrWidget('${side}_icon');
    final text = widget.control.buildTextOrWidget(side,
        textStyle: widget.control
            .getTextStyle('${side}_style', cupertinoStyleTheme(context)));
    if (icon == null) return text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        if (text != null) ...[const SizedBox(width: 6), text],
      ]),
    );
  }

  String _value = "";
  bool _focused = false;
  bool _revealPassword = false;
  late TextEditingController _controller;
  late final FocusNode _focusNode;
  late final FocusNode _shiftEnterfocusNode;
  String? _lastFocusValue;
  String? _lastBlurValue;
  TextSelection? _selection;

  KeyEventResult _handleTextFieldKeyEvent(KeyEvent event,
      {required bool submitOnEnter}) {
    // ignore up/down arrow keys if flag is set
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        widget.control.getBool("ignore_up_down_keys", false)! &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown)) {
      return KeyEventResult.handled;
    }

    // submit on Enter if flag is set and shift is not pressed
    if (submitOnEnter &&
        event is KeyDownEvent &&
        !HardwareKeyboard.instance.isShiftPressed &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      widget.control.triggerEvent("submit");
      return KeyEventResult.handled;
    }

    // let the system handle other key events
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleControllerChange);
    _shiftEnterfocusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent event) =>
          _handleTextFieldKeyEvent(event, submitOnEnter: true),
    );
    _shiftEnterfocusNode.addListener(_onShiftEnterFocusChange);
    _focusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent event) =>
          _handleTextFieldKeyEvent(event, submitOnEnter: false),
    );
    _focusNode.addListener(_onFocusChange);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    _shiftEnterfocusNode.removeListener(_onShiftEnterFocusChange);
    _shiftEnterfocusNode.dispose();
    _focusNode.removeListener(_onFocusChange);
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _focusNode.dispose();
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("CupertinoTextField.$name($args)");
    switch (name) {
      case "focus":
        _activeFocusNode.requestFocus();
      case "blur":
        _focusNode.unfocus();
        _shiftEnterfocusNode.unfocus();
      default:
        throw Exception("Unknown CupertinoTextField method: $name");
    }
  }

  // shift_enter fields render with their own focus node.
  FocusNode get _activeFocusNode =>
      widget.control.getBool("shift_enter", false)!
          ? _shiftEnterfocusNode
          : _focusNode;

  void _onShiftEnterFocusChange() {
    setState(() {
      _focused = _shiftEnterfocusNode.hasFocus;
    });
    widget.control
        .triggerEvent(_shiftEnterfocusNode.hasFocus ? "focus" : "blur");
  }

  // Ruby's on_paste_files (Flet's TextFieldPasteFilesEvent data).
  void _onPasteFiles(List<PastedFile> files) {
    widget.control.triggerEvent(
        "paste_files", {"files": files.map((file) => file.toMap()).toList()});
  }

  void _onFocusChange() {
    setState(() {
      _focused = _focusNode.hasFocus;
    });
    widget.control.triggerEvent(_focusNode.hasFocus ? "focus" : "blur");
  }

  void _handleControllerChange() {
    final selection = _controller.selection;
    if (_selection == selection) return;

    _selection = selection;

    if (!selection.isValid ||
        !widget.control.getBool("on_selection_change", false)!) {
      return;
    }

    widget.control.updateProperties({"selection": selection.toMap()});
    widget.control.triggerEvent("selection_change", {
      "selected_text":
          _controller.text.substring(selection.start, selection.end),
      "selection": selection.toMap()
    });
  }

  /// Maps the Ruby `border` keyword onto the iOS field.
  ///
  /// Absent, or a Border map, keeps the native rounded field. "outline" and
  /// "underline" draw the native hairline (or `border_color`/`border_width`;
  /// width 0 removes it). "underline" has square corners and no fill.
  /// "none" draws nothing, so the field blends into a form row or container.
  /// `bgcolor`, `filled`/`fill_color`, `gradient`, `image` and `shadows`
  /// still paint on any style. Returns null when there is nothing to paint,
  /// which also keeps disabled "none" fields free of a gray box.
  ///
  /// While focused, `focused_border_color`/`focused_border_width` restyle the
  /// drawn border (like Material's focusedBorder, "none" stays borderless) and
  /// `focused_bgcolor` replaces the background. Border styling without a
  /// `border` keyword implies "outline", as on Material.
  BoxDecoration? _decoration(BuildContext context, RufletStyleTheme theme) {
    final native = const CupertinoTextField().decoration!;
    final nativeSide = (native.border! as Border).top;
    final rawBorder = widget.control.get("border");
    var style = rawBorder is String
        ? parseFormFieldInputBorder(rawBorder.replaceAll("_", ""))
        : null;
    if (rawBorder is String && style == null) {
      debugPrint("CupertinoTextField: unknown border \"$rawBorder\"");
    }

    final borderColor = widget.control.getColor("border_color", context);
    final borderWidth = widget.control.getDouble("border_width");
    final focusedBorderColor =
        widget.control.getColor("focused_border_color", context);
    final focusedBorderWidth = widget.control.getDouble("focused_border_width");
    if (rawBorder == null &&
        (borderColor != null ||
            borderWidth != null ||
            focusedBorderColor != null ||
            focusedBorderWidth != null)) {
      style = FormFieldInputBorder.outline;
    }
    final focusColor = _focused ? focusedBorderColor : null;
    final focusWidth = _focused ? focusedBorderWidth : null;
    final side = borderWidth == 0
        ? BorderSide.none
        : nativeSide.copyWith(
            color: focusColor ?? borderColor, width: focusWidth ?? borderWidth);
    final bgcolor = widget.control.getColor("bgcolor", context);
    var color = widget.control.getBool("filled", false)!
        ? widget.control.getColor("fill_color", context) ??
            bgcolor ??
            CupertinoColors.tertiarySystemFill
        : bgcolor;
    if (_focused) {
      color = widget.control.getColor("focused_bgcolor", context) ?? color;
    }
    final gradient = widget.control.getGradient("gradient", theme);
    final image = widget.control.getDecorationImage("image", context);
    final shadows = widget.control.getBoxShadows("shadows", theme);
    final borderRadius = widget.control.getBorderRadius("border_radius");
    BorderRadiusGeometry? radius = borderRadius ?? native.borderRadius;

    BoxBorder? border;
    switch (style) {
      case FormFieldInputBorder.outline:
        border = side == BorderSide.none ? null : Border.fromBorderSide(side);
        color ??= native.color;
      case FormFieldInputBorder.underline:
        border = side == BorderSide.none ? null : Border(bottom: side);
        radius = borderRadius ?? BorderRadius.zero;
      case FormFieldInputBorder.none:
        border = null;
      case null:
        border = rawBorder is Map
            ? _restyleSides(widget.control.getBorder("border", theme),
                focusColor, focusWidth)
            : native.border;
        color ??= native.color;
    }

    if (color == null &&
        border == null &&
        gradient == null &&
        image == null &&
        (shadows == null || shadows.isEmpty)) {
      return null;
    }
    return BoxDecoration(
      color: color,
      gradient: gradient,
      image: image,
      backgroundBlendMode: color != null || gradient != null
          ? widget.control.getBlendMode("blend_mode")
          : null,
      border: border,
      borderRadius: radius,
      boxShadow: shadows,
    );
  }

  /// Applies the focused color/width to every side a Border map draws.
  Border? _restyleSides(Border? border, Color? color, double? width) {
    if (border == null || (color == null && width == null)) return border;
    BorderSide restyle(BorderSide side) => side == BorderSide.none
        ? side
        : side.copyWith(color: color, width: width);
    return Border(
        top: restyle(border.top),
        right: restyle(border.right),
        bottom: restyle(border.bottom),
        left: restyle(border.left));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoTextField build: ${widget.control.id}");
    final theme = cupertinoStyleTheme(context);

    var autofocus = widget.control.getBool("autofocus", false)!;
    var value = widget.control.getString("value", "")!;
    if (_value != value) {
      _value = value;
      _controller.value = TextEditingValue(
        text: value,
        // preserve cursor position at the end
        selection: TextSelection.collapsed(offset: value.length),
      );
      _selection = _controller.selection;
    }

    var shiftEnter = widget.control.getBool("shift_enter", false)!;
    var multiline = widget.control.getBool("multiline", false)! || shiftEnter;
    var minLines = widget.control.getInt("min_lines", 1)!;
    var maxLines = widget.control.getInt("max_lines", multiline ? null : 1);

    var readOnly = widget.control.getBool("read_only", false)!;
    var password = widget.control.getBool("password", false)!;
    var onChange = widget.control.getBool("on_change", false)!;

    var cursorColor = widget.control.getColor("cursor_color", context);
    var selectionColor = widget.control.getColor("selection_color", context);

    var maxLength = widget.control.getInt("max_length");

    var textSize = widget.control.getDouble("text_size");

    var color = widget.control.getColor("color", context);
    var focusedColor = widget.control.getColor("focused_color", context);

    var textStyle = widget.control.getTextStyle("text_style", theme);
    if (textSize != null || color != null || focusedColor != null) {
      textStyle = (textStyle ?? const TextStyle()).copyWith(
          fontSize: textSize, color: _focused ? focusedColor ?? color : color);
    }

    List<TextInputFormatter> inputFormatters = [];
    var inputFilter = widget.control.getTextInputFormatter("input_filter");
    if (inputFilter != null) {
      inputFormatters.add(inputFilter);
    }
    var textCapitalization = widget.control
        .getTextCapitalization("capitalization", TextCapitalization.none)!;
    if (textCapitalization != TextCapitalization.none) {
      inputFormatters.add(TextCapitalizationFormatter(textCapitalization));
    }
    var textAlign = widget.control.getTextAlign("text_align", TextAlign.start)!;
    var textVerticalAlign = widget.control.getDouble("text_vertical_align");
    var rtl = widget.control.getBool("rtl", false)!;
    var autocorrect = widget.control.getBool("autocorrect", true)!;
    var textInputAction =
        widget.control.getTextInputAction("text_input_action");
    FocusNode focusNode = shiftEnter ? _shiftEnterfocusNode : _focusNode;

    var focusValue = widget.control.getString("focus");
    var blurValue = widget.control.getString("blur");
    if (focusValue != null && focusValue != _lastFocusValue) {
      _lastFocusValue = focusValue;
      focusNode.requestFocus();
    }
    if (blurValue != null && blurValue != _lastBlurValue) {
      _lastBlurValue = blurValue;
      _focusNode.unfocus();
    }

    var selection = widget.control.getTextSelection("selection",
        minOffset: 0, maxOffset: _controller.text.length);
    if (selection != null && selection != _controller.selection) {
      _controller.selection = selection;
      _selection = selection;
    }

    var canRevealPassword =
        widget.control.getBool("can_reveal_password", false)!;

    Widget? revealPasswordIcon;
    if (password && canRevealPassword) {
      revealPasswordIcon = Padding(
        padding: const EdgeInsets.only(right: 15.0),
        child: GestureDetector(
            child: Icon(_revealPassword
                ? CupertinoIcons.eye_slash
                : CupertinoIcons.eye),
            onTap: () {
              setState(() {
                _revealPassword = !_revealPassword;
              });
            }),
      );
    }
    var fitParentSize = widget.control.getBool("fit_parent_size", false)!;
    var label = widget.control.get("label");
    String? labelStr;
    if (label is String) {
      labelStr = widget.control.getString("label");
    }

    Widget textField = CupertinoTextField(
        style: textStyle,
        textAlignVertical: textVerticalAlign != null
            ? TextAlignVertical(y: textVerticalAlign)
            : null,
        placeholder: widget.control.getString("hint_text") ??
            widget.control.getString("placeholder_text") ??
            labelStr,
        placeholderStyle: widget.control.getTextStyle("hint_style", theme) ??
            widget.control.getTextStyle("placeholder_style", theme) ??
            widget.control.getTextStyle("label_style", theme),
        // label_style for adaptive TextField
        autofocus: autofocus,
        enabled: !widget.control.disabled,
        textInputAction: textInputAction,
        onSubmitted: !multiline ||
                textInputActionEndsMultilineEditing(textInputAction)
            ? (String value) {
                widget.control.triggerEvent("submit", value);
              }
            : null,
        decoration: _decoration(context, theme),
        cursorHeight: widget.control.getDouble("cursor_height"),
        showCursor: widget.control.getBool("show_cursor"),
        cursorWidth: widget.control.getDouble("cursor_width", 2.0)!,
        cursorRadius: widget.control
            .getRadius("cursor_radius", const Radius.circular(2.0))!,
        keyboardType: multiline
            ? TextInputType.multiline
            : parseTextInputType(
                widget.control.getString("keyboard_type"), TextInputType.text)!,
        clearButtonSemanticLabel:
            widget.control.getString("clear_button_semantics_label"),
        autocorrect: autocorrect,
        enableSuggestions: widget.control.getBool("enable_suggestions", true)!,
        smartDashesType: widget.control.getBool("smart_dashes_type", true)!
            ? SmartDashesType.enabled
            : SmartDashesType.disabled,
        smartQuotesType: widget.control.getBool("smart_quotes_type", true)!
            ? SmartQuotesType.enabled
            : SmartQuotesType.disabled,
        suffixMode: widget.control.getOverlayVisibilityMode(
            "suffix_visibility_mode", OverlayVisibilityMode.always)!,
        prefixMode: widget.control.getOverlayVisibilityMode(
            "prefix_visibility_mode", OverlayVisibilityMode.always)!,
        textAlign: textAlign,
        minLines: fitParentSize ? null : minLines,
        maxLines: fitParentSize ? null : maxLines,
        maxLength: maxLength,
        prefix: _inputAffix("prefix"),
        suffix: revealPasswordIcon ?? _inputAffix("suffix"),
        readOnly: readOnly,
        textDirection: rtl ? TextDirection.rtl : null,
        inputFormatters: inputFormatters.isNotEmpty ? inputFormatters : null,
        obscureText: password && !_revealPassword,
        padding: widget.control.getPadding("content_padding") ??
            widget.control.getPadding("padding", const EdgeInsets.all(7.0))!,
        stylusHandwritingEnabled:
            widget.control.getBool("enable_stylus_handwriting", true)!,
        scrollPadding: widget.control
            .getPadding("scroll_padding", const EdgeInsets.all(20.0))!,
        obscuringCharacter:
            widget.control.getString("obscuring_character", '•')!,
        cursorOpacityAnimates:
            widget.control.getBool("animate_cursor_opacity", isIOSMobile())!,
        expands: fitParentSize,
        enableIMEPersonalizedLearning:
            widget.control.getBool("enable_ime_personalized_learning", true)!,
        clipBehavior:
            widget.control.getClipBehavior("clip_behavior", Clip.hardEdge)!,
        cursorColor: cursorColor,
        autofillHints: widget.control.getAutofillHints("autofill_hints"),
        keyboardAppearance: widget.control.getBrightness("keyboard_brightness"),
        enableInteractiveSelection:
            widget.control.getBool("enable_interactive_selection"),
        clearButtonMode: widget.control.getOverlayVisibilityMode(
            "clear_button_visibility_mode", OverlayVisibilityMode.never)!,
        strutStyle: widget.control.getStrutStyle("strut_style"),
        onTap: () => widget.control.triggerEvent("click"),
        controller: _controller,
        focusNode: focusNode,
        onTapOutside: widget.control.getBool("on_tap_outside", false)!
            ? (PointerDownEvent? event) {
                widget.control.triggerEvent("tap_outside");
              }
            : null,
        onChanged: (String value) {
          _value = value;
          widget.control.updateProperties({"value": value});
          if (onChange) {
            widget.control.triggerEvent("change", value);
          }
        });

    textField = PasteFilesScope(
        enabled: widget.control.getBool("on_paste_files", false)!,
        focusNode: focusNode,
        onPaste: _onPasteFiles,
        child: textField);

    if (cursorColor != null || selectionColor != null) {
      textField = DefaultSelectionStyle.merge(
          cursorColor: cursorColor,
          selectionColor: selectionColor,
          child: textField);
    }

    final error = widget.control.get("error");
    final errorStyle = TextStyle(
      fontSize: 12,
      color: CupertinoColors.systemRed.resolveFrom(context),
    ).merge(widget.control.getTextStyle("error_style", theme));
    final errorWidget = error is Control
        ? widget.control.buildWidget("error")
        : error == null
            ? null
            : Text(
                error.toString(),
                style: errorStyle,
                maxLines: widget.control.getInt("error_max_lines"),
              );
    textField = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: rtl ? TextDirection.rtl : null,
      children: [
        if (fitParentSize) Expanded(child: textField) else textField,
        if (errorWidget != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(liveRegion: true, child: errorWidget),
          ),
      ],
    );

    if (widget.control.getExpand("expand", 0)! > 0) {
      return LayoutControl(control: widget.control, child: textField);
    } else {
      double? width = widget.control.getDouble("width");

      return LayoutControl(
        control: widget.control,
        child: width == null
            ? ConstrainedBox(
                constraints: const BoxConstraints.tightFor(width: 300),
                child: textField)
            : textField,
      );
    }
  }
}
