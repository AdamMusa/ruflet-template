import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../extensions/control.dart';
import '../models/control.dart';
import '../models/ruflet_time.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class CupertinoDropdownControl extends StatefulWidget {
  final Control control;

  const CupertinoDropdownControl({super.key, required this.control});

  @override
  State<CupertinoDropdownControl> createState() =>
      _CupertinoDropdownControlState();
}

class _CupertinoDropdownControlState extends State<CupertinoDropdownControl> {
  late final FocusNode _focusNode;
  late final TextEditingController _textController;

  Control get control => widget.control;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(
          () => control.triggerEvent(_focusNode.hasFocus ? "focus" : "blur"));
    _textController = TextEditingController(
        text: control.getString("text") ?? control.getString("value") ?? "");
    control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name == "focus") {
      _focusNode.requestFocus();
      return null;
    }
    throw Exception("Unknown Dropdown method: $name");
  }

  @override
  void dispose() {
    control.removeInvokeMethodListener(_invokeMethod);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _showOptions() async {
    final options = control.children("options");
    if (options.isEmpty || control.disabled) return;

    // Ruby's dropdown_option(disabled:) cannot be chosen, as in the Material
    // renderers (DropdownMenuEntry/DropdownMenuItem enabled): the picker opens
    // on the current value's option when it is enabled, else on the first
    // enabled one, and the sheet turns Done off while a disabled row is
    // centred.
    final currentValue = control.getString("value");
    var selectedIndex = options.indexWhere((option) =>
        (option.getString("key") ?? option.getString("text")) == currentValue);
    if (selectedIndex < 0 || options[selectedIndex].disabled) {
      final firstEnabled = options.indexWhere((option) => !option.disabled);
      if (firstEnabled >= 0) {
        selectedIndex = firstEnabled;
      } else if (selectedIndex < 0) {
        selectedIndex = 0;
      }
    }

    final selected = await showCupertinoModalPopup<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DropdownOptionsSheet(
        dropdown: control,
        options: options,
        initialIndex: selectedIndex,
        borderRadius: control.getBorderRadius("menu_border_radius"),
      ),
    );

    // An option Ruby disabled while the sheet was open is not chosen either,
    // even when the change lands in the same frame as the tap on Done.
    if (!mounted || selected == null || options[selected].disabled) return;
    final option = options[selected];
    final value = option.getString("key") ?? option.getString("text") ?? "";
    final label = option.getString("text") ?? value;
    setState(() => _textController.text = label);
    control.updateProperties({"value": value, "text": label});
    control.triggerEvent("select", value);
    option.triggerEvent("click");
  }

  @override
  Widget build(BuildContext context) {
    final value = control.getString("value");
    final options = control.children("options");
    final selected = options.where((option) =>
        (option.getString("key") ?? option.getString("text")) == value);
    final backendText = control.getString("text") ??
        (selected.isEmpty ? value : selected.first.getString("text")) ??
        "";
    if (!_focusNode.hasFocus && _textController.text != backendText) {
      _textController.text = backendText;
    }

    final editable = control.getBool("editable", false)!;
    final field = CupertinoTextField(
      controller: _textController,
      focusNode: _focusNode,
      enabled: !control.disabled,
      readOnly: !editable,
      autofocus: control.getBool("autofocus", false)!,
      // Cupertino placeholders are text only; hint_content and
      // disabled_hint_content are rendered by the Material 2 renderer.
      placeholder: control.getString("hint_text"),
      padding: control.getPadding("content_padding", const EdgeInsets.all(10))!,
      prefix: control.buildIconOrWidget("leading_icon"),
      suffix: Row(mainAxisSize: MainAxisSize.min, children: [
        // Ruby selected_suffix: shown after the chosen option's text.
        if (selected.isNotEmpty)
          if (control.buildWidget("selected_suffix") case final suffix?) suffix,
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size.square(32),
          onPressed: control.disabled ? null : _showOptions,
          child: control.buildIconOrWidget("trailing_icon") ??
              const Icon(CupertinoIcons.chevron_down, size: 18),
        ),
      ]),
      onTap: editable ? null : _showOptions,
      onChanged: editable
          ? (value) {
              control.updateProperties({"text": value});
              control.triggerEvent("text_change", value);
            }
          : null,
      onSubmitted: (_) => _showOptions(),
    );
    return LayoutControl(control: control, child: field);
  }
}

/// The Dropdown options picker: Cancel/Done over a [CupertinoPicker] of
/// [options]. It pops the chosen index on Done. Disabled options are drawn
/// dimmed, and Done is off while one of them is centred.
class _DropdownOptionsSheet extends StatefulWidget {
  final Control dropdown;
  final List<Control> options;
  final int initialIndex;
  final BorderRadius? borderRadius;

