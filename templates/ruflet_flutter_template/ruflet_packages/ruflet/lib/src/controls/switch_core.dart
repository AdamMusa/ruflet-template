import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/text_or_widget.dart';
import '../core/toggle_label.dart';
import '../utils/misc.dart' show LabelPosition;

/// Everything Ruby can send to a Switch, and which design honors it.
const switchSpec = ControlSpec(
  wireType: 'Switch',
  props: [
    PropSpec('value', PropType.boolean, 'value'),
    PropSpec('label', PropType.textOrWidget, 'label',
        consumer: PropConsumer.core),
    PropSpec('label_position', PropType.enumName, 'labelPosition',
        consumer: PropConsumer.core),
    PropSpec('label_text_style', PropType.textStyle, 'labelTextStyle'),
    PropSpec('autofocus', PropType.boolean, 'autofocus'),
    PropSpec('active_track_color', PropType.color, 'activeTrackColor'),
    PropSpec('inactive_track_color', PropType.color, 'inactiveTrackColor'),
    PropSpec('inactive_thumb_color', PropType.color, 'inactiveThumbColor'),
    PropSpec('thumb_color', PropType.stateColor, 'thumbColor'),
    PropSpec('thumb_icon', PropType.stateIcon, 'thumbIcon'),
    PropSpec('focus_color', PropType.color, 'focusColor'),
    PropSpec('track_outline_color', PropType.stateColor, 'trackOutlineColor'),
    PropSpec('track_outline_width', PropType.stateNumber, 'trackOutlineWidth'),
    PropSpec('active_thumb_image_src', PropType.image, 'activeThumbImage'),
    // Ruby's Cupertino spelling of active_thumb_image_src.
    PropSpec('active_thumb_image', PropType.image, 'activeThumbImage'),
    PropSpec('inactive_thumb_image_src', PropType.image, 'inactiveThumbImage'),
    // Ruby's Cupertino spelling of inactive_thumb_image_src.
    PropSpec('inactive_thumb_image', PropType.image, 'inactiveThumbImage'),
    PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor'),
    PropSpec('active_color', PropType.color, 'activeColor',
        skins: {Skin.material},
        reason: 'CupertinoSwitch has no separate active thumb color; '
            'thumb_color covers it'),
    PropSpec('hover_color', PropType.color, 'hoverColor',
        skins: {Skin.material}, reason: 'no hover ink on iOS'),
    PropSpec('overlay_color', PropType.stateColor, 'overlayColor',
        skins: {Skin.material}, reason: 'no ink overlay on iOS'),
    PropSpec('splash_radius', PropType.number, 'splashRadius',
        skins: {Skin.material}, reason: 'no ink splash on iOS'),
    PropSpec('track_color', PropType.stateColor, 'trackColor',
        skins: {Skin.material},
        reason: 'CupertinoSwitch takes active/inactive track colors only'),
    PropSpec('padding', PropType.edgeInsets, 'padding',
        skins: {Skin.material}, reason: 'CupertinoSwitch has no padding'),
    PropSpec('on_label_color', PropType.color, 'onLabelColor',
        skins: {Skin.cupertino}, reason: 'iOS on/off accessibility glyphs'),
    PropSpec('off_label_color', PropType.color, 'offLabelColor',
        skins: {Skin.cupertino}, reason: 'iOS on/off accessibility glyphs'),
    // Shared with LayoutControl: it sizes the box, the core scales the
    // switch and its label into it, the same on both designs.
    PropSpec('width', PropType.number, 'width', consumer: PropConsumer.core),
    PropSpec('height', PropType.number, 'height', consumer: PropConsumer.core),
  ],
  events: [
    // The new value on both designs.
    EventSpec('change', source: EventSource.core),
    EventSpec('focus', source: EventSource.core),
    EventSpec('blur', source: EventSource.core),
    EventSpec('image_error', field: 'onImageError'),
  ],
  sharedLayoutKeys: {'width', 'height'},
);

