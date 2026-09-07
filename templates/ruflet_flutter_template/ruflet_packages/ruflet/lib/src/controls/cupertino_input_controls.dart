import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../models/ruflet_time.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
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

    final currentValue = control.getString("value");
    var selectedIndex = options.indexWhere((option) =>
        (option.getString("key") ?? option.getString("text")) == currentValue);
    if (selectedIndex < 0) selectedIndex = 0;
    var pendingIndex = selectedIndex;

    final selected = await showCupertinoModalPopup<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoPopupSurface(
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
                      onPressed: () => Navigator.pop(context, pendingIndex),
                      child: const Text("Done"),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: selectedIndex),
                    itemExtent: 42,
                    onSelectedItemChanged: (index) => pendingIndex = index,
                    children: options
                        .map((option) => Center(
                              child: option.buildWidget("content") ??
                                  Text(option.getString("text") ??
                                      option.getString("key") ??
                                      ""),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    final option = options[selected];
    final value = option.getString("key") ?? option.getString("text") ?? "";
    final label = option.getString("text") ?? value;
    setState(() => _textController.text = label);
    control.updateProperties({"value": value, "text": label});
    control.triggerEvent("select", value);
    if (control.type == "DropdownM2") control.triggerEvent("change", value);
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
      placeholder: control.getString("hint_text"),
      padding: control.getPadding("content_padding", const EdgeInsets.all(10))!,
      prefix: control.buildIconOrWidget("leading_icon"),
      suffix: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size.square(32),
        onPressed: control.disabled ? null : _showOptions,
        child: control.buildIconOrWidget("trailing_icon") ??
            const Icon(CupertinoIcons.chevron_down, size: 18),
      ),
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

  Control get control => widget.control;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: control.getString("value", ""));
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() {});
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
        _controller.text.isNotEmpty;
    final leading = control.buildWidget("bar_leading");
    final trailing = control.buildWidgets("bar_trailing");

    final search = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(
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
    return LayoutControl(control: control, child: search);
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
    final initialStart = control.get("start_value") is DateTime
        ? (control.get("start_value") as DateTime).toLocal()
        : now;
    final initialEnd = control.get("end_value") is DateTime
        ? (control.get("end_value") as DateTime).toLocal()
        : initialStart;

    if (open && open != lastOpen) {
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var start = initialStart;
        var end = initialEnd;
        final result = await showCupertinoModalPopup<List<DateTime>>(
          context: context,
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
                        minimumDate: control.get("first_date") as DateTime?,
                        maximumDate: control.get("last_date") as DateTime?,
                        onDateTimeChanged: (value) => start = value,
                      ),
                    ),
                    const Text("End"),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: end,
                        minimumDate: control.get("first_date") as DateTime?,
                        maximumDate: control.get("last_date") as DateTime?,
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