  const _DropdownOptionsSheet({
    required this.dropdown,
    required this.options,
    required this.initialIndex,
    required this.borderRadius,
  });

  @override
  State<_DropdownOptionsSheet> createState() => _DropdownOptionsSheetState();
}

class _DropdownOptionsSheetState extends State<_DropdownOptionsSheet> {
  late final FixedExtentScrollController _scrollController =
      FixedExtentScrollController(initialItem: widget.initialIndex);
  late int _pendingIndex = widget.initialIndex;

  /// An option's `disabled` is its own flag or any ancestor's
  /// ([Control.disabled]). Ruby can change either while the sheet is open, so
  /// the sheet watches the options, the Dropdown and its ancestors, and
  /// redraws when the flags it last drew no longer hold.
  late final List<Control> _watched = [
    ...widget.options,
    for (Control? c = widget.dropdown; c != null; c = c.parent) c,
  ];
  List<bool> _drawnDisabled = const [];

  List<bool> _disabledFlags() => [for (final o in widget.options) o.disabled];

  void _onControlChanged() {
    if (!listEquals(_disabledFlags(), _drawnDisabled)) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final control in _watched) {
      control.addListener(_onControlChanged);
    }
  }

  @override
  void dispose() {
    for (final control in _watched) {
      control.removeListener(_onControlChanged);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Widget _row(Control option, bool disabled) {
    final row = Center(
      child: option.buildWidget("content") ??
          Text(option.getString("text") ?? option.getString("key") ?? ""),
    );
    return disabled ? Opacity(opacity: 0.38, child: row) : row;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _drawnDisabled = _disabledFlags();
    final canPick = !disabled[_pendingIndex];
    return _DropdownMenuSurface(
      borderRadius: widget.borderRadius,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 280,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  CupertinoButton(
                    onPressed: canPick
                        ? () => Navigator.pop(context, _pendingIndex)
                        : null,
                    child: const Text("Done"),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: _scrollController,
                  itemExtent: 42,
                  onSelectedItemChanged: (index) =>
                      setState(() => _pendingIndex = index),
                  children: [
                    for (var i = 0; i < widget.options.length; i++)
                      _row(widget.options[i], disabled[i]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Dropdown options sheet: a [CupertinoPopupSurface], rounded by Ruby's
/// menu_border_radius (Flet's DropdownM2) like the Material menu.
class _DropdownMenuSurface extends StatelessWidget {
  final BorderRadius? borderRadius;
  final Widget child;

  const _DropdownMenuSurface({required this.borderRadius, required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = CupertinoPopupSurface(child: child);
    final radius = borderRadius;
    return radius == null
        ? surface
        : ClipRRect(borderRadius: radius, child: surface);
  }
}

class CupertinoSearchBarControl extends StatefulWidget {
  final Control control;

  const CupertinoSearchBarControl({super.key, required this.control});

  @override
  State<CupertinoSearchBarControl> createState() =>
      _CupertinoSearchBarControlState();
}

class _CupertinoSearchBarControlState extends State<CupertinoSearchBarControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Set by open_view: the search is active and lists every suggestion, the
  /// way an iOS search controller shows results before anything is typed.
  bool _viewOpen = false;

  Control get control => widget.control;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: control.getString("value", ""));
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() {
          // Leaving the field ends an opened search view.
          if (!_focusNode.hasFocus) _viewOpen = false;
        });
        control.triggerEvent(_focusNode.hasFocus ? "focus" : "blur");
      });
    control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    switch (name) {
      case "focus":
        _focusNode.requestFocus();
        return null;
      case "blur":
        _focusNode.unfocus();
        return null;
      case "clear":
        _controller.clear();
        _changed("");
        return null;
      // iOS has no separate search view: opening the view activates the
      // search field (first responder, suggestions listed) and closing it
      // cancels the search, as UISearchController does.
      case "open_view":
        if (control.disabled || _viewOpen) return null;
        setState(() => _viewOpen = true);
        _focusNode.requestFocus();
        return null;
      case "close_view":
        if (!_viewOpen && !_focusNode.hasFocus) return null;
        final text = args is Map ? args["text"]?.toString() : null;
        if (text != null) {
          _controller.text = text;
          // Like Material, closing writes the value without a change event.
          control.updateProperties({"value": text});
        }
        setState(() => _viewOpen = false);
        _focusNode.unfocus();
        return null;
      default:
        throw Exception("Unknown SearchBar method: $name");
    }
  }

  void _changed(String value) {
    control.updateProperties({"value": value});
    control.triggerEvent("change", value);
  }

  @override
  void dispose() {
    control.removeInvokeMethodListener(_invokeMethod);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backendValue = control.getString("value", "")!;
    if (!_focusNode.hasFocus && _controller.text != backendValue) {
      _controller.text = backendValue;
    }
    final suggestions = control.children("controls");
    final showSuggestions = _focusNode.hasFocus &&
        suggestions.isNotEmpty &&
        (_viewOpen || _controller.text.isNotEmpty);
    // The inline counterpart of Material's search view: opened by
    // open_view, or listing suggestions for the query.
    final viewShown = _viewOpen || showSuggestions;
    final leading = control.buildWidget("bar_leading");
    final trailing = control.buildWidgets("bar_trailing");

    final search = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(
              // CupertinoSearchTextField has no onTapOutside; like the
              // Material SearchBar's text field, report outside taps while
              // the bar has focus and the view is closed.
              child: TextFieldTapRegion(
                onTapOutside: _focusNode.hasFocus &&
                        !viewShown &&
                        control.getBool("on_tap_outside_bar", false)!
                    ? (event) => control.triggerEvent("tap_outside_bar")
                    : null,
                child: CupertinoSearchTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !control.disabled,
                  autofocus: control.getBool("autofocus", false)!,
                  placeholder: control.getString("bar_hint_text"),
                  backgroundColor: control.getColor("bar_bgcolor", context),
                  onTap: () => control.triggerEvent("tap"),
                  onChanged: _changed,
                  onSubmitted: (value) => control.triggerEvent("submit", value),
                ),
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 8),
              ...trailing,
            ],
          ],
        ),
        if (showSuggestions)
          CupertinoPopupSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: suggestions
                  .map((suggestion) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => suggestion.triggerEvent("click"),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: ControlWidget(control: suggestion),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
    // A tap outside the field and its suggestions while the view is shown
    // is Ruby's tap_outside_view, as a tap on Material's view barrier.
    return LayoutControl(
        control: control,
        child: TapRegion(
          onTapOutside:
              viewShown && control.getBool("on_tap_outside_view", false)!
                  ? (event) => control.triggerEvent("tap_outside_view")
                  : null,
          child: search,
        ));
  }
}