@immutable
class SwitchProps {
  SwitchProps.parse(PropReader r)
      : value = r.boolean('value'),
        label = _nonEmpty(r.textOrWidget('label')),
        labelPosition = r.enumValue(
            LabelPosition.values, 'label_position', LabelPosition.right),
        labelTextStyle = r.textStyle('label_text_style'),
        autofocus = r.boolean('autofocus'),
        activeTrackColor = r.color('active_track_color'),
        inactiveTrackColor = r.color('inactive_track_color'),
        inactiveThumbColor = r.color('inactive_thumb_color'),
        thumbColor = r.stateColor('thumb_color'),
        thumbIcon = r.stateIcon('thumb_icon'),
        focusColor = r.color('focus_color'),
        trackOutlineColor = r.stateColor('track_outline_color'),
        trackOutlineWidth = r.stateNumber('track_outline_width'),
        activeThumbImage = _first(
            r.image('active_thumb_image_src'), r.image('active_thumb_image')),
        inactiveThumbImage = _first(r.image('inactive_thumb_image_src'),
            r.image('inactive_thumb_image')),
        mouseCursor = r.mouseCursor('mouse_cursor'),
        activeColor = r.color('active_color'),
        hoverColor = r.color('hover_color'),
        overlayColor = r.stateColor('overlay_color'),
        splashRadius = r.number('splash_radius'),
        trackColor = r.stateColor('track_color'),
        padding = r.edgeInsets('padding'),
        onLabelColor = r.color('on_label_color'),
        offLabelColor = r.color('off_label_color'),
        width = r.number('width'),
        height = r.number('height');

  final bool value;
  final TextOrWidget? label;
  final LabelPosition labelPosition;
  final TextStyle? labelTextStyle;
  final bool autofocus;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final Color? inactiveThumbColor;
  final WidgetStateProperty<Color?>? thumbColor;
  final WidgetStateProperty<Icon?>? thumbIcon;
  final Color? focusColor;
  final WidgetStateProperty<Color?>? trackOutlineColor;
  final WidgetStateProperty<double?>? trackOutlineWidth;
  final ImageProvider? activeThumbImage;
  final ImageProvider? inactiveThumbImage;
  final MouseCursor? mouseCursor;
  final Color? activeColor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;
  final WidgetStateProperty<Color?>? trackColor;
  final EdgeInsets? padding;
  final Color? onLabelColor;
  final Color? offLabelColor;
  final double? width;
  final double? height;

  static TextOrWidget? _nonEmpty(TextOrWidget? label) =>
      label == null || label.isEmptyText ? null : label;

  static ImageProvider? _first(
          ImageProvider? preferred, ImageProvider? alias) =>
      preferred ?? alias;
}

/// The shared Switch: value commits, the label, ListTile toggling, focus and
/// scale-to-fit, identical on Material and Cupertino.
class SwitchCore extends ControlCore<SwitchProps>
    with FocusableCore<SwitchProps>, TileToggleCore<SwitchProps> {
  SwitchCore(super.control);

  @override
  ControlSpec get spec => switchSpec;

  @override
  SwitchProps parse(PropReader r) => SwitchProps.parse(r);

  /// A commit made since the last parse (several in one frame toggle from
  /// it); every parse reads Ruby's value again.
  bool? _pending;

  bool get value => _pending ?? props.value;

  @override
  Set<WidgetState> get states =>
      {...super.states, if (value) WidgetState.selected};

  ValueChanged<bool>? get onChanged => enabled ? _commit : null;

  /// Toggles from the label (and from an enclosing toggle_inputs tile).
  VoidCallback? get onToggle => enabled ? () => _commit(!value) : null;

  /// Thumb image load failures, reported as `image_error` with the message.
  ImageErrorListener get onImageError =>
      (error, _) => events.fire('image_error', error.toString());

  void _commit(bool next) {
    _pending = next;
    writeBack({'value': next});
    events.fire('change', next);
  }

  @override
  void onTileClick() => _commit(!value);

  @override
  void didParse(SwitchProps? previous) {
    _pending = null;
    super.didParse(previous);
  }

  /// The native switch with its label: one tap target and semantics node,
  /// the same compact row on both designs. Skins only pick the label style.
  Widget labelled(Widget native, {TextStyle? labelStyle}) => ToggleLabel(
        label: props.label?.build(style: labelStyle),
        position: props.labelPosition,
        onToggle: onToggle,
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
