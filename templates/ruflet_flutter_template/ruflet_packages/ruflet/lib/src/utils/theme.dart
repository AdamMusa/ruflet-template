import 'material_enums.dart';
import 'material_style_theme.dart';
import 'platform_theme.dart';
export 'platform_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import '../utils/tabs.dart';
import '../utils/transforms.dart';
import 'alignment.dart';
import 'animations.dart';
import 'borders.dart';
import 'box.dart';
import 'buttons.dart';
import 'colors.dart';
import 'dismissible.dart';
import 'edge_insets.dart';
import 'enums.dart';
import 'geometry.dart';
import 'icons.dart';
import 'menu.dart';
import 'misc.dart';
import 'mouse.dart';
import 'numbers.dart';
import 'overlay_style.dart';
import 'text.dart';
import 'time.dart';
import 'tooltip.dart';
import 'widget_state.dart';

class SystemUiOverlayStyleTheme
    extends ThemeExtension<SystemUiOverlayStyleTheme> {
  final SystemUiOverlayStyle? systemUiOverlayStyle;
  SystemUiOverlayStyleTheme(this.systemUiOverlayStyle);

  @override
  SystemUiOverlayStyleTheme copyWith() {
    return SystemUiOverlayStyleTheme(systemUiOverlayStyle);
  }

  @override
  SystemUiOverlayStyleTheme lerp(
      covariant SystemUiOverlayStyleTheme? other, double t) {
    if (other is! SystemUiOverlayStyleTheme) {
      return this;
    }
    return other;
  }

  @override
  bool operator ==(Object other) {
    return systemUiOverlayStyle ==
        (other as SystemUiOverlayStyleTheme).systemUiOverlayStyle;
  }

  @override
  int get hashCode => systemUiOverlayStyle.hashCode;
}

ThemeMode? parseThemeMode(String? value, [ThemeMode? defaultValue]) {
  return parseEnum(ThemeMode.values, value, defaultValue);
}

ThemeData parseTheme(
    dynamic value, BuildContext context, Brightness? brightness,
    {ThemeData? parentTheme}) {
  ThemeData? theme = parentTheme;

  var colorSchemeSeed = parseColor(value?["color_scheme_seed"],
          (theme == null ? null : materialStyleTheme(theme))) ??
      Colors.blue;

  // create new theme
  theme ??= ThemeData(
    colorSchemeSeed: colorSchemeSeed,
    fontFamily: value?["font_family"],
    brightness: brightness,
    useMaterial3: value?["use_material3"],
  );

  ColorScheme? colorScheme = parseColorScheme(value?["color_scheme"], theme);
  DividerThemeData? dividerTheme =
      parseDividerTheme(value?["divider_theme"], theme);

  theme = theme.copyWith(
    extensions: {
      SystemUiOverlayStyleTheme(value?["system_overlay_style"] != null
          ? parseSystemUiOverlayStyle(value?["system_overlay_style"],
              materialStyleTheme(theme), brightness)
          : null)
    },
    visualDensity:
        parseVisualDensity(value?["visual_density"], theme.visualDensity)!,
    pageTransitionsTheme: parsePageTransitions(
        value?["page_transitions"], theme.pageTransitionsTheme)!,
    colorScheme: colorScheme,
    textTheme: parseTextTheme(value?["text_theme"], theme, theme.textTheme),
    primaryTextTheme: parseTextTheme(
        value?["primary_text_theme"], theme, theme.primaryTextTheme),
    scrollbarTheme: parseScrollBarTheme(value?["scrollbar_theme"], theme),
    tabBarTheme: parseTabBarTheme(value?["tab_bar_theme"], theme),
    splashColor: parseColor(value?["splash_color"], materialStyleTheme(theme)),
    highlightColor:
        parseColor(value?["highlight_color"], materialStyleTheme(theme)),
    hoverColor: parseColor(value?["hover_color"], materialStyleTheme(theme)),
    focusColor: parseColor(value?["focus_color"], materialStyleTheme(theme)),
    unselectedWidgetColor: parseColor(
        value?["unselected_control_color"], materialStyleTheme(theme)),
    disabledColor:
        parseColor(value?["disabled_color"], materialStyleTheme(theme)),
    canvasColor: parseColor(value?["canvas_color"], materialStyleTheme(theme)),
    scaffoldBackgroundColor:
        parseColor(value?["scaffold_bgcolor"], materialStyleTheme(theme)),
    cardColor: parseColor(value?["card_bgcolor"], materialStyleTheme(theme)),
    dividerColor:
        parseColor(value?["divider_color"], materialStyleTheme(theme)),
    hintColor: parseColor(value?["hint_color"], materialStyleTheme(theme)),
    shadowColor: colorScheme?.shadow,
    secondaryHeaderColor:
        parseColor(value?["secondary_header_color"], materialStyleTheme(theme)),
    dialogTheme: parseDialogTheme(value?["dialog_theme"], theme),
    bottomSheetTheme:
        parseBottomSheetTheme(value?["bottom_sheet_theme"], theme),
    cardTheme: parseCardTheme(value?["card_theme"], theme),
    chipTheme: parseChipTheme(value?["chip_theme"], theme),
    floatingActionButtonTheme: parseFloatingActionButtonTheme(
        value?["floating_action_button_theme"], theme),
    bottomAppBarTheme:
        parseBottomAppBarTheme(value?["bottom_app_bar_theme"], theme),
    checkboxTheme: parseCheckboxTheme(value?["checkbox_theme"], theme),
    radioTheme: parseRadioTheme(value?["radio_theme"], theme),
    badgeTheme: parseBadgeTheme(value?["badge_theme"], theme),
    switchTheme: parseSwitchTheme(value?["switch_theme"], context),
    dividerTheme: dividerTheme,
    snackBarTheme: parseSnackBarTheme(value?["snackbar_theme"], theme),
    bannerTheme: parseBannerTheme(value?["banner_theme"], theme),
    datePickerTheme: parseDatePickerTheme(value?["date_picker_theme"], theme),
    navigationRailTheme:
        parseNavigationRailTheme(value?["navigation_rail_theme"], theme),
    appBarTheme: parseAppBarTheme(value?["appbar_theme"], theme),
    dropdownMenuTheme: parseDropdownMenuTheme(value?["dropdown_theme"], theme),
    listTileTheme: parseListTileTheme(value?["list_tile_theme"], theme),
    tooltipTheme: parseTooltipTheme(value?["tooltip_theme"], context),
    expansionTileTheme:
        parseExpansionTileTheme(value?["expansion_tile_theme"], theme),
    sliderTheme: parseSliderTheme(value?["slider_theme"], theme),
    progressIndicatorTheme:
        parseProgressIndicatorTheme(value?["progress_indicator_theme"], theme),
    popupMenuTheme: parsePopupMenuTheme(value?["popup_menu_theme"], theme),
    searchBarTheme: parseSearchBarTheme(value?["search_bar_theme"], theme),
    searchViewTheme: parseSearchViewTheme(value?["search_view_theme"], theme),
    navigationDrawerTheme:
        parseNavigationDrawerTheme(value?["navigation_drawer_theme"], theme),
    navigationBarTheme:
        parseNavigationBarTheme(value?["navigation_bar_theme"], theme),
    dataTableTheme: parseDataTableTheme(value?["data_table_theme"], context),
    elevatedButtonTheme: parseButtonTheme(value?["button_theme"], theme),
    outlinedButtonTheme:
        parseOutlinedButtonTheme(value?["outlined_button_theme"], theme),
    textButtonTheme: parseTextButtonTheme(value?["text_button_theme"], theme),
    filledButtonTheme:
        parseFilledButtonTheme(value?["filled_button_theme"], theme),
    iconButtonTheme: parseIconButtonTheme(value?["icon_button_theme"], theme),
    segmentedButtonTheme: parseSegmentedButtonTheme(
        value?["segmented_button_theme"], theme, context),
    iconTheme: parseIconTheme(value?["icon_theme"], theme),
    timePickerTheme: parseTimePickerTheme(value?["time_picker_theme"], theme),
  );

  return theme;
}