class CupertinoTimePickerControl extends StatelessWidget {
  final Control control;

  const CupertinoTimePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final open = control.getBool("open", false)!;
    final lastOpen = control.getBool("_open", false)!;
    final raw = control.get("value");
    final value = raw is RufletTime ? raw : RufletTime.now();

    if (open && open != lastOpen) {
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var selected = value;
        final result = await showCupertinoModalPopup<RufletTime>(
          context: context,
          useRootNavigator: false,
          barrierDismissible: !control.getBool("modal", false)!,
          builder: (context) => CupertinoPopupSurface(
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 300,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.pop(context),
                          child:
                              Text(control.getString("cancel_text", "Cancel")!),
                        ),
                        CupertinoButton(
                          onPressed: () => Navigator.pop(context, selected),
                          child:
                              Text(control.getString("confirm_text", "Done")!),
                        ),
                      ],
                    ),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: control.getString("hour_format") == "h24",
                        initialDateTime:
                            DateTime(2000, 1, 1, value.hour, value.minute),
                        onDateTimeChanged: (date) => selected =
                            RufletTime(hour: date.hour, minute: date.minute),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        control.updateProperties({"_open": false}, python: false);
        control.updateProperties({"value": result ?? value, "open": false});
        if (result != null) control.triggerEvent("change", result);
        control.triggerEvent("dismiss", result == null);
      });
    }
    return const SizedBox.shrink();
  }
}

class CupertinoDateRangePickerControl extends StatelessWidget {
  final Control control;

  const CupertinoDateRangePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final open = control.getBool("open", false)!;
    final lastOpen = control.getBool("_open", false)!;
    final now = DateTime.now();
    final initialStart = control.getDateTime("start_value", now)!;
    final initialEnd = control.getDateTime("end_value", initialStart)!;
    final firstDate = control.getDateTime("first_date");
    final lastDate = control.getDateTime("last_date");

    if (open && open != lastOpen) {
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var start = initialStart;
        var end = initialEnd;
        final result = await showCupertinoModalPopup<List<DateTime>>(
          context: context,
          useRootNavigator: false,
          barrierDismissible: !control.getBool("modal", false)!,
          builder: (context) => CupertinoPopupSurface(
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 430,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.pop(context),
                          child:
                              Text(control.getString("cancel_text", "Cancel")!),
                        ),
                        Text(control.getString("help_text", "Select dates")!),
                        CupertinoButton(
                          onPressed: () => Navigator.pop(context, [start, end]),
                          child:
                              Text(control.getString("confirm_text", "Done")!),
                        ),
                      ],
                    ),
                    const Text("Start"),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: start,
                        minimumDate: firstDate,
                        maximumDate: lastDate,
                        onDateTimeChanged: (value) => start = value,
                      ),
                    ),
                    const Text("End"),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: end,
                        minimumDate: firstDate,
                        maximumDate: lastDate,
                        onDateTimeChanged: (value) => end = value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        control.updateProperties({"_open": false}, python: false);
        control.updateProperties({
          "start_value": result?.first ?? initialStart,
          "end_value": result?.last ?? initialEnd,
          "open": false,
        });
        if (result != null) {
          control.triggerEvent(
              "change", {"start": result.first, "end": result.last});
        }
        control.triggerEvent("dismiss", result == null);
      });
    }
    return const SizedBox.shrink();
  }
}

