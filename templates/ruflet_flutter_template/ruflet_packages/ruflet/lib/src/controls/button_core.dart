import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';
import '../core/text_or_widget.dart';
import '../utils/launch_url.dart' show Url, openWebBrowser, parseUrl;

/// The visual variant a Button wire type selects.
enum ButtonVariant { elevated, filled, tonal, outlined, text }

const _cupertinoStyle =
    'CupertinoButton takes it directly; Material buttons take the same '
    'value through `style` (ButtonStyle)';

/// Keys every Button wire type accepts.
const _sharedProps = [
  PropSpec('content', PropType.textOrWidget, 'content'),
  PropSpec('icon', PropType.iconOrWidget, 'icon'),
  PropSpec('icon_color', PropType.color, 'iconColor'),
  PropSpec('color', PropType.color, 'color'),
  PropSpec('bgcolor', PropType.color, 'bgcolor'),
  PropSpec('style', PropType.raw, 'style'),
  PropSpec('clip_behavior', PropType.enumName, 'clipBehavior'),
  PropSpec('autofocus', PropType.boolean, 'autofocus'),
  PropSpec('url', PropType.raw, 'url', consumer: PropConsumer.core),
  // Client actions run in the tap, before `click` (Flet's `action`).
  PropSpec('action', PropType.raw, 'action', consumer: PropConsumer.core),
  PropSpec('alignment', PropType.alignment, 'alignment',
      skins: {Skin.cupertino}, reason: _cupertinoStyle),
  PropSpec('border_radius', PropType.borderRadius, 'borderRadius',
      skins: {Skin.cupertino},
      reason: 'CupertinoButton radius; Material shapes come from '
          '`style.shape`'),
  PropSpec('padding', PropType.edgeInsets, 'padding',
      skins: {Skin.cupertino}, reason: _cupertinoStyle),
  PropSpec('min_size', PropType.raw, 'minSize',
      skins: {Skin.cupertino}, reason: _cupertinoStyle),
  PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor',
      skins: {Skin.cupertino}, reason: _cupertinoStyle),
  PropSpec('focus_color', PropType.color, 'focusColor',
      skins: {Skin.cupertino},
      reason: 'CupertinoButton focus colour; Material focus is '
          '`style.overlay_color`'),
  PropSpec('disabled_bgcolor', PropType.color, 'disabledBgcolor',
      skins: {Skin.cupertino},
      reason: 'CupertinoButton disabled colour; Material uses the '
          '`style.bgcolor` disabled state'),
  PropSpec('opacity_on_click', PropType.number, 'pressedOpacity',
      skins: {Skin.cupertino},
      reason: 'iOS buttons fade when pressed; Material shows ink'),
  PropSpec('size', PropType.raw, 'sizeStyle',
      skins: {Skin.cupertino}, reason: 'CupertinoButtonSize'),
];

/// Not on OutlinedButton/TextButton (Ruby does not declare it there).
const _elevationProp = PropSpec('elevation', PropType.number, 'elevation');

/// The iOS alert-dialog action keys; Button only.
const _dialogActionProps = [
  PropSpec('default', PropType.boolean, 'isDefault',
      skins: {Skin.cupertino},
      reason: 'iOS alert-dialog action role (CupertinoDialogAction)'),
  PropSpec('destructive', PropType.boolean, 'isDestructive',
      skins: {Skin.cupertino},
      reason: 'iOS alert-dialog action role (CupertinoDialogAction)'),
  PropSpec('text_style', PropType.textStyle, 'textStyle',
      skins: {Skin.cupertino}, reason: 'iOS alert-dialog action text style'),
];

const _buttonEvents = [
  EventSpec('click', field: 'onClick'),
  EventSpec('long_press', field: 'onLongPress'),
  EventSpec('hover', source: EventSource.core),
  EventSpec('focus', source: EventSource.core),
  EventSpec('blur', source: EventSource.core),
  EventSpec('action_result', source: EventSource.core),
];

const _buttonMethods = [MethodSpec('focus'), MethodSpec('blur')];

/// Everything Ruby can send to each Button wire type, and which design
/// honors it.
const buttonSpec = ControlSpec(
  wireType: 'Button',
  props: [..._sharedProps, _elevationProp, ..._dialogActionProps],
  events: _buttonEvents,
  methods: _buttonMethods,
);
const filledButtonSpec = ControlSpec(
  wireType: 'FilledButton',
  props: [..._sharedProps, _elevationProp],
  events: _buttonEvents,
  methods: _buttonMethods,
);
const filledTonalButtonSpec = ControlSpec(
  wireType: 'FilledTonalButton',
  props: [..._sharedProps, _elevationProp],
  events: _buttonEvents,
  methods: _buttonMethods,
);
const outlinedButtonSpec = ControlSpec(
  wireType: 'OutlinedButton',
  props: _sharedProps,
  events: _buttonEvents,
  methods: _buttonMethods,
);
const textButtonSpec = ControlSpec(
  wireType: 'TextButton',
  props: _sharedProps,
  events: _buttonEvents,
  methods: _buttonMethods,
);

