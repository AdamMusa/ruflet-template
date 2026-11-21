import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';
import '../utils/launch_url.dart' show Url, openWebBrowser, parseUrl;

/// The visual variant an IconButton wire type selects.
enum IconButtonVariant { standard, filled, tonal, outlined }

const _ink = 'Material ink; iOS buttons fade when pressed';

/// Keys every IconButton wire type accepts (Ruby declares the same set on all
/// four).
const _iconButtonProps = [
  PropSpec('icon', PropType.iconOrWidget, 'icon'),
  PropSpec('selected_icon', PropType.iconOrWidget, 'selectedIcon'),
  PropSpec('icon_color', PropType.color, 'iconColor'),
  PropSpec('selected_icon_color', PropType.color, 'selectedIconColor'),
  PropSpec('disabled_color', PropType.color, 'disabledColor'),
  PropSpec('icon_size', PropType.number, 'iconSize'),
  PropSpec('selected', PropType.boolean, 'selected'),
  PropSpec('autofocus', PropType.boolean, 'autofocus'),
  PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor'),
  PropSpec('alignment', PropType.alignment, 'alignment'),
  PropSpec('padding', PropType.edgeInsets, 'padding'),
  PropSpec('focus_color', PropType.color, 'focusColor'),
  PropSpec('enable_feedback', PropType.boolean, 'enableFeedback'),
  PropSpec('style', PropType.raw, 'style'),
  PropSpec('url', PropType.raw, 'url', consumer: PropConsumer.core),
  // Client actions run in the tap, before `click` (Flet's `action`).
  PropSpec('action', PropType.raw, 'action', consumer: PropConsumer.core),
  PropSpec('bgcolor', PropType.color, 'bgcolor',
      skins: {Skin.cupertino},
      reason: 'CupertinoButton background; Material icon buttons take it '
          'through `style.bgcolor`'),
  PropSpec('highlight_color', PropType.color, 'highlightColor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('hover_color', PropType.color, 'hoverColor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('splash_color', PropType.color, 'splashColor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('splash_radius', PropType.number, 'splashRadius',
      skins: {Skin.material}, reason: _ink),
  PropSpec('visual_density', PropType.raw, 'visualDensity',
      skins: {Skin.material}, reason: 'Material density'),
  PropSpec('size_constraints', PropType.raw, 'sizeConstraints',
      skins: {Skin.material},
      reason: 'Material IconButton constraints; CupertinoButton sizes from '
          '`style.minimum_size`/`fixed_size`'),
];

const _iconButtonEvents = [
  EventSpec('click', field: 'onClick'),
  EventSpec('long_press', field: 'onLongPress'),
  EventSpec('hover', source: EventSource.core),
  EventSpec('focus', source: EventSource.core),
  EventSpec('blur', source: EventSource.core),
  EventSpec('action_result', source: EventSource.core),
];

const _iconButtonMethods = [MethodSpec('focus'), MethodSpec('blur')];

/// Everything Ruby can send to each IconButton wire type, and which design
/// honors it.
const iconButtonSpec = ControlSpec(
    wireType: 'IconButton',
    props: _iconButtonProps,
    events: _iconButtonEvents,
    methods: _iconButtonMethods);
const filledIconButtonSpec = ControlSpec(
    wireType: 'FilledIconButton',
    props: _iconButtonProps,
    events: _iconButtonEvents,
    methods: _iconButtonMethods);
const filledTonalIconButtonSpec = ControlSpec(
    wireType: 'FilledTonalIconButton',
    props: _iconButtonProps,
    events: _iconButtonEvents,
    methods: _iconButtonMethods);
const outlinedIconButtonSpec = ControlSpec(
    wireType: 'OutlinedIconButton',
    props: _iconButtonProps,
    events: _iconButtonEvents,
    methods: _iconButtonMethods);

@immutable
class IconButtonProps {
  IconButtonProps.parse(PropReader r)
      : icon = r.iconOrWidget('icon'),
        selectedIcon = r.iconOrWidget('selected_icon'),
        iconColor = r.color('icon_color'),
        selectedIconColor = r.color('selected_icon_color'),
        disabledColor = r.color('disabled_color'),
        iconSize = r.number('icon_size'),
        selected = r.optionalBoolean('selected'),
        autofocus = r.boolean('autofocus'),
        mouseCursor = r.mouseCursor('mouse_cursor'),
        alignment = r.alignment('alignment'),
        padding = r.edgeInsets('padding'),
        focusColor = r.color('focus_color'),
        enableFeedback = r.optionalBoolean('enable_feedback'),
        style = r.raw('style'),
        url = r.raw('url'),
        action = r.raw('action'),
        bgcolor = r.color('bgcolor'),
        highlightColor = r.color('highlight_color'),
        hoverColor = r.color('hover_color'),
        splashColor = r.color('splash_color'),
        splashRadius = r.number('splash_radius'),
        visualDensity = r.raw('visual_density'),
        sizeConstraints = r.raw('size_constraints');

  final Widget? icon;
  final Widget? selectedIcon;
  final Color? iconColor;
  final Color? selectedIconColor;
  final Color? disabledColor;
  final double? iconSize;

  /// Null when Ruby did not send it: the button is not a toggle.
  final bool? selected;
  final bool autofocus;
  final MouseCursor? mouseCursor;
  final Alignment? alignment;
  final EdgeInsets? padding;
  final Color? focusColor;
  final bool? enableFeedback;
  final RawProp style;
  final RawProp url;
  final RawProp action;
  final Color? bgcolor;
  final Color? highlightColor;
  final Color? hoverColor;
  final Color? splashColor;
  final double? splashRadius;
  final RawProp visualDensity;
  final RawProp sizeConstraints;
}

/// The shared icon button: click (and its `action` and `url`), long press,
/// hover and pressed state, the selected state, focus and the `focus`/`blur`
/// methods, identical on Material and Cupertino. One core serves the four IconButton
/// wire types; it picks its spec and variant from its wire type.
class IconButtonCore extends ControlCore<IconButtonProps>
    with FocusableCore<IconButtonProps> {
  IconButtonCore(super.control);

  @override
  ControlSpec get spec => switch (wireType) {
        'FilledIconButton' => filledIconButtonSpec,
        'FilledTonalIconButton' => filledTonalIconButtonSpec,
        'OutlinedIconButton' => outlinedIconButtonSpec,
        _ => iconButtonSpec,
      };

  IconButtonVariant get variant => switch (wireType) {
        'FilledIconButton' => IconButtonVariant.filled,
        'FilledTonalIconButton' => IconButtonVariant.tonal,
        'OutlinedIconButton' => IconButtonVariant.outlined,
        _ => IconButtonVariant.standard,
      };

  /// A plain IconButton leading an AppBar: iOS shows its native back
  /// chevron for a Material back arrow there. The filled, tonal and outlined
  /// variants keep their glyph, as before the move onto the core.
  bool get isAppBarLeading =>
      variant == IconButtonVariant.standard &&
      parentWireType == 'AppBar' &&
      parentSlot == 'leading';

  @override
  IconButtonProps parse(PropReader r) => IconButtonProps.parse(r);

  bool _hovered = false;
  bool _pressed = false;

  bool get selected => props.selected ?? false;

  @override
  Set<WidgetState> get states => {
        ...super.states,
        if (selected) WidgetState.selected,
        if (_hovered) WidgetState.hovered,
        if (_pressed) WidgetState.pressed,
      };

  /// Runs the client `action`s, opens `url` (if any) and fires `click`.
  /// Non-null while enabled.
  VoidCallback? get onClick => enabled ? _click : null;

  /// Fires `long_press`. Non-null while enabled.
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