class CupertinoRangeSliderControl extends StatelessWidget {
  final Control control;

  const CupertinoRangeSliderControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final min = control.getDouble("min", 0)!;
    final max = control.getDouble("max", 1)!;
    final start = control.getDouble("start_value", min)!.clamp(min, max);
    final end = control.getDouble("end_value", max)!.clamp(start, max);

    void changed(double newStart, double newEnd) {
      control.updateProperties({"start_value": newStart, "end_value": newEnd},
          notify: true);
      control.triggerEvent("change");
    }

    final slider = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoSlider(
          value: start,
          min: min,
          max: end,
          divisions: control.getInt("divisions"),
          activeColor: control.getColor("active_color", context),
          onChangeStart: control.disabled
              ? null
              : (_) => control.triggerEvent("change_start"),
          onChangeEnd: control.disabled
              ? null
              : (_) => control.triggerEvent("change_end"),
          onChanged: control.disabled ? null : (value) => changed(value, end),
        ),
        CupertinoSlider(
          value: end,
          min: start,
          max: max,
          divisions: control.getInt("divisions"),
          activeColor: control.getColor("active_color", context),
          onChangeStart: control.disabled
              ? null
              : (_) => control.triggerEvent("change_start"),
          onChangeEnd: control.disabled
              ? null
              : (_) => control.triggerEvent("change_end"),
          onChanged: control.disabled ? null : (value) => changed(start, value),
        ),
      ],
    );
    return LayoutControl(control: control, child: slider);
  }
}

class _CupertinoSuggestion {
  final int index;
  final String key;
  final String value;

  const _CupertinoSuggestion(this.index, this.key, this.value);
}

class CupertinoAutoCompleteControl extends StatefulWidget {
  final Control control;

  const CupertinoAutoCompleteControl({super.key, required this.control});

  @override
  State<CupertinoAutoCompleteControl> createState() =>
      _CupertinoAutoCompleteControlState();
}

class _CupertinoAutoCompleteControlState
    extends State<CupertinoAutoCompleteControl> {
  @override
  Widget build(BuildContext context) {
    final raw = widget.control.get("suggestions");
    final suggestions = raw is List
        ? raw.indexed
            .map((entry) {
              final value = entry.$2;
              final key = value is Map ? value["key"]?.toString() : null;
              final label = value is Map ? value["value"]?.toString() : null;
              return _CupertinoSuggestion(
                  entry.$1, key ?? label ?? "", label ?? key ?? "");
            })
            .where((item) => item.key.isNotEmpty)
            .toList()
        : <_CupertinoSuggestion>[];

    final autocomplete = RawAutocomplete<_CupertinoSuggestion>(
      initialValue:
          TextEditingValue(text: widget.control.getString("value", "")!),
      displayStringForOption: (option) => option.key,
      optionsBuilder: (value) => value.text.isEmpty
          ? const Iterable<_CupertinoSuggestion>.empty()
          : suggestions.where((suggestion) =>
              suggestion.key.toLowerCase().contains(value.text.toLowerCase())),
      onSelected: (selection) {
        widget.control.updateProperties(
            {"value": selection.key, "_selected_index": selection.index});
        widget.control.triggerEvent("select", {
          "index": selection.index,
          "selection": {"key": selection.key, "value": selection.value}
        });
      },
      fieldViewBuilder: (context, controller, focusNode, submit) {
        return CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: !widget.control.disabled,
          onChanged: (value) {
            widget.control.updateProperties({"value": value});
            widget.control.triggerEvent("change", value);
          },
          onSubmitted: (_) => submit(),
        );
      },
      optionsViewBuilder: (context, selected, options) {
        final entries = options.toList();
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: CupertinoPopupSurface(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight:
                      widget.control.getDouble("suggestions_max_height", 200)!),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (context, index) => CupertinoButton(
                  alignment: AlignmentDirectional.centerStart,
                  onPressed: () => selected(entries[index]),
                  child: Text(entries[index].value),
                ),
              ),
            ),
          ),
        );
      },
    );
    return LayoutControl(control: widget.control, child: autocomplete);
  }
}