ColorScheme? parseColorScheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [ColorScheme? defaultValue]) {
  if (value == null) return defaultValue;
  return theme.colorScheme.copyWith(
    primary: parseColor(value["primary"], materialStyleTheme(theme)),
    onPrimary: parseColor(value["on_primary"], materialStyleTheme(theme)),
    primaryContainer:
        parseColor(value["primary_container"], materialStyleTheme(theme)),
    onPrimaryContainer:
        parseColor(value["on_primary_container"], materialStyleTheme(theme)),
    secondary: parseColor(value["secondary"], materialStyleTheme(theme)),
    onSecondary: parseColor(value["on_secondary"], materialStyleTheme(theme)),
    secondaryContainer:
        parseColor(value["secondary_container"], materialStyleTheme(theme)),
    onSecondaryContainer:
        parseColor(value["on_secondary_container"], materialStyleTheme(theme)),
    tertiary: parseColor(value["tertiary"], materialStyleTheme(theme)),
    onTertiary: parseColor(value["on_tertiary"], materialStyleTheme(theme)),
    tertiaryContainer:
        parseColor(value["tertiary_container"], materialStyleTheme(theme)),
    onTertiaryContainer:
        parseColor(value["on_tertiary_container"], materialStyleTheme(theme)),
    error: parseColor(value["error"], materialStyleTheme(theme)),
    onError: parseColor(value["on_error"], materialStyleTheme(theme)),
    errorContainer:
        parseColor(value["error_container"], materialStyleTheme(theme)),
    onErrorContainer:
        parseColor(value["on_error_container"], materialStyleTheme(theme)),
    surface: parseColor(value["surface"], materialStyleTheme(theme)),
    onSurface: parseColor(value["on_surface"], materialStyleTheme(theme)),
    onSurfaceVariant:
        parseColor(value["on_surface_variant"], materialStyleTheme(theme)),
    outline: parseColor(value["outline"], materialStyleTheme(theme)),
    outlineVariant:
        parseColor(value["outline_variant"], materialStyleTheme(theme)),
    shadow: parseColor(value["shadow"], materialStyleTheme(theme)),
    scrim: parseColor(value["scrim"], materialStyleTheme(theme)),
    inverseSurface:
        parseColor(value["inverse_surface"], materialStyleTheme(theme)),
    onInverseSurface:
        parseColor(value["on_inverse_surface"], materialStyleTheme(theme)),
    inversePrimary:
        parseColor(value["inverse_primary"], materialStyleTheme(theme)),
    surfaceTint: parseColor(value["surface_tint"], materialStyleTheme(theme)),
    onPrimaryFixed:
        parseColor(value["on_primary_fixed"], materialStyleTheme(theme)),
    onSecondaryFixed:
        parseColor(value["on_secondary_fixed"], materialStyleTheme(theme)),
    onTertiaryFixed:
        parseColor(value["on_tertiary_fixed"], materialStyleTheme(theme)),
    onPrimaryFixedVariant: parseColor(
        value["on_primary_fixed_variant"], materialStyleTheme(theme)),
    onSecondaryFixedVariant: parseColor(
        value["on_secondary_fixed_variant"], materialStyleTheme(theme)),
    onTertiaryFixedVariant: parseColor(
        value["on_tertiary_fixed_variant"], materialStyleTheme(theme)),
    primaryFixed: parseColor(value["primary_fixed"], materialStyleTheme(theme)),
    secondaryFixed:
        parseColor(value["secondary_fixed"], materialStyleTheme(theme)),
    tertiaryFixed:
        parseColor(value["tertiary_fixed"], materialStyleTheme(theme)),
    primaryFixedDim:
        parseColor(value["primary_fixed_dim"], materialStyleTheme(theme)),
    secondaryFixedDim:
        parseColor(value["secondary_fixed_dim"], materialStyleTheme(theme)),
    surfaceBright:
        parseColor(value["surface_bright"], materialStyleTheme(theme)),
    surfaceContainer:
        parseColor(value["surface_container"], materialStyleTheme(theme)),
    surfaceContainerHigh:
        parseColor(value["surface_container_high"], materialStyleTheme(theme)),
    surfaceContainerHighest: parseColor(
        value["surface_container_highest"], materialStyleTheme(theme)),
    surfaceContainerLow:
        parseColor(value["surface_container_low"], materialStyleTheme(theme)),
    surfaceContainerLowest: parseColor(
        value["surface_container_lowest"], materialStyleTheme(theme)),
    surfaceDim: parseColor(value["surface_dim"], materialStyleTheme(theme)),
    tertiaryFixedDim:
        parseColor(value["tertiary_fixed_dim"], materialStyleTheme(theme)),
  );
}

TextTheme? parseTextTheme(
    Map<dynamic, dynamic>? value, ThemeData theme, TextTheme textTheme,
    [TextTheme? defaultValue]) {
  if (value == null) return defaultValue;

  return textTheme.copyWith(
    bodyLarge: parseTextStyle(value["body_large"], materialStyleTheme(theme)),
    bodyMedium: parseTextStyle(value["body_medium"], materialStyleTheme(theme)),
    bodySmall: parseTextStyle(value["body_small"], materialStyleTheme(theme)),
    displayLarge:
        parseTextStyle(value["display_large"], materialStyleTheme(theme)),
    displayMedium:
        parseTextStyle(value["display_medium"], materialStyleTheme(theme)),
    displaySmall:
        parseTextStyle(value["display_small"], materialStyleTheme(theme)),
    headlineLarge:
        parseTextStyle(value["headline_large"], materialStyleTheme(theme)),
    headlineMedium:
        parseTextStyle(value["headline_medium"], materialStyleTheme(theme)),
    headlineSmall:
        parseTextStyle(value["headline_small"], materialStyleTheme(theme)),
    labelLarge: parseTextStyle(value["label_large"], materialStyleTheme(theme)),
    labelMedium:
        parseTextStyle(value["label_medium"], materialStyleTheme(theme)),
    labelSmall: parseTextStyle(value["label_small"], materialStyleTheme(theme)),
    titleLarge: parseTextStyle(value["title_large"], materialStyleTheme(theme)),
    titleMedium:
        parseTextStyle(value["title_medium"], materialStyleTheme(theme)),
    titleSmall: parseTextStyle(value["title_small"], materialStyleTheme(theme)),
  );
}

ElevatedButtonThemeData? parseButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [ElevatedButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return ElevatedButtonThemeData(
      style: parseButtonStyle(value["style"], theme));
}

OutlinedButtonThemeData? parseOutlinedButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [OutlinedButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return OutlinedButtonThemeData(
      style: parseButtonStyle(value["style"], theme));
}

TextButtonThemeData? parseTextButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [TextButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return TextButtonThemeData(style: parseButtonStyle(value["style"], theme));
}

FilledButtonThemeData? parseFilledButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [FilledButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return FilledButtonThemeData(style: parseButtonStyle(value["style"], theme));
}

IconButtonThemeData? parseIconButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [IconButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return IconButtonThemeData(style: parseButtonStyle(value["style"], theme));
}

