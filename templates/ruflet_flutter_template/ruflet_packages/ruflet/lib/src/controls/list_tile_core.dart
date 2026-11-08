import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';
import '../core/text_or_widget.dart';
import '../utils/launch_url.dart' show Url, openWebBrowser, parseUrl;
import '../widgets/list_tile_clicks.dart';

const _ink = 'Material ink; the iOS tile highlights with `bgcolor_activated`';
const _materialLayout = 'Material ListTile layout; the iOS tile has fixed '
    'iOS metrics (`leading_size`, `leading_to_title`, `notched`)';
const _materialColors = 'Material tile colors; iOS tiles keep the colors of '
    'their children';
const _materialText = 'Material ListTile text styles; the iOS tile uses the '
    'Cupertino text theme';
const _iosOnly = 'iOS list tile metrics';

/// Everything Ruby can send to ListTile (`list_tile` and
/// `cupertino_list_tile`), and which design honors it.
const listTileSpec = ControlSpec(wireType: 'ListTile', props: [
  PropSpec('title', PropType.textOrWidget, 'title'),
  PropSpec('subtitle', PropType.textOrWidget, 'subtitle'),
  PropSpec('leading', PropType.iconOrWidget, 'leading'),
  // The core composes the trailing widget with the chevron for both designs.
  PropSpec('trailing', PropType.iconOrWidget, 'trailing',
      consumer: PropConsumer.core),
  PropSpec('chevron', PropType.boolean, 'chevron', consumer: PropConsumer.core),
  PropSpec('bgcolor', PropType.color, 'bgcolor'),
  // `content_padding` (list_tile) and `padding` (cupertino_list_tile) are one
  // padding; the core resolves it for both designs.
  PropSpec('content_padding', PropType.edgeInsets, 'contentPadding',
      consumer: PropConsumer.core),
  PropSpec('padding', PropType.edgeInsets, 'padding',
      consumer: PropConsumer.core),
  PropSpec('selected', PropType.boolean, 'selected'),
  PropSpec('toggle_inputs', PropType.boolean, 'toggleInputs',
      consumer: PropConsumer.core),
  PropSpec('url', PropType.raw, 'url', consumer: PropConsumer.core),
  // Client actions run in the tap, before `click` (Flet's `action`).
  PropSpec('action', PropType.raw, 'action', consumer: PropConsumer.core),
  PropSpec('additional_info', PropType.textOrWidget, 'additionalInfo',
      skins: {Skin.cupertino},
      reason: 'iOS detail text before the trailing widget; Material tiles put '
          'such text in `trailing`'),
  PropSpec('bgcolor_activated', PropType.color, 'bgcolorActivated',
      skins: {Skin.cupertino},
      reason: 'iOS pressed background; Material tiles show ink '
          '(`splash_color`)'),
  PropSpec('notched', PropType.boolean, 'notched',
      skins: {Skin.cupertino}, reason: 'iOS inset grouped tile style'),
  PropSpec('leading_size', PropType.number, 'leadingSize',
      skins: {Skin.cupertino}, reason: _iosOnly),
  PropSpec('leading_to_title', PropType.number, 'leadingToTitle',
      skins: {Skin.cupertino},
      reason: '$_iosOnly; the Material gap is `horizontal_spacing`'),
  PropSpec('autofocus', PropType.boolean, 'autofocus',
      skins: {Skin.material},
      reason: 'Material tiles take keyboard focus; the iOS tile does not'),
  PropSpec('dense', PropType.boolean, 'dense',
      skins: {Skin.material}, reason: _materialLayout),
  PropSpec('is_three_line', PropType.boolean, 'isThreeLine',
      skins: {Skin.material}, reason: _materialLayout),
  PropSpec('horizontal_spacing', PropType.number, 'horizontalSpacing',
      skins: {Skin.material},
      reason: '$_materialLayout; the iOS gap is `leading_to_title`'),
  PropSpec('min_leading_width', PropType.number, 'minLeadingWidth',
      skins: {Skin.material}, reason: _materialLayout),
  PropSpec('min_vertical_padding', PropType.number, 'minVerticalPadding',
      skins: {Skin.material}, reason: _materialLayout),
  PropSpec('min_height', PropType.number, 'minHeight',
      skins: {Skin.material}, reason: _materialLayout),
  PropSpec('visual_density', PropType.raw, 'visualDensity',
      skins: {Skin.material}, reason: 'Material density'),
  PropSpec('style', PropType.raw, 'style',
      skins: {Skin.material}, reason: 'Material ListTileStyle (list/drawer)'),
  PropSpec('title_alignment', PropType.raw, 'titleAlignment',
      skins: {Skin.material}, reason: _materialLayout),
  PropSpec('shape', PropType.outlinedBorder, 'shape',
      skins: {Skin.material},
      reason: 'Material ink shape; the iOS tile is a plain row'),
  PropSpec('icon_color', PropType.color, 'iconColor',
      skins: {Skin.material}, reason: _materialColors),
  PropSpec('text_color', PropType.color, 'textColor',
      skins: {Skin.material}, reason: _materialColors),
  PropSpec('selected_color', PropType.color, 'selectedColor',
      skins: {Skin.material}, reason: _materialColors),
  PropSpec('selected_tile_color', PropType.color, 'selectedTileColor',
      skins: {Skin.material}, reason: _materialColors),
  PropSpec('focus_color', PropType.color, 'focusColor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('hover_color', PropType.color, 'hoverColor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('splash_color', PropType.color, 'splashColor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('enable_feedback', PropType.boolean, 'enableFeedback',
      skins: {Skin.material},
      reason: 'Material tap sound and haptics; the iOS tile gives none'),
  PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor',
      skins: {Skin.material}, reason: _ink),
  PropSpec('title_text_style', PropType.textStyle, 'titleTextStyle',
      skins: {Skin.material}, reason: _materialText),
  PropSpec('subtitle_text_style', PropType.textStyle, 'subtitleTextStyle',
      skins: {Skin.material}, reason: _materialText),
  PropSpec('leading_and_trailing_text_style', PropType.textStyle,
      'leadingAndTrailingTextStyle',
      skins: {Skin.material}, reason: _materialText),
], events: [
  EventSpec('click', field: 'onTap'),
  EventSpec('long_press', field: 'onLongPress'),
  EventSpec('action_result', source: EventSource.core),
]);

