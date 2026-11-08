import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';
import '../core/text_or_widget.dart';

const _material = 'Material AppBar; CupertinoNavigationBar has no such '
    'parameter';
const _materialText = 'Material AppBar text styles; the iOS bar uses the '
    'Cupertino navigation title style';
const _cupertino = 'CupertinoNavigationBar behaviour; the Material AppBar has '
    'no such parameter';

/// Everything Ruby can send to AppBar (`app_bar` and `cupertino_app_bar`),
/// and which design honors it.
const appBarSpec = ControlSpec(wireType: 'AppBar', props: [
  PropSpec('title', PropType.textOrWidget, 'title'),
  PropSpec('leading', PropType.widget, 'leading'),
  PropSpec('automatically_imply_leading', PropType.boolean,
      'automaticallyImplyLeading'),
  PropSpec('bgcolor', PropType.color, 'bgcolor'),
  PropSpec('large', PropType.boolean, 'large'),
  // The core composes the bar's end widgets for both designs.
  PropSpec('actions', PropType.widgets, 'actions', consumer: PropConsumer.core),
  PropSpec('trailing', PropType.widget, 'trailing',
      consumer: PropConsumer.core),
  PropSpec('leading_width', PropType.number, 'leadingWidth',
      skins: {Skin.material}, reason: _material),
  PropSpec('center_title', PropType.boolean, 'centerTitle',
      skins: {Skin.material}, reason: 'the iOS bar always centers its title'),
  PropSpec('toolbar_height', PropType.number, 'toolbarHeight',
      skins: {Skin.material},
      reason: 'the iOS bar has the fixed iOS navigation bar height'),
  PropSpec('color', PropType.color, 'color',
      skins: {Skin.material}, reason: _material),
  PropSpec('elevation', PropType.number, 'elevation',
      skins: {Skin.material}, reason: 'Material elevation; iOS bars are flat'),
  PropSpec('shadow_color', PropType.color, 'shadowColor',
      skins: {Skin.material}, reason: 'Material elevation; iOS bars are flat'),
  PropSpec('elevation_on_scroll', PropType.number, 'elevationOnScroll',
      skins: {Skin.material}, reason: 'Material elevation; iOS bars are flat'),
  PropSpec('force_material_transparency', PropType.boolean,
      'forceMaterialTransparency',
      skins: {Skin.material}, reason: _material),
  PropSpec('secondary', PropType.boolean, 'secondary',
      skins: {Skin.material},
      reason: 'Material status bar padding (`primary`); the iOS bar always '
          'pads for the status bar'),
  PropSpec('title_spacing', PropType.number, 'titleSpacing',
      skins: {Skin.material}, reason: _material),
  PropSpec(
      'exclude_header_semantics', PropType.boolean, 'excludeHeaderSemantics',
      skins: {Skin.material},
      reason: 'CupertinoNavigationBar always marks its title as a header'),
  PropSpec('clip_behavior', PropType.raw, 'clipBehavior',
      skins: {Skin.material}, reason: _material),
  PropSpec('shape', PropType.outlinedBorder, 'shape',
      skins: {Skin.material},
      reason: 'Material shape; the iOS bar draws `border`'),
  PropSpec('toolbar_opacity', PropType.number, 'toolbarOpacity',
      skins: {Skin.material}, reason: _material),
  PropSpec('actions_padding', PropType.edgeInsets, 'actionsPadding',
      skins: {Skin.material},
      reason: 'Material actions padding; the iOS bar pads with `padding`'),
  PropSpec('title_text_style', PropType.textStyle, 'titleTextStyle',
      skins: {Skin.material}, reason: _materialText),
  PropSpec('toolbar_text_style', PropType.textStyle, 'toolbarTextStyle',
      skins: {Skin.material}, reason: _materialText),
  PropSpec(
      'automatically_imply_title', PropType.boolean, 'automaticallyImplyTitle',
      skins: {Skin.cupertino},
      reason: 'iOS shows the route title; Material does not'),
  PropSpec(
      'transition_between_routes', PropType.boolean, 'transitionBetweenRoutes',
      skins: {Skin.cupertino}, reason: _cupertino),
  PropSpec('previous_page_title', PropType.string, 'previousPageTitle',
      skins: {Skin.cupertino}, reason: 'iOS back button label'),
  PropSpec('border', PropType.raw, 'border',
      skins: {Skin.cupertino}, reason: 'iOS bar border; Material uses `shape`'),
  PropSpec('padding', PropType.raw, 'padding',
      skins: {Skin.cupertino},
      reason: 'iOS bar padding; Material uses `title_spacing` and '
          '`actions_padding`'),
  PropSpec('brightness', PropType.raw, 'barBrightness',
      skins: {Skin.cupertino}, reason: _cupertino),
  PropSpec('automatic_background_visibility', PropType.boolean,
      'automaticBackgroundVisibility',
      skins: {Skin.cupertino}, reason: _cupertino),
  PropSpec('enable_background_filter_blur', PropType.boolean,
      'enableBackgroundFilterBlur',
      skins: {Skin.cupertino},
      reason: 'iOS translucent bar blur; Material bars are opaque'),
]);