DataTableThemeData? parseDataTableTheme(
    Map<dynamic, dynamic>? value, BuildContext context,
    [DataTableThemeData? defaultValue]) {
  if (value == null) return defaultValue;
  var theme = Theme.of(context);

  return theme.dataTableTheme.copyWith(
    checkboxHorizontalMargin: parseDouble(value["checkbox_horizontal_margin"]),
    columnSpacing: parseDouble(value["column_spacing"]),
    dataRowMaxHeight: parseDouble(value["data_row_max_height"]),
    dataRowMinHeight: parseDouble(value["data_row_min_height"]),
    dataRowColor: parseWidgetStateColor(
        value["data_row_color"], materialStyleTheme(theme)),
    dataTextStyle:
        parseTextStyle(value["data_text_style"], materialStyleTheme(theme)),
    dividerThickness: parseDouble(value["divider_thickness"]),
    horizontalMargin: parseDouble(value["horizontal_margin"]),
    headingTextStyle:
        parseTextStyle(value["heading_text_style"], materialStyleTheme(theme)),
    headingRowColor: parseWidgetStateColor(
        value["heading_row_color"], materialStyleTheme(theme)),
    headingRowHeight: parseDouble(value["heading_row_height"]),
    dataRowCursor: parseWidgetStateMouseCursor(value["data_row_cursor"]),
    decoration: parseBoxDecoration(value["decoration"], context),
    headingRowAlignment: parseMainAxisAlignment(value["heading_row_alignment"]),
    headingCellCursor:
        parseWidgetStateMouseCursor(value["heading_cell_cursor"]),
  );
}

ScrollbarThemeData? parseScrollBarTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [ScrollbarThemeData? defaultValue]) {
  if (value == null) return defaultValue;
  return theme.scrollbarTheme.copyWith(
    trackVisibility: parseWidgetStateBool(value["track_visibility"]),
    trackColor:
        parseWidgetStateColor(value["track_color"], materialStyleTheme(theme)),
    trackBorderColor: parseWidgetStateColor(
        value["track_border_color"], materialStyleTheme(theme)),
    thumbVisibility: parseWidgetStateBool(value["thumb_visibility"]),
    thumbColor:
        parseWidgetStateColor(value["thumb_color"], materialStyleTheme(theme)),
    thickness: parseWidgetStateDouble(value["thickness"]),
    radius: parseRadius(value["radius"]),
    crossAxisMargin: parseDouble(value["cross_axis_margin"]),
    mainAxisMargin: parseDouble(value["main_axis_margin"]),
    minThumbLength: parseDouble(value["min_thumb_length"]),
    interactive: parseBool(value["interactive"]),
  );
}

TabBarThemeData? parseTabBarTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [TabBarThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  var indicatorColor = parseColor(value["indicator_color"],
      materialStyleTheme(theme), theme.colorScheme.primary)!;

  return theme.tabBarTheme.copyWith(
      indicatorSize: parseTabBarIndicatorSize(value["indicator_size"]),
      indicator: parseUnderlineTabIndicator(value["indicator"], theme),
      indicatorAnimation:
          parseTabIndicatorAnimation(value["indicator_animation"]),
      splashBorderRadius: parseBorderRadius(value["splash_border_radius"]),
      tabAlignment: parseTabAlignment(value["tab_alignment"]),
      overlayColor: parseWidgetStateColor(
          value["overlay_color"], materialStyleTheme(theme)),
      dividerColor:
          parseColor(value["divider_color"], materialStyleTheme(theme)),
      indicatorColor: indicatorColor,
      mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
      dividerHeight: parseDouble(value["divider_height"]),
      labelColor: parseColor(value["label_color"], materialStyleTheme(theme)),
      unselectedLabelColor: parseColor(
          value["unselected_label_color"], materialStyleTheme(theme)),
      labelPadding: parsePadding(value["label_padding"]),
      labelStyle:
          parseTextStyle(value["label_text_style"], materialStyleTheme(theme)),
      unselectedLabelStyle: parseTextStyle(
          value["unselected_label_text_style"], materialStyleTheme(theme)));
}

VisualDensity? parseVisualDensity(String? density,
    [VisualDensity? defaultValue]) {
  switch (density?.toLowerCase()) {
    case "adaptiveplatformdensity":
      return VisualDensity.adaptivePlatformDensity;
    case "comfortable":
      return VisualDensity.comfortable;
    case "compact":
      return VisualDensity.compact;
    case "standard":
      return VisualDensity.standard;
    default:
      return defaultValue;
  }
}

PageTransitionsTheme? parsePageTransitions(Map<dynamic, dynamic>? value,
    [PageTransitionsTheme? defaultValue]) {
  if (value == null) {
    return defaultValue;
  }
  return PageTransitionsTheme(builders: {
    TargetPlatform.android: parseTransitionsBuilder(
        value["android"], const FadeUpwardsPageTransitionsBuilder())!,
    TargetPlatform.iOS: parseTransitionsBuilder(
        value["ios"], const CupertinoPageTransitionsBuilder())!,
    TargetPlatform.linux: parseTransitionsBuilder(
        value["linux"], const ZoomPageTransitionsBuilder())!,
    TargetPlatform.macOS: parseTransitionsBuilder(
        value["macos"], const ZoomPageTransitionsBuilder())!,
    TargetPlatform.windows: parseTransitionsBuilder(
        value["windows"], const ZoomPageTransitionsBuilder())!,
  });
}