@immutable
class ButtonProps {
  ButtonProps.parse(PropReader r, ButtonCore core)
      : content = r.textOrWidget('content'),
        icon = r.iconOrWidget('icon'),
        iconColor = r.color('icon_color'),
        color = r.color('color'),
        bgcolor = r.color('bgcolor'),
        elevation =
            core.spec.prop('elevation') == null ? null : r.number('elevation'),
        style = r.raw('style'),
        clipBehavior = r.enumValue(Clip.values, 'clip_behavior', Clip.none),
        autofocus = r.boolean('autofocus'),
        url = r.raw('url'),
        action = r.raw('action'),
        alignment = r.alignment('alignment'),
        borderRadius = r.borderRadius('border_radius'),
        padding = r.edgeInsets('padding'),
        minSize = r.raw('min_size'),
        mouseCursor = r.mouseCursor('mouse_cursor'),
        focusColor = r.color('focus_color'),
        disabledBgcolor = r.color('disabled_bgcolor'),
        pressedOpacity = r.number('opacity_on_click'),
        sizeStyle = r.raw('size'),
        isDefault = core.spec.prop('default') != null && r.boolean('default'),
        isDestructive =
            core.spec.prop('destructive') != null && r.boolean('destructive'),
        textStyle = core.spec.prop('text_style') == null
            ? null
            : r.textStyle('text_style');

  final TextOrWidget? content;
  final Widget? icon;
  final Color? iconColor;
  final Color? color;
  final Color? bgcolor;
  final double? elevation;
  final RawProp style;
  final Clip clipBehavior;
  final bool autofocus;
  final RawProp url;
  final RawProp action;
  final Alignment? alignment;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final RawProp minSize;
  final MouseCursor? mouseCursor;
  final Color? focusColor;
  final Color? disabledBgcolor;
  final double? pressedOpacity;
  final RawProp sizeStyle;
  final bool isDefault;
  final bool isDestructive;
  final TextStyle? textStyle;
}

/// The shared button: click (and its `action` and `url`), long press, hover
/// and pressed state, focus and the `focus`/`blur` methods, identical on
/// Material and Cupertino. One core serves the five Button wire types; it picks its spec
/// and variant from its wire type.
class ButtonCore extends ControlCore<ButtonProps>
    with FocusableCore<ButtonProps> {
  ButtonCore(super.control);

  @override
  ControlSpec get spec => switch (wireType) {
        'FilledButton' => filledButtonSpec,
        'FilledTonalButton' => filledTonalButtonSpec,
        'OutlinedButton' => outlinedButtonSpec,
        'TextButton' => textButtonSpec,
        _ => buttonSpec,
      };

  ButtonVariant get variant => switch (wireType) {
        'FilledButton' => ButtonVariant.filled,
        'FilledTonalButton' => ButtonVariant.tonal,
        'OutlinedButton' => ButtonVariant.outlined,
        'TextButton' => ButtonVariant.text,
        _ => ButtonVariant.elevated,
      };

  /// An AlertDialog action: iOS renders it as a CupertinoDialogAction.
  bool get inAlertDialog => parentWireType == 'AlertDialog';

  @override
  ButtonProps parse(PropReader r) => ButtonProps.parse(r, this);

  bool _hovered = false;
  bool _pressed = false;

  @override
  Set<WidgetState> get states => {
        ...super.states,
        if (_hovered) WidgetState.hovered,
        if (_pressed) WidgetState.pressed,
      };

  /// Runs the client `action`s, opens `url` (if any) and fires `click`.
  /// Non-null while enabled, with or without a Ruby handler, so the button
  /// keeps its enabled look.
  VoidCallback? get onClick => enabled ? _click : null;

  /// Fires `long_press`. Non-null while enabled, so a long press never falls
  /// through to a click.
  VoidCallback? get onLongPress =>
      enabled ? () => events.fire('long_press') : null;

  void _click() {
    runClientActions(props.action);
    final Url? url = parseUrl(props.url.value);
    if (url != null) openWebBrowser(url);
    events.fire('click');
  }

  void _hover(bool hovered) {
    _hovered = hovered;
    events.fire('hover', hovered);
    markNeedsBuild();
  }

  void _press(bool pressed) {
    if (_pressed == pressed) return;
    _pressed = pressed;
    markNeedsBuild();
  }

  /// Hover (with the `hover` event) and pressed state are tracked once here
  /// for both designs, around the native button.
  @override
  Widget decorate(BuildContext context, Widget skin) => MouseRegion(
        onEnter: enabled ? (_) => _hover(true) : null,
        onExit: enabled ? (_) => _hover(false) : null,
        child: Listener(
          onPointerDown: enabled ? (_) => _press(true) : null,
          onPointerUp: (_) => _press(false),
          onPointerCancel: (_) => _press(false),
          child: skin,
        ),
      );
}