@immutable
class AppBarProps {
  AppBarProps.parse(PropReader r)
      : title = r.textOrWidget('title'),
        leading = r.widget('leading'),
        automaticallyImplyLeading =
            r.boolean('automatically_imply_leading', true),
        bgcolor = r.color('bgcolor'),
        large = r.boolean('large'),
        actions = r.widgets('actions'),
        trailing = r.widget('trailing'),
        leadingWidth = r.number('leading_width'),
        centerTitle = r.optionalBoolean('center_title'),
        toolbarHeight = r.number('toolbar_height'),
        color = r.color('color'),
        elevation = r.number('elevation'),
        shadowColor = r.color('shadow_color'),
        elevationOnScroll = r.number('elevation_on_scroll'),
        forceMaterialTransparency = r.boolean('force_material_transparency'),
        secondary = r.boolean('secondary'),
        titleSpacing = r.number('title_spacing'),
        excludeHeaderSemantics = r.boolean('exclude_header_semantics'),
        clipBehavior = r.raw('clip_behavior'),
        shape = r.outlinedBorder('shape'),
        toolbarOpacity = r.number('toolbar_opacity', 1),
        actionsPadding = r.edgeInsets('actions_padding'),
        titleTextStyle = r.textStyle('title_text_style'),
        toolbarTextStyle = r.textStyle('toolbar_text_style'),
        automaticallyImplyTitle = r.boolean('automatically_imply_title', true),
        transitionBetweenRoutes = r.boolean('transition_between_routes', true),
        previousPageTitle = r.string('previous_page_title'),
        border = r.raw('border'),
        padding = r.raw('padding'),
        barBrightness = r.raw('brightness'),
        automaticBackgroundVisibility =
            r.boolean('automatic_background_visibility', true),
        enableBackgroundFilterBlur =
            r.boolean('enable_background_filter_blur', true);

  final TextOrWidget? title;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? bgcolor;
  final bool large;
  final List<Widget> actions;
  final Widget? trailing;
  final double? leadingWidth;
  final bool? centerTitle;
  final double? toolbarHeight;
  final Color? color;
  final double? elevation;
  final Color? shadowColor;
  final double? elevationOnScroll;
  final bool forceMaterialTransparency;
  final bool secondary;
  final double? titleSpacing;
  final bool excludeHeaderSemantics;
  final RawProp clipBehavior;
  final OutlinedBorder? shape;
  final double? toolbarOpacity;
  final EdgeInsets? actionsPadding;
  final TextStyle? titleTextStyle;
  final TextStyle? toolbarTextStyle;
  final bool automaticallyImplyTitle;
  final bool transitionBetweenRoutes;
  final String? previousPageTitle;
  final RawProp border;
  final RawProp padding;
  final RawProp barBrightness;
  final bool automaticBackgroundVisibility;
  final bool enableBackgroundFilterBlur;
}

/// What a scaffold reads from the bar before building it.
typedef AppBarSizing = ({bool large, double? toolbarHeight});

/// The shared app bar: its end widgets (composed once for both designs) and
/// the sizing contract a scaffold reads before building it. The skin is the
/// widget the scaffold is handed (it implements PreferredSizeWidget) and
/// hosts this core with `CoreHost.adopt`.
class AppBarCore extends ControlCore<AppBarProps> {
  AppBarCore(super.control);

  @override
  ControlSpec get spec => appBarSpec;

  @override
  AppBarProps parse(PropReader r) => AppBarProps.parse(r);

  /// The bar's end widgets: `trailing` (the `cupertino_app_bar` keyword)
  /// wins over `actions` on both designs.
  List<Widget> get endWidgets {
    final trailing = props.trailing;
    return trailing != null ? [trailing] : props.actions;
  }

  /// Whether the bar is large and the toolbar height Ruby sent, read before
  /// the bar builds: the scaffold sizes it first.
  AppBarSizing get sizing => (
        large: peekBoolean('large'),
        toolbarHeight: peekNumber('toolbar_height')
      );

  /// `bgcolor` in the scaffold's [context], read before the bar builds (an
  /// iOS scaffold asks whether the bar fully obstructs the content).
  Color? backgroundIn(BuildContext context) => peekColor('bgcolor', context);
}

/// What both skins are: the widget a scaffold is handed for the bar (so it
/// can read the bar's size first), built on an [AppBarCore] it hosts. The
/// registry entry's design switch returns one of them.
abstract class AppBarSkin extends StatelessWidget
    implements PreferredSizeWidget {
  const AppBarSkin({super.key, required this.core});

  final AppBarCore core;
}