@immutable
class ListTileProps {
  ListTileProps.parse(PropReader r)
      : title = r.textOrWidget('title'),
        subtitle = r.textOrWidget('subtitle'),
        leading = r.iconOrWidget('leading'),
        trailing = r.iconOrWidget('trailing'),
        chevron = r.boolean('chevron'),
        bgcolor = r.color('bgcolor'),
        contentPadding = r.edgeInsets('content_padding'),
        padding = r.edgeInsets('padding'),
        selected = r.boolean('selected'),
        toggleInputs = r.boolean('toggle_inputs'),
        url = r.raw('url'),
        action = r.raw('action'),
        additionalInfo = r.textOrWidget('additional_info'),
        bgcolorActivated = r.color('bgcolor_activated'),
        notched = r.boolean('notched'),
        leadingSize = r.number('leading_size'),
        leadingToTitle = r.number('leading_to_title'),
        autofocus = r.boolean('autofocus'),
        dense = r.optionalBoolean('dense'),
        isThreeLine = r.optionalBoolean('is_three_line'),
        horizontalSpacing = r.number('horizontal_spacing'),
        minLeadingWidth = r.number('min_leading_width'),
        minVerticalPadding = r.number('min_vertical_padding'),
        minHeight = r.number('min_height'),
        visualDensity = r.raw('visual_density'),
        style = r.raw('style'),
        titleAlignment = r.raw('title_alignment'),
        shape = r.outlinedBorder('shape'),
        iconColor = r.color('icon_color'),
        textColor = r.color('text_color'),
        selectedColor = r.color('selected_color'),
        selectedTileColor = r.color('selected_tile_color'),
        focusColor = r.color('focus_color'),
        hoverColor = r.color('hover_color'),
        splashColor = r.color('splash_color'),
        enableFeedback = r.optionalBoolean('enable_feedback'),
        mouseCursor = r.mouseCursor('mouse_cursor'),
        titleTextStyle = r.textStyle('title_text_style'),
        subtitleTextStyle = r.textStyle('subtitle_text_style'),
        leadingAndTrailingTextStyle =
            r.textStyle('leading_and_trailing_text_style');

