import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';
import '../core/text_or_widget.dart';
import '../core/toggle_label.dart';
import '../utils/misc.dart' show LabelPosition;

/// Everything Ruby can send to a Checkbox, and which design honors it.
const checkboxSpec = ControlSpec(
  wireType: 'Checkbox',
  props: [
    PropSpec('value', PropType.boolean, 'value'),
    PropSpec('tristate', PropType.boolean, 'tristate'),
    PropSpec('label', PropType.textOrWidget, 'label',
        consumer: PropConsumer.core),
    PropSpec('label_position', PropType.enumName, 'labelPosition',
        consumer: PropConsumer.core),
    PropSpec('label_style', PropType.textStyle, 'labelStyle'),
    // Gap between box and label; each design keeps its native default.
    PropSpec('spacing', PropType.number, 'spacing',
        consumer: PropConsumer.core),
    PropSpec('autofocus', PropType.boolean, 'autofocus'),
    PropSpec('active_color', PropType.color, 'activeColor'),
    PropSpec('check_color', PropType.color, 'checkColor'),
    PropSpec('focus_color', PropType.color, 'focusColor'),
    PropSpec('fill_color', PropType.stateColor, 'fillColor'),
    PropSpec('border_side', PropType.stateBorderSide, 'borderSide'),
    PropSpec('shape', PropType.outlinedBorder, 'shape'),
    PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor'),
    PropSpec('semantics_label', PropType.string, 'semanticsLabel'),
    PropSpec('error', PropType.boolean, 'error',
        skins: {Skin.material}, reason: 'CupertinoCheckbox has no error state'),
    PropSpec('hover_color', PropType.color, 'hoverColor',
        skins: {Skin.material}, reason: 'no hover ink on iOS'),
    PropSpec('overlay_color', PropType.stateColor, 'overlayColor',
        skins: {Skin.material}, reason: 'no ink overlay on iOS'),
    PropSpec('splash_radius', PropType.number, 'splashRadius',
        skins: {Skin.material}, reason: 'no ink splash on iOS'),
    PropSpec('visual_density', PropType.raw, 'visualDensity',
        skins: {Skin.material}, reason: 'Material density'),
    // Shared with LayoutControl: it sizes the box, the core scales the
    // checkbox and its label into it, the same on both designs.
    PropSpec('width', PropType.number, 'width', consumer: PropConsumer.core),
    PropSpec('height', PropType.number, 'height', consumer: PropConsumer.core),
  ],
  events: [
    // The new value (true, false or, when tristate, null) on both designs.
    EventSpec('change', source: EventSource.core),
    EventSpec('focus', source: EventSource.core),
    EventSpec('blur', source: EventSource.core),
  ],
  sharedLayoutKeys: {'width', 'height'},
);

@immutable
class CheckboxProps {
  factory CheckboxProps.parse(PropReader r) {
    final tristate = r.boolean('tristate');
    return CheckboxProps._(
        r, tristate, r.optionalBoolean('value', tristate ? null : false));
  }

  CheckboxProps._(PropReader r, this.tristate, this.value)
      : label = r.textOrWidget('label'),
        labelPosition = r.enumValue(
            LabelPosition.values, 'label_position', LabelPosition.right),
        labelStyle = r.textStyle('label_style'),
        spacing = r.number('spacing'),
        autofocus = r.boolean('autofocus'),
        activeColor = r.color('active_color'),
        checkColor = r.color('check_color'),
        focusColor = r.color('focus_color'),
        fillColor = r.stateColor('fill_color'),
        borderSide = r.stateBorderSide('border_side'),
        shape = r.outlinedBorder('shape'),
        mouseCursor = r.mouseCursor('mouse_cursor'),
        semanticsLabel = r.string('semantics_label'),
        error = r.boolean('error'),
        hoverColor = r.color('hover_color'),
        overlayColor = r.stateColor('overlay_color'),
        splashRadius = r.number('splash_radius'),
        visualDensity = r.raw('visual_density'),
        width = r.number('width'),
        height = r.number('height');

  final bool tristate;
  final bool? value;
  final TextOrWidget? label;
  final LabelPosition labelPosition;
  final TextStyle? labelStyle;
  final double? spacing;
  final bool autofocus;
  final Color? activeColor;
  final Color? checkColor;
  final Color? focusColor;
  final WidgetStateProperty<Color?>? fillColor;
  final WidgetStateBorderSide? borderSide;
  final OutlinedBorder? shape;
  final MouseCursor? mouseCursor;
  final String? semanticsLabel;
  final bool error;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;
  final RawProp visualDensity;
  final double? width;
  final double? height;
}

/// The shared Checkbox: the tristate cycle, value commits, the label,
/// ListTile toggling, focus and scale-to-fit, identical on both designs.
class CheckboxCore extends ControlCore<CheckboxProps>
    with FocusableCore<CheckboxProps>, TileToggleCore<CheckboxProps> {
  CheckboxCore(super.control);

  @override
  ControlSpec get spec => checkboxSpec;

  @override
  CheckboxProps parse(PropReader r) => CheckboxProps.parse(r);

  /// A commit made since the last parse; every parse reads Ruby's value.
  bool _committed = false;
  bool? _pending;

  bool? get value => _committed ? _pending : props.value;

  @override
  Set<WidgetState> get states =>
      {...super.states, if (value ?? false) WidgetState.selected};

  ValueChanged<bool?>? get onChanged => enabled ? _commit : null;

  /// Advances the cycle from the label and an enclosing toggle_inputs tile:
  /// false -> true -> false, or with tristate null -> false -> true -> null.
  VoidCallback? get onToggle => enabled ? _toggle : null;

  void _toggle() {
    final current = value;
    _commit(!props.tristate
        ? !(current ?? false)
        : switch (current) {
            null => false,
            false => true,
            true => null,
          });
  }

  void _commit(bool? next) {
    _committed = true;
    _pending = next;
    writeBack({'value': next});
    events.fire('change', next);
  }

  @override
  void onTileClick() => _toggle();

  @override
  void didParse(CheckboxProps? previous) {
    _committed = false;
    _pending = null;
    super.didParse(previous);
  }

  /// The native checkbox with its label: one tap target and semantics node.
  /// Skins pick the label style and their native gap default.
  Widget labelled(Widget native,
          {TextStyle? labelStyle, required double defaultSpacing}) =>
      ToggleLabel(
        label: props.label?.build(style: labelStyle),
        position: props.labelPosition,
        onToggle: onToggle,
        spacing: props.spacing ?? defaultSpacing,
        mainAxisSize: MainAxisSize.max,
        child: native,
      );

  @override
  Widget decorate(BuildContext context, Widget skin) {
    final p = props;
    if (p.width == null && p.height == null) return skin;
    return SizedBox(
      width: p.width,
      height: p.height,
      child: FittedBox(fit: BoxFit.fill, child: skin),
    );
  }
}
