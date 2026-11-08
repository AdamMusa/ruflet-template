import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';
import '../core/text_or_widget.dart';
import '../core/toggle_label.dart';
import '../utils/misc.dart' show LabelPosition;
import '../widgets/error.dart';

/// Everything Ruby can send to a Radio, and which design honors it.
const radioSpec = ControlSpec(
  wireType: 'Radio',
  props: [
    // The value this radio selects in its RadioGroup.
    PropSpec('value', PropType.string, 'value'),
    PropSpec('label', PropType.textOrWidget, 'label',
        consumer: PropConsumer.core),
    PropSpec('label_position', PropType.enumName, 'labelPosition',
        consumer: PropConsumer.core),
    PropSpec('label_style', PropType.textStyle, 'labelStyle'),
    PropSpec('autofocus', PropType.boolean, 'autofocus'),
    PropSpec('toggleable', PropType.boolean, 'toggleable'),
    PropSpec('active_color', PropType.color, 'activeColor'),
    PropSpec('fill_color', PropType.stateColor, 'fillColor'),
    PropSpec('focus_color', PropType.color, 'focusColor'),
    PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor'),
    PropSpec('hover_color', PropType.color, 'hoverColor',
        skins: {Skin.material}, reason: 'no hover ink on iOS'),
    PropSpec('overlay_color', PropType.stateColor, 'overlayColor',
        skins: {Skin.material}, reason: 'no ink overlay on iOS'),
    PropSpec('splash_radius', PropType.number, 'splashRadius',
        skins: {Skin.material}, reason: 'no ink splash on iOS'),
    PropSpec('visual_density', PropType.raw, 'visualDensity',
        skins: {Skin.material}, reason: 'Material density'),
    PropSpec('inactive_color', PropType.color, 'inactiveColor',
        skins: {Skin.cupertino},
        reason: 'Material Radio has no inactive color; fill_color covers it'),
    PropSpec('use_checkmark_style', PropType.boolean, 'useCheckmarkStyle',
        skins: {Skin.cupertino}, reason: 'iOS checkmark radio style'),
  ],
  events: [
    // Selection is reported by the RadioGroup (`change`), not the radio.
    EventSpec('focus', source: EventSource.core),
    EventSpec('blur', source: EventSource.core),
  ],
);

@immutable
class RadioProps {
  RadioProps.parse(PropReader r)
      : value = r.string('value', '')!,
        label = _nonEmpty(r.textOrWidget('label')),
        labelPosition = r.enumValue(
            LabelPosition.values, 'label_position', LabelPosition.right),
        labelStyle = r.textStyle('label_style'),
        autofocus = r.boolean('autofocus'),
        toggleable = r.boolean('toggleable'),
        activeColor = r.color('active_color'),
        fillColor = r.stateColor('fill_color'),
        focusColor = r.color('focus_color'),
        mouseCursor = r.mouseCursor('mouse_cursor'),
        hoverColor = r.color('hover_color'),
        overlayColor = r.stateColor('overlay_color'),
        splashRadius = r.number('splash_radius'),
        visualDensity = r.raw('visual_density'),
        inactiveColor = r.color('inactive_color'),
        useCheckmarkStyle = r.boolean('use_checkmark_style');

  final String value;
  final TextOrWidget? label;
  final LabelPosition labelPosition;
  final TextStyle? labelStyle;
  final bool autofocus;
  final bool toggleable;
  final Color? activeColor;
  final WidgetStateProperty<Color?>? fillColor;
  final Color? focusColor;
  final MouseCursor? mouseCursor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;
  final RawProp visualDensity;
  final Color? inactiveColor;
  final bool useCheckmarkStyle;

  static TextOrWidget? _nonEmpty(TextOrWidget? label) =>
      label == null || label.isEmptyText ? null : label;
}

/// The shared Radio: its RadioGroup, label and toggle_inputs tile taps
/// select it, focus, and the "must be in a RadioGroup" rule, identical on
/// Material and Cupertino. The group owns the value and the `change` event.
class RadioCore extends ControlCore<RadioProps>
    with FocusableCore<RadioProps>, TileToggleCore<RadioProps> {
  RadioCore(super.control);

  @override
  ControlSpec get spec => radioSpec;

  @override
  RadioProps parse(PropReader r) => RadioProps.parse(r);

  RadioGroupRegistry<String>? _group;

  bool get selected => _group != null && _group!.groupValue == props.value;

  @override
  Set<WidgetState> get states =>
      {...super.states, if (selected) WidgetState.selected};

  /// Selects this radio from its label (and an enclosing toggle_inputs tile).
  VoidCallback? get onToggle =>
      enabled && _group != null ? () => _group!.onChanged(props.value) : null;

  @override
  void onTileClick() => onToggle?.call();

  @override
  void didChangeDependencies(BuildContext context) {
    _group = RadioGroup.maybeOf<String>(context);
    super.didChangeDependencies(context);
  }

  /// The native radio with its label: one tap target and semantics node.
  /// Skins only pick the label style.
  Widget labelled(Widget native, {TextStyle? labelStyle}) => ToggleLabel(
        label: props.label?.build(style: labelStyle),
        position: props.labelPosition,
        onToggle: onToggle,
        mainAxisSize: MainAxisSize.max,
        child: native,
      );

  @override
  Widget decorate(BuildContext context, Widget skin) => _group == null
      ? const ErrorControl("Radio must be enclosed within RadioGroup")
      : skin;
}