  final TextOrWidget? title;
  final TextOrWidget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool chevron;
  final Color? bgcolor;
  final EdgeInsets? contentPadding;
  final EdgeInsets? padding;
  final bool selected;
  final bool toggleInputs;
  final RawProp url;
  final RawProp action;
  final TextOrWidget? additionalInfo;
  final Color? bgcolorActivated;
  final bool notched;
  final double? leadingSize;
  final double? leadingToTitle;
  final bool autofocus;
  final bool? dense;
  final bool? isThreeLine;
  final double? horizontalSpacing;
  final double? minLeadingWidth;
  final double? minVerticalPadding;
  final double? minHeight;
  final RawProp visualDensity;
  final RawProp style;
  final RawProp titleAlignment;
  final OutlinedBorder? shape;
  final Color? iconColor;
  final Color? textColor;
  final Color? selectedColor;
  final Color? selectedTileColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? splashColor;
  final bool? enableFeedback;
  final MouseCursor? mouseCursor;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final TextStyle? leadingAndTrailingTextStyle;
}

/// The shared list tile: what a tap does (click, `action`, `url`, and
/// toggling the inputs inside a `toggle_inputs` tile), long press, the
/// padding and the trailing chevron, identical on Material and Cupertino.
class ListTileCore extends ControlCore<ListTileProps> {
  ListTileCore(super.control);

  @override
  ControlSpec get spec => listTileSpec;

  @override
  ListTileProps parse(PropReader r) => ListTileProps.parse(r);

  /// One notifier for the core's lifetime: the toggles inside the tile
  /// subscribe to it through [ListTileClicks].
  final ListTileClickNotifier _clicks = ListTileClickNotifier();

  /// Runs the client `action`s, toggles the tile's inputs
  /// (`toggle_inputs`), opens `url` and fires `click`. Null while disabled,
  /// or when a tap would do nothing, which also turns off the native tap
  /// feedback.
  VoidCallback? get onTap {
    if (disabled) return null;
    final click = events.callback('click');
    final toggleInputs = props.toggleInputs;
    final Url? url = parseUrl(props.url.value);
    final action = props.action;
    if (click == null &&
        !toggleInputs &&
        url == null &&
        !hasClientActions(action)) {
      return null;
    }
    return () {
      runClientActions(action);
      if (toggleInputs) _clicks.onClick();
      if (url != null) openWebBrowser(url);
      click?.call();
    };
  }

  /// Fires `long_press`. Null while disabled or without a Ruby handler.
  VoidCallback? get onLongPress => events.callback('long_press');

  /// `content_padding`, or Ruby's `cupertino_list_tile(padding:)`.
  EdgeInsets? get tilePadding => props.contentPadding ?? props.padding;

  /// The trailing widget followed by the design's [chevron] glyph when Ruby
  /// asked for one, with the same spacing on both designs.
  Widget? trailingWithChevron(Widget chevron) {
    final trailing = props.trailing;
    if (!props.chevron) return trailing;
    if (trailing == null) return chevron;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [trailing, const SizedBox(width: 6), chevron],
    );
  }

  @override
  Widget decorate(BuildContext context, Widget skin) => props.toggleInputs
      ? ListTileClicks(notifier: _clicks, child: skin)
      : skin;

  @override
  void disposeCore() {
    _clicks.dispose();
    super.disposeCore();
  }
}