DialogThemeData? parseDialogTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [DialogThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.dialogTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    iconColor: parseColor(value["icon_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    titleTextStyle:
        parseTextStyle(value["title_text_style"], materialStyleTheme(theme)),
    contentTextStyle:
        parseTextStyle(value["content_text_style"], materialStyleTheme(theme)),
    alignment: parseAlignment(value["alignment"]),
    actionsPadding: parsePadding(value["actions_padding"]),
    clipBehavior: parseClip(value["clip_behavior"]),
    barrierColor: parseColor(value["barrier_color"], materialStyleTheme(theme)),
    insetPadding: parsePadding(value["inset_padding"]),
  );
}

BottomSheetThemeData? parseBottomSheetTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [BottomSheetThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.bottomSheetTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    modalBackgroundColor:
        parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    showDragHandle: parseBool(value["show_drag_handle"]),
    clipBehavior: parseClip(value["clip_behavior"]),
    constraints: parseBoxConstraints(value["size_constraints"]),
    modalBarrierColor:
        parseColor(value["barrier_color"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    dragHandleColor:
        parseColor(value["drag_handle_color"], materialStyleTheme(theme)),
    modalElevation: parseDouble(value["elevation"]),
    // elevation: parseDouble(value["elevation"]),
  );
}

CardThemeData? parseCardTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [CardThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.cardTheme.copyWith(
      color: parseColor(value["color"], materialStyleTheme(theme)),
      shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
      elevation: parseDouble(value["elevation"]),
      shape: parseShape(value["shape"], materialStyleTheme(theme)),
      clipBehavior: parseClip(value["clip_behavior"]),
      margin: parseMargin(value["margin"]));
}

ChipThemeData? parseChipTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [ChipThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.chipTheme.copyWith(
    color: parseWidgetStateColor(value["color"], materialStyleTheme(theme)),
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    padding: parsePadding(value["padding"]),
    labelPadding: parsePadding(value["label_padding"]),
    labelStyle:
        parseTextStyle(value["label_text_style"], materialStyleTheme(theme)),
    disabledColor:
        parseColor(value["disabled_color"], materialStyleTheme(theme)),
    selectedColor:
        parseColor(value["selected_color"], materialStyleTheme(theme)),
    checkmarkColor: parseColor(value["check_color"], materialStyleTheme(theme)),
    deleteIconColor:
        parseColor(value["delete_icon_color"], materialStyleTheme(theme)),
    side: parseBorderSide(value["border_side"], materialStyleTheme(theme)),
    brightness: parseBrightness(value["brightness"]),
    selectedShadowColor:
        parseColor(value["selected_shadow_color"], materialStyleTheme(theme)),
    showCheckmark: parseBool(value["show_checkmark"]),
    pressElevation: parseDouble(value["elevation_on_click"]),
    avatarBoxConstraints:
        parseBoxConstraints(value["leading_size_constraints"]),
    deleteIconBoxConstraints:
        parseBoxConstraints(value["delete_icon_size_constraints"]),
    // below props are for [ChoiceChip], which is not supported yet
    // secondaryLabelStyle:
    //     parseTextStyle(value["secondary_label_text_style"], theme),
    // secondarySelectedColor:
    //     parseColor(value["secondary_selected_color"], theme),
  );
}

FloatingActionButtonThemeData? parseFloatingActionButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [FloatingActionButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.floatingActionButtonTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    hoverColor: parseColor(value["hover_color"], materialStyleTheme(theme)),
    focusColor: parseColor(value["focus_color"], materialStyleTheme(theme)),
    foregroundColor:
        parseColor(value["foreground_color"], materialStyleTheme(theme)),
    splashColor: parseColor(value["splash_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    focusElevation: parseDouble(value["focus_elevation"]),
    hoverElevation: parseDouble(value["hover_elevation"]),
    highlightElevation: parseDouble(value["highlight_elevation"]),
    disabledElevation: parseDouble(value["disabled_elevation"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    enableFeedback: parseBool(value["enable_feedback"]),
    extendedPadding: parsePadding(value["extended_padding"]),
    extendedTextStyle:
        parseTextStyle(value["text_style"], materialStyleTheme(theme)),
    extendedIconLabelSpacing: parseDouble(value["icon_label_spacing"]),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
    iconSize: parseDouble(value["icon_size"]),
    extendedSizeConstraints:
        parseBoxConstraints(value["extended_size_constraints"]),
    sizeConstraints: parseBoxConstraints(value["size_constraints"]),
    // smallSizeConstraints: parseBoxConstraints(value["small_size_constraints"]),
    // largeSizeConstraints: parseBoxConstraints(value["large_size_constraints"]),
  );
}

NavigationRailThemeData? parseNavigationRailTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [NavigationRailThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.navigationRailTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    indicatorColor:
        parseColor(value["indicator_color"], materialStyleTheme(theme)),
    unselectedLabelTextStyle: parseTextStyle(
        value["unselected_label_text_style"], materialStyleTheme(theme)),
    selectedLabelTextStyle: parseTextStyle(
        value["selected_label_text_style"], materialStyleTheme(theme)),
    minWidth: parseDouble(value["min_width"]),
    labelType: parseNavigationRailLabelType(value["label_type"]),
    groupAlignment: parseDouble(value["group_alignment"]),
    indicatorShape:
        parseShape(value["indicator_shape"], materialStyleTheme(theme)),
    minExtendedWidth: parseDouble(value["min_extended_width"]),
    useIndicator: parseBool(value["use_indicator"]),
  );
}

AppBarThemeData? parseAppBarTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [AppBarThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.appBarTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    foregroundColor: parseColor(value["color"], materialStyleTheme(theme)),
    titleTextStyle:
        parseTextStyle(value["title_text_style"], materialStyleTheme(theme)),
    toolbarTextStyle:
        parseTextStyle(value["toolbar_text_style"], materialStyleTheme(theme)),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    centerTitle: parseBool(value["center_title"]),
    titleSpacing: parseDouble(value["title_spacing"]),
    scrolledUnderElevation: parseDouble(value["elevation_on_scroll"]),
    toolbarHeight: parseDouble(value["toolbar_height"]),
    actionsPadding: parsePadding(value["actions_padding"]),
  );
}

BottomAppBarThemeData? parseBottomAppBarTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [BottomAppBarThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.bottomAppBarTheme.copyWith(
    color: parseColor(value["color"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    height: parseDouble(value["height"]),
    padding: parsePadding(value["padding"]),
    shape: parseNotchedShape(value["shape"], materialStyleTheme(theme)),
  );
}

RadioThemeData? parseRadioTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [RadioThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.radioTheme.copyWith(
    fillColor:
        parseWidgetStateColor(value["fill_color"], materialStyleTheme(theme)),
    splashRadius: parseDouble(value["splash_radius"]),
    overlayColor: parseWidgetStateColor(
        value["overlay_color"], materialStyleTheme(theme)),
    visualDensity: parseVisualDensity(value["visual_density"]),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
  );
}

CheckboxThemeData? parseCheckboxTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [CheckboxThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.checkboxTheme.copyWith(
    fillColor:
        parseWidgetStateColor(value["fill_color"], materialStyleTheme(theme)),
    splashRadius: parseDouble(value["splash_radius"]),
    overlayColor: parseWidgetStateColor(
        value["overlay_color"], materialStyleTheme(theme)),
    visualDensity: parseVisualDensity(value["visual_density"]),
    checkColor:
        parseWidgetStateColor(value["check_color"], materialStyleTheme(theme)),
    side: parseBorderSide(value["border_side"], materialStyleTheme(theme)),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
  );
}

BadgeThemeData? parseBadgeTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [BadgeThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.badgeTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    textStyle: parseTextStyle(value["text_style"], materialStyleTheme(theme)),
    padding: parsePadding(value["padding"]),
    alignment: parseAlignment(value["alignment"]),
    textColor: parseColor(value["text_color"], materialStyleTheme(theme)),
    offset: parseOffset(value["offset"]),
    smallSize: parseDouble(value["small_size"]),
    largeSize: parseDouble(value["large_size"]),
  );
}

SwitchThemeData? parseSwitchTheme(
    Map<dynamic, dynamic>? value, BuildContext context,
    [SwitchThemeData? defaultValue]) {
  if (value == null) return defaultValue;
  var theme = Theme.of(context);
  return theme.switchTheme.copyWith(
    thumbColor:
        parseWidgetStateColor(value["thumb_color"], materialStyleTheme(theme)),
    trackColor:
        parseWidgetStateColor(value["track_color"], materialStyleTheme(theme)),
    overlayColor: parseWidgetStateColor(
        value["overlay_color"], materialStyleTheme(theme)),
    splashRadius: parseDouble(value["splash_radius"]),
    thumbIcon: parseWidgetStateIcon(value["thumb_icon"],
        RufletBackend.of(context), materialStyleTheme(theme)),
    trackOutlineColor: parseWidgetStateColor(
        value["track_outline_color"], materialStyleTheme(theme)),
    trackOutlineWidth: parseWidgetStateDouble(value["track_outline_width"]),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
    padding: parsePadding(value["padding"]),
  );
}

DividerThemeData? parseDividerTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [DividerThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.dividerTheme.copyWith(
    color: parseColor(value["color"], materialStyleTheme(theme)),
    space: parseDouble(value["space"]),
    thickness: parseDouble(value["thickness"]),
    indent: parseDouble(value["leading_indent"]),
    endIndent: parseDouble(value["trailing_indent"]),
  );
}

SnackBarThemeData? parseSnackBarTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [SnackBarThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.snackBarTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    actionTextColor:
        parseColor(value["action_text_color"], materialStyleTheme(theme)),
    actionBackgroundColor:
        parseColor(value["action_bgcolor"], materialStyleTheme(theme)),
    closeIconColor:
        parseColor(value["close_icon_color"], materialStyleTheme(theme)),
    disabledActionTextColor: parseColor(
        value["disabled_action_text_color"], materialStyleTheme(theme)),
    disabledActionBackgroundColor:
        parseColor(value["disabled_action_bgcolor"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    behavior: parseSnackBarBehavior(value["behavior"]),
    contentTextStyle:
        parseTextStyle(value["content_text_style"], materialStyleTheme(theme)),
    width: parseDouble(value["width"]),
    insetPadding: parsePadding(value["inset_padding"]),
    dismissDirection: parseDismissDirection(value["dismiss_direction"]),
    showCloseIcon: parseBool(value["show_close_icon"]),
    actionOverflowThreshold: parseDouble(value["action_overflow_threshold"]),
  );
}

MaterialBannerThemeData? parseBannerTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [MaterialBannerThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.bannerTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    dividerColor: parseColor(value["divider_color"], materialStyleTheme(theme)),
    padding: parsePadding(value["padding"]),
    leadingPadding: parsePadding(value["leading_padding"]),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    contentTextStyle:
        parseTextStyle(value["content_text_style"], materialStyleTheme(theme)),
  );
}

DatePickerThemeData? parseDatePickerTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [DatePickerThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.datePickerTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    dividerColor: parseColor(value["divider_color"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    cancelButtonStyle: parseButtonStyle(value["cancel_button_style"], theme),
    confirmButtonStyle: parseButtonStyle(value["confirm_button_style"], theme),
    dayBackgroundColor:
        parseWidgetStateColor(value["day_bgcolor"], materialStyleTheme(theme)),
    yearStyle:
        parseTextStyle(value["year_text_style"], materialStyleTheme(theme)),
    dayStyle:
        parseTextStyle(value["day_text_style"], materialStyleTheme(theme)),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    dayOverlayColor: parseWidgetStateColor(
        value["day_overlay_color"], materialStyleTheme(theme)),
    headerBackgroundColor:
        parseColor(value["header_bgcolor"], materialStyleTheme(theme)),
    dayForegroundColor: parseWidgetStateColor(
        value["day_foreground_color"], materialStyleTheme(theme)),
    rangePickerElevation: parseDouble(value["range_picker_elevation"]),
    todayBackgroundColor: parseWidgetStateColor(
        value["today_bgcolor"], materialStyleTheme(theme)),
    headerForegroundColor:
        parseColor(value["header_foreground_color"], materialStyleTheme(theme)),
    headerHeadlineStyle: parseTextStyle(
        value["header_headline_text_style"], materialStyleTheme(theme)),
    headerHelpStyle: parseTextStyle(
        value["header_help_text_style"], materialStyleTheme(theme)),
    rangePickerBackgroundColor:
        parseColor(value["range_picker_bgcolor"], materialStyleTheme(theme)),
    rangePickerHeaderBackgroundColor: parseColor(
        value["range_picker_header_bgcolor"], materialStyleTheme(theme)),
    rangePickerHeaderForegroundColor: parseColor(
        value["range_picker_header_foreground_color"],
        materialStyleTheme(theme)),
    rangePickerShadowColor: parseColor(
        value["range_picker_shadow_color"], materialStyleTheme(theme)),
    todayForegroundColor: parseWidgetStateColor(
        value["today_foreground_color"], materialStyleTheme(theme)),
    rangePickerShape:
        parseShape(value["range_picker_shape"], materialStyleTheme(theme)),
    rangePickerHeaderHelpStyle: parseTextStyle(
        value["range_picker_header_help_text_style"],
        materialStyleTheme(theme)),
    rangePickerHeaderHeadlineStyle: parseTextStyle(
        value["range_picker_header_headline_text_style"],
        materialStyleTheme(theme)),
    rangeSelectionBackgroundColor:
        parseColor(value["range_selection_bgcolor"], materialStyleTheme(theme)),
    rangeSelectionOverlayColor: parseWidgetStateColor(
        value["range_selection_overlay_color"], materialStyleTheme(theme)),
    todayBorder:
        parseBorderSide(value["today_border_side"], materialStyleTheme(theme)),
    yearBackgroundColor:
        parseWidgetStateColor(value["year_bgcolor"], materialStyleTheme(theme)),
    yearForegroundColor: parseWidgetStateColor(
        value["year_foreground_color"], materialStyleTheme(theme)),
    yearOverlayColor: parseWidgetStateColor(
        value["year_overlay_color"], materialStyleTheme(theme)),
    weekdayStyle:
        parseTextStyle(value["weekday_text_style"], materialStyleTheme(theme)),
    dayShape: parseWidgetStateOutlinedBorder(
        value["day_shape"], materialStyleTheme(theme)),
    //locale: parseLocale(value["locale"]),
  );
}

TimePickerThemeData? parseTimePickerTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [TimePickerThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.timePickerTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    padding: parsePadding(value["padding"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    dayPeriodBorderSide: parseBorderSide(
        value["day_period_border_side"], materialStyleTheme(theme)),
    dayPeriodButtonStyle:
        parseButtonStyle(value["day_period_button_style"], theme),
    dayPeriodColor:
        parseColor(value["day_period_color"], materialStyleTheme(theme)),
    dayPeriodShape:
        parseShape(value["day_period_shape"], materialStyleTheme(theme)),
    dayPeriodTextColor:
        parseColor(value["day_period_text_color"], materialStyleTheme(theme)),
    dayPeriodTextStyle: parseTextStyle(
        value["day_period_text_style"], materialStyleTheme(theme)),
    dialBackgroundColor:
        parseColor(value["dial_bgcolor"], materialStyleTheme(theme)),
    dialHandColor:
        parseColor(value["dial_hand_color"], materialStyleTheme(theme)),
    dialTextColor:
        parseColor(value["dial_text_color"], materialStyleTheme(theme)),
    dialTextStyle:
        parseTextStyle(value["dial_text_style"], materialStyleTheme(theme)),
    entryModeIconColor:
        parseColor(value["entry_mode_icon_color"], materialStyleTheme(theme)),
    helpTextStyle:
        parseTextStyle(value["help_text_style"], materialStyleTheme(theme)),
    hourMinuteColor:
        parseColor(value["hour_minute_color"], materialStyleTheme(theme)),
    hourMinuteTextColor:
        parseColor(value["hour_minute_text_color"], materialStyleTheme(theme)),
    hourMinuteTextStyle: parseTextStyle(
        value["hour_minute_text_style"], materialStyleTheme(theme)),
    hourMinuteShape:
        parseShape(value["hour_minute_shape"], materialStyleTheme(theme)),
    cancelButtonStyle: parseButtonStyle(value["cancel_button_style"], theme),
    confirmButtonStyle: parseButtonStyle(value["confirm_button_style"], theme),
    timeSelectorSeparatorColor: parseWidgetStateColor(
        value["time_selector_separator_color"], materialStyleTheme(theme)),
    timeSelectorSeparatorTextStyle: parseWidgetStateTextStyle(
        value["time_selector_separator_text_style"], materialStyleTheme(theme)),
  );
}

DropdownMenuThemeData? parseDropdownMenuTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [DropdownMenuThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.dropdownMenuTheme.copyWith(
    menuStyle: parseMenuStyle(value["menu_style"], theme),
    textStyle: parseTextStyle(value["text_style"], materialStyleTheme(theme)),
  );
}

ListTileThemeData? parseListTileTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [ListTileThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.listTileTheme.copyWith(
    iconColor: parseColor(value["icon_color"], materialStyleTheme(theme)),
    textColor: parseColor(value["text_color"], materialStyleTheme(theme)),
    tileColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    contentPadding: parsePadding(value["content_padding"]),
    selectedColor:
        parseColor(value["selected_color"], materialStyleTheme(theme)),
    selectedTileColor:
        parseColor(value["selected_tile_color"], materialStyleTheme(theme)),
    isThreeLine: parseBool(value["is_three_line"]),
    visualDensity: parseVisualDensity(value["visual_density"]),
    titleTextStyle:
        parseTextStyle(value["title_text_style"], materialStyleTheme(theme)),
    subtitleTextStyle:
        parseTextStyle(value["subtitle_text_style"], materialStyleTheme(theme)),
    minVerticalPadding: parseDouble(value["min_vertical_padding"]),
    enableFeedback: parseBool(value["enable_feedback"]),
    dense: parseBool(value["dense"]),
    horizontalTitleGap: parseDouble(value["horizontal_spacing"]),
    minLeadingWidth: parseDouble(value["min_leading_width"]),
    leadingAndTrailingTextStyle: parseTextStyle(
        value["leading_and_trailing_text_style"], materialStyleTheme(theme)),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
    minTileHeight: parseDouble(value["min_height"]),
    controlAffinity: parseListTileControlAffinity(value["affinity"]),
    style: parseListTileStyle(value["style"]),
    titleAlignment: parseListTileTitleAlignment(value["title_alignment"]),
  );
}

TooltipThemeData? parseTooltipTheme(
    Map<dynamic, dynamic>? value, BuildContext context,
    [TooltipThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  var theme = Theme.of(context);

  return theme.tooltipTheme.copyWith(
    enableFeedback: parseBool(value["enable_feedback"]),
    constraints: parseBoxConstraints(value["size_constraints"]),
    excludeFromSemantics: parseBool(value["exclude_from_semantics"]),
    textStyle: parseTextStyle(value["text_style"], materialStyleTheme(theme)),
    preferBelow: parseBool(value["prefer_below"]),
    verticalOffset: parseDouble(value["vertical_offset"]),
    padding: parsePadding(value["padding"]),
    waitDuration: parseDuration(value["wait_duration"]),
    exitDuration: parseDuration(value["exit_duration"]),
    showDuration: parseDuration(value["show_duration"]),
    margin: parseMargin(value["margin"]),
    textAlign: parseTextAlign(value["text_align"]),
    triggerMode: parseTooltipTriggerMode(value["trigger_mode"]),
    decoration: parseBoxDecoration(value["decoration"], context),
  );
}

ExpansionTileThemeData? parseExpansionTileTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [ExpansionTileThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.expansionTileTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    iconColor: parseColor(value["icon_color"], materialStyleTheme(theme)),
    textColor: parseColor(value["text_color"], materialStyleTheme(theme)),
    collapsedBackgroundColor:
        parseColor(value["collapsed_bgcolor"], materialStyleTheme(theme)),
    collapsedIconColor:
        parseColor(value["collapsed_icon_color"], materialStyleTheme(theme)),
    clipBehavior: parseClip(value["clip_behavior"]),
    collapsedTextColor:
        parseColor(value["collapsed_text_color"], materialStyleTheme(theme)),
    tilePadding: parsePadding(value["tile_padding"]),
    expandedAlignment: parseAlignment(value["expanded_alignment"]),
    childrenPadding: parsePadding(value["controls_padding"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    collapsedShape:
        parseShape(value["collapsed_shape"], materialStyleTheme(theme)),
    expansionAnimationStyle:
        parseAnimationStyle(value["expansion_animation_style"]),
  );
}

SliderThemeData? parseSliderTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [SliderThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.sliderTheme.copyWith(
    activeTrackColor:
        parseColor(value["active_track_color"], materialStyleTheme(theme)),
    inactiveTrackColor:
        parseColor(value["inactive_track_color"], materialStyleTheme(theme)),
    thumbColor: parseColor(value["thumb_color"], materialStyleTheme(theme)),
    overlayColor: parseColor(value["overlay_color"], materialStyleTheme(theme)),
    valueIndicatorColor:
        parseColor(value["value_indicator_color"], materialStyleTheme(theme)),
    disabledThumbColor:
        parseColor(value["disabled_thumb_color"], materialStyleTheme(theme)),
    valueIndicatorTextStyle: parseTextStyle(
        value["value_indicator_text_style"], materialStyleTheme(theme)),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
    activeTickMarkColor:
        parseColor(value["active_tick_mark_color"], materialStyleTheme(theme)),
    disabledActiveTickMarkColor: parseColor(
        value["disabled_active_tick_mark_color"], materialStyleTheme(theme)),
    disabledActiveTrackColor: parseColor(
        value["disabled_active_track_color"], materialStyleTheme(theme)),
    disabledInactiveTickMarkColor: parseColor(
        value["disabled_inactive_tick_mark_color"], materialStyleTheme(theme)),
    disabledInactiveTrackColor: parseColor(
        value["disabled_inactive_track_color"], materialStyleTheme(theme)),
    disabledSecondaryActiveTrackColor: parseColor(
        value["disabled_secondary_active_track_color"],
        materialStyleTheme(theme)),
    inactiveTickMarkColor: parseColor(
        value["inactive_tick_mark_color"], materialStyleTheme(theme)),
    overlappingShapeStrokeColor: parseColor(
        value["overlapping_shape_stroke_color"], materialStyleTheme(theme)),
    minThumbSeparation: parseDouble(value["min_thumb_separation"]),
    secondaryActiveTrackColor: parseColor(
        value["secondary_active_track_color"], materialStyleTheme(theme)),
    trackHeight: parseDouble(value["track_height"]),
    valueIndicatorStrokeColor: parseColor(
        value["value_indicator_stroke_color"], materialStyleTheme(theme)),
    allowedInteraction: parseSliderInteraction(value["interaction"]),
    padding: parsePadding(value["padding"]),
    trackGap: parseDouble(value["track_gap"]),
    thumbSize: getWidgetStateProperty<Size?>(
        value["thumb_size"], (jv) => parseSize(jv)),
    // TODO: deprecated in v0.27.0, to be removed in future versions
    year2023: parseBool(value["year_2023"]),
  );
}

ProgressIndicatorThemeData? parseProgressIndicatorTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [ProgressIndicatorThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.progressIndicatorTheme.copyWith(
    color: parseColor(value["color"], materialStyleTheme(theme)),
    circularTrackColor:
        parseColor(value["circular_track_color"], materialStyleTheme(theme)),
    linearTrackColor:
        parseColor(value["linear_track_color"], materialStyleTheme(theme)),
    refreshBackgroundColor:
        parseColor(value["refresh_bgcolor"], materialStyleTheme(theme)),
    linearMinHeight: parseDouble(value["linear_min_height"]),
    borderRadius: parseBorderRadius(value["border_radius"]),
    trackGap: parseDouble(value["track_gap"]),
    circularTrackPadding: parsePadding(value["circular_track_padding"]),
    constraints: parseBoxConstraints(value["size_constraints"]),
    stopIndicatorColor:
        parseColor(value["stop_indicator_color"], materialStyleTheme(theme)),
    stopIndicatorRadius: parseDouble(value["stop_indicator_radius"]),
    strokeAlign: parseDouble(value["stroke_align"]),
    strokeCap: parseStrokeCap(value["stroke_cap"]),
    strokeWidth: parseDouble(value["stroke_width"]),
    year2023: parseBool(value["year_2023"], false),
  );
}

PopupMenuThemeData? parsePopupMenuTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [PopupMenuThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.popupMenuTheme.copyWith(
    color: parseColor(value["color"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    iconColor: parseColor(value["icon_color"], materialStyleTheme(theme)),
    labelTextStyle: parseWidgetStateTextStyle(
        value["label_text_style"], materialStyleTheme(theme)),
    enableFeedback: parseBool(value["enable_feedback"]),
    elevation: parseDouble(value["elevation"]),
    iconSize: parseDouble(value["icon_size"]),
    position: parsePopupMenuPosition(value["menu_position"]),
    mouseCursor: parseWidgetStateMouseCursor(value["mouse_cursor"]),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    menuPadding: parsePadding(value["menu_padding"]),
  );
}

SearchBarThemeData? parseSearchBarTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [SearchBarThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.searchBarTheme.copyWith(
    shadowColor:
        parseWidgetStateColor(value["shadow_color"], materialStyleTheme(theme)),
    elevation: parseWidgetStateDouble(value["elevation"]),
    backgroundColor:
        parseWidgetStateColor(value["bgcolor"], materialStyleTheme(theme)),
    overlayColor: parseWidgetStateColor(
        value["overlay_color"], materialStyleTheme(theme)),
    textStyle: parseWidgetStateTextStyle(
        value["text_style"], materialStyleTheme(theme)),
    hintStyle: parseWidgetStateTextStyle(
        value["hint_style"], materialStyleTheme(theme)),
    shape: parseWidgetStateOutlinedBorder(
        value["shape"], materialStyleTheme(theme)),
    textCapitalization: parseTextCapitalization(value["text_capitalization"]),
    padding: parseWidgetStatePadding(value["padding"]),
    constraints: parseBoxConstraints(value["size_constraints"]),
    side: parseWidgetStateBorderSide(
        value["border_side"], materialStyleTheme(theme)),
  );
}

SearchViewThemeData? parseSearchViewTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [SearchViewThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.searchViewTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    dividerColor: parseColor(value["divider_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    headerHintStyle: parseTextStyle(
        value["header_hint_text_style"], materialStyleTheme(theme)),
    headerTextStyle:
        parseTextStyle(value["header_text_style"], materialStyleTheme(theme)),
    shape: parseShape(value["shape"], materialStyleTheme(theme)),
    side: parseBorderSide(value["border_side"], materialStyleTheme(theme)),
    constraints: parseBoxConstraints(value["size_constraints"]),
    headerHeight: parseDouble(value["header_height"]),
    padding: parsePadding(value["padding"]),
    barPadding: parsePadding(value["bar_padding"]),
    shrinkWrap: parseBool(value["shrink_wrap"]),
  );
}

NavigationDrawerThemeData? parseNavigationDrawerTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [NavigationDrawerThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.navigationDrawerTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    indicatorColor:
        parseColor(value["indicator_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    indicatorSize: parseSize(value["indicator_size"]),
    tileHeight: parseDouble(value["tile_height"]),
    labelTextStyle: parseWidgetStateTextStyle(
        value["label_text_style"], materialStyleTheme(theme)),
    indicatorShape:
        parseShape(value["indicator_shape"], materialStyleTheme(theme)),
  );
}

NavigationBarThemeData? parseNavigationBarTheme(
    Map<dynamic, dynamic>? value, ThemeData theme,
    [NavigationBarThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.navigationBarTheme.copyWith(
    backgroundColor: parseColor(value["bgcolor"], materialStyleTheme(theme)),
    shadowColor: parseColor(value["shadow_color"], materialStyleTheme(theme)),
    indicatorColor:
        parseColor(value["indicator_color"], materialStyleTheme(theme)),
    overlayColor: parseWidgetStateColor(
        value["overlay_color"], materialStyleTheme(theme)),
    elevation: parseDouble(value["elevation"]),
    height: parseDouble(value["height"]),
    labelTextStyle: parseWidgetStateTextStyle(
        value["label_text_style"], materialStyleTheme(theme)),
    indicatorShape:
        parseShape(value["indicator_shape"], materialStyleTheme(theme)),
    labelBehavior:
        parseNavigationDestinationLabelBehavior(value["label_behavior"]),
    labelPadding: parsePadding(value["label_padding"]),
  );
}

SegmentedButtonThemeData? parseSegmentedButtonTheme(
    Map<dynamic, dynamic>? value, ThemeData theme, BuildContext context,
    [SegmentedButtonThemeData? defaultValue]) {
  if (value == null) return defaultValue;
  var selectedIcon =
      parseIconData(value["selected_icon"], RufletBackend.of(context));

  return theme.segmentedButtonTheme.copyWith(
    selectedIcon: selectedIcon != null ? Icon(selectedIcon) : null,
    style: parseButtonStyle(value["style"], theme),
  );
}

IconThemeData? parseIconTheme(Map<dynamic, dynamic>? value, ThemeData theme,
    [IconThemeData? defaultValue]) {
  if (value == null) return defaultValue;

  return theme.iconTheme.copyWith(
    color: parseColor(value["color"], materialStyleTheme(theme)),
    applyTextScaling: parseBool(value["apply_text_scaling"]),
    fill: parseDouble(value["fill"]),
    opacity: parseDouble(value["opacity"]),
    size: parseDouble(value["size"]),
    opticalSize: parseDouble(value["optical_size"]),
    grade: parseDouble(value["grade"]),
    weight: parseDouble(value["weight"]),
    shadows: parseBoxShadows(value["shadows"], materialStyleTheme(theme)),
  );
}

PageTransitionsBuilder? parseTransitionsBuilder(String? value,
    [PageTransitionsBuilder? defaultValue]) {
  var buildersMap = {
    "fadeupwards": const FadeUpwardsPageTransitionsBuilder(),
    "openupwards": const OpenUpwardsPageTransitionsBuilder(),
    "cupertino": const CupertinoPageTransitionsBuilder(),
    "zoom": const ZoomPageTransitionsBuilder(),
    "none": const NoPageTransitionsBuilder(),
    "predictive": const PredictiveBackPageTransitionsBuilder(),
    "fadeforwards": const FadeForwardsPageTransitionsBuilder(),
  };
  return buildersMap[value?.toLowerCase()] ?? defaultValue;
}

class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T>? route,
      BuildContext? context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget? child) {
    // only return the child without warping it with animations
    return child!;
  }
}

extension ThemeParsers on Control {
  ThemeData getTheme(
      String propertyName, BuildContext context, Brightness? brightness,
      {ThemeData? parentTheme}) {
    return parseTheme(get(propertyName), context, brightness,
        parentTheme: parentTheme);
  }

  ThemeMode? getThemeMode(String propertyName, [ThemeMode? defaultValue]) {
    return parseThemeMode(get(propertyName), defaultValue);
  }

  ColorScheme? getColorScheme(String propertyName, ThemeData theme,
      [ColorScheme? defaultValue]) {
    return parseColorScheme(get(propertyName), theme, defaultValue);
  }

  TextTheme? getTextTheme(
      String propertyName, ThemeData theme, TextTheme textTheme,
      [TextTheme? defaultValue]) {
    return parseTextTheme(get(propertyName), theme, textTheme, defaultValue);
  }

  VisualDensity? getVisualDensity(String propertyName,
      [VisualDensity? defaultValue]) {
    return parseVisualDensity(get(propertyName), defaultValue);
  }

  PageTransitionsTheme? getPageTransitionsTheme(String propertyName,
      [PageTransitionsTheme? defaultValue]) {
    return parsePageTransitions(get(propertyName), defaultValue);
  }

  SystemUiOverlayStyleTheme getSystemUiOverlayStyleTheme(
      String propertyName, ThemeData theme, Brightness? brightness) {
    return SystemUiOverlayStyleTheme(
      get(propertyName) != null
          ? parseSystemUiOverlayStyle(
              get(propertyName), materialStyleTheme(theme), brightness)
          : null,
    );
  }

  ElevatedButtonThemeData? getButtonTheme(String propertyName, ThemeData theme,
      [ElevatedButtonThemeData? defaultValue]) {
    return parseButtonTheme(get(propertyName), theme, defaultValue);
  }

  OutlinedButtonThemeData? getOutlinedButtonTheme(
      String propertyName, ThemeData theme,
      [OutlinedButtonThemeData? defaultValue]) {
    return parseOutlinedButtonTheme(get(propertyName), theme, defaultValue);
  }

  TextButtonThemeData? getTextButtonTheme(String propertyName, ThemeData theme,
      [TextButtonThemeData? defaultValue]) {
    return parseTextButtonTheme(get(propertyName), theme, defaultValue);
  }

  FilledButtonThemeData? getFilledButtonTheme(
      String propertyName, ThemeData theme,
      [FilledButtonThemeData? defaultValue]) {
    return parseFilledButtonTheme(get(propertyName), theme, defaultValue);
  }

  IconButtonThemeData? getIconButtonTheme(String propertyName, ThemeData theme,
      [IconButtonThemeData? defaultValue]) {
    return parseIconButtonTheme(get(propertyName), theme, defaultValue);
  }

  DataTableThemeData? getDataTableTheme(
      String propertyName, BuildContext context,
      [DataTableThemeData? defaultValue]) {
    return parseDataTableTheme(get(propertyName), context, defaultValue);
  }

  ScrollbarThemeData? getScrollbarTheme(String propertyName, ThemeData theme,
      [ScrollbarThemeData? defaultValue]) {
    return parseScrollBarTheme(get(propertyName), theme, defaultValue);
  }

  TabBarThemeData? getTabBarTheme(String propertyName, ThemeData theme,
      [TabBarThemeData? defaultValue]) {
    return parseTabBarTheme(get(propertyName), theme, defaultValue);
  }

  DialogThemeData? getDialogTheme(String propertyName, ThemeData theme,
      [DialogThemeData? defaultValue]) {
    return parseDialogTheme(get(propertyName), theme, defaultValue);
  }

  BottomSheetThemeData? getBottomSheetTheme(
      String propertyName, ThemeData theme,
      [BottomSheetThemeData? defaultValue]) {
    return parseBottomSheetTheme(get(propertyName), theme, defaultValue);
  }

  CardThemeData? getCardTheme(String propertyName, ThemeData theme,
      [CardThemeData? defaultValue]) {
    return parseCardTheme(get(propertyName), theme, defaultValue);
  }

  ChipThemeData? getChipTheme(String propertyName, ThemeData theme,
      [ChipThemeData? defaultValue]) {
    return parseChipTheme(get(propertyName), theme, defaultValue);
  }

  FloatingActionButtonThemeData? getFloatingActionButtonTheme(
      String propertyName, ThemeData theme,
      [FloatingActionButtonThemeData? defaultValue]) {
    return parseFloatingActionButtonTheme(
        get(propertyName), theme, defaultValue);
  }

  NavigationRailThemeData? getNavigationRailTheme(
      String propertyName, ThemeData theme,
      [NavigationRailThemeData? defaultValue]) {
    return parseNavigationRailTheme(get(propertyName), theme, defaultValue);
  }

  AppBarThemeData? getAppBarTheme(String propertyName, ThemeData theme,
      [AppBarThemeData? defaultValue]) {
    return parseAppBarTheme(get(propertyName), theme, defaultValue);
  }

  BottomAppBarThemeData? getBottomAppBarTheme(
      String propertyName, ThemeData theme,
      [BottomAppBarThemeData? defaultValue]) {
    return parseBottomAppBarTheme(get(propertyName), theme, defaultValue);
  }

  RadioThemeData? getRadioTheme(String propertyName, ThemeData theme,
      [RadioThemeData? defaultValue]) {
    return parseRadioTheme(get(propertyName), theme, defaultValue);
  }

  CheckboxThemeData? getCheckboxTheme(String propertyName, ThemeData theme,
      [CheckboxThemeData? defaultValue]) {
    return parseCheckboxTheme(get(propertyName), theme, defaultValue);
  }

  BadgeThemeData? getBadgeTheme(String propertyName, ThemeData theme,
      [BadgeThemeData? defaultValue]) {
    return parseBadgeTheme(get(propertyName), theme, defaultValue);
  }

  SwitchThemeData? getSwitchTheme(String propertyName, BuildContext context,
      [SwitchThemeData? defaultValue]) {
    return parseSwitchTheme(get(propertyName), context, defaultValue);
  }

  DividerThemeData? getDividerTheme(String propertyName, ThemeData theme,
      [DividerThemeData? defaultValue]) {
    return parseDividerTheme(get(propertyName), theme, defaultValue);
  }

  SnackBarThemeData? getSnackBarTheme(String propertyName, ThemeData theme,
      [SnackBarThemeData? defaultValue]) {
    return parseSnackBarTheme(get(propertyName), theme, defaultValue);
  }

  MaterialBannerThemeData? getBannerTheme(String propertyName, ThemeData theme,
      [MaterialBannerThemeData? defaultValue]) {
    return parseBannerTheme(get(propertyName), theme, defaultValue);
  }

  DatePickerThemeData? getDatePickerTheme(String propertyName, ThemeData theme,
      [DatePickerThemeData? defaultValue]) {
    return parseDatePickerTheme(get(propertyName), theme, defaultValue);
  }

  TimePickerThemeData? getTimePickerTheme(String propertyName, ThemeData theme,
      [TimePickerThemeData? defaultValue]) {
    return parseTimePickerTheme(get(propertyName), theme, defaultValue);
  }

  DropdownMenuThemeData? getDropdownMenuTheme(
      String propertyName, ThemeData theme,
      [DropdownMenuThemeData? defaultValue]) {
    return parseDropdownMenuTheme(get(propertyName), theme, defaultValue);
  }

  ListTileThemeData? getListTileTheme(String propertyName, ThemeData theme,
      [ListTileThemeData? defaultValue]) {
    return parseListTileTheme(get(propertyName), theme, defaultValue);
  }

  TooltipThemeData? getTooltipTheme(String propertyName, BuildContext context,
      [TooltipThemeData? defaultValue]) {
    return parseTooltipTheme(get(propertyName), context, defaultValue);
  }

  ExpansionTileThemeData? getExpansionTileTheme(
      String propertyName, ThemeData theme,
      [ExpansionTileThemeData? defaultValue]) {
    return parseExpansionTileTheme(get(propertyName), theme, defaultValue);
  }

  SliderThemeData? getSliderTheme(String propertyName, ThemeData theme,
      [SliderThemeData? defaultValue]) {
    return parseSliderTheme(get(propertyName), theme, defaultValue);
  }

  ProgressIndicatorThemeData? getProgressIndicatorTheme(
      String propertyName, ThemeData theme,
      [ProgressIndicatorThemeData? defaultValue]) {
    return parseProgressIndicatorTheme(get(propertyName), theme, defaultValue);
  }

  PopupMenuThemeData? getPopupMenuTheme(String propertyName, ThemeData theme,
      [PopupMenuThemeData? defaultValue]) {
    return parsePopupMenuTheme(get(propertyName), theme, defaultValue);
  }

  SearchBarThemeData? getSearchBarTheme(String propertyName, ThemeData theme,
      [SearchBarThemeData? defaultValue]) {
    return parseSearchBarTheme(get(propertyName), theme, defaultValue);
  }

  SearchViewThemeData? getSearchViewTheme(String propertyName, ThemeData theme,
      [SearchViewThemeData? defaultValue]) {
    return parseSearchViewTheme(get(propertyName), theme, defaultValue);
  }

  NavigationDrawerThemeData? getNavigationDrawerTheme(
      String propertyName, ThemeData theme,
      [NavigationDrawerThemeData? defaultValue]) {
    return parseNavigationDrawerTheme(get(propertyName), theme, defaultValue);
  }

  NavigationBarThemeData? getNavigationBarTheme(
      String propertyName, ThemeData theme,
      [NavigationBarThemeData? defaultValue]) {
    return parseNavigationBarTheme(get(propertyName), theme, defaultValue);
  }

  SegmentedButtonThemeData? getSegmentedButtonTheme(
      String propertyName, ThemeData theme, BuildContext context,
      [SegmentedButtonThemeData? defaultValue]) {
    return parseSegmentedButtonTheme(
        get(propertyName), theme, context, defaultValue);
  }

  IconThemeData? getIconTheme(String propertyName, ThemeData theme,
      [IconThemeData? defaultValue]) {
    return parseIconTheme(get(propertyName), theme, defaultValue);
  }
}
