import 'package:flutter/material.dart';
import '../models/control.dart';
import 'enums.dart';

SliderInteraction? parseSliderInteraction(String? value,
    [SliderInteraction? defaultValue]) {
  return parseEnum(SliderInteraction.values, value, defaultValue);
}

SnackBarBehavior? parseSnackBarBehavior(String? value,
    [SnackBarBehavior? defaultValue]) {
  return parseEnum(SnackBarBehavior.values, value, defaultValue);
}

ListTileControlAffinity? parseListTileControlAffinity(String? value,
    [ListTileControlAffinity? defaultValue]) {
  return parseEnum(ListTileControlAffinity.values, value, defaultValue);
}

ListTileStyle? parseListTileStyle(String? value,
    [ListTileStyle? defaultValue]) {
  return parseEnum(ListTileStyle.values, value, defaultValue);
}

NavigationDestinationLabelBehavior? parseNavigationDestinationLabelBehavior(
    String? value,
    [NavigationDestinationLabelBehavior? defaultValue]) {
  return parseEnum(
      NavigationDestinationLabelBehavior.values, value, defaultValue);
}

PopupMenuPosition? parsePopupMenuPosition(String? value,
    [PopupMenuPosition? defaultValue]) {
  return parseEnum(PopupMenuPosition.values, value, defaultValue);
}

ListTileTitleAlignment? parseListTileTitleAlignment(String? value,
    [ListTileTitleAlignment? defaultValue]) {
  return parseEnum(ListTileTitleAlignment.values, value, defaultValue);
}

NavigationRailLabelType? parseNavigationRailLabelType(String? value,
    [NavigationRailLabelType? defaultValue]) {
  return parseEnum(NavigationRailLabelType.values, value, defaultValue);
}

FloatingLabelBehavior? parseFloatingLabelBehavior(String? value,
    [FloatingLabelBehavior? defaultValue]) {
  return parseEnum(FloatingLabelBehavior.values, value, defaultValue);
}

TabAlignment? parseTabAlignment(String? value, [TabAlignment? defaultValue]) {
  return parseEnum(TabAlignment.values, value, defaultValue);
}

extension MaterialEnumParsers on Control {
  SliderInteraction? getSliderInteraction(String propertyName,
      [SliderInteraction? defaultValue]) {
    return parseSliderInteraction(get(propertyName), defaultValue);
  }

  SnackBarBehavior? getSnackBarBehavior(String propertyName,
      [SnackBarBehavior? defaultValue]) {
    return parseSnackBarBehavior(get(propertyName), defaultValue);
  }

  ListTileControlAffinity? getListTileControlAffinity(String propertyName,
      [ListTileControlAffinity? defaultValue]) {
    return parseListTileControlAffinity(get(propertyName), defaultValue);
  }

  ListTileStyle? getListTileStyle(String propertyName,
      [ListTileStyle? defaultValue]) {
    return parseListTileStyle(get(propertyName), defaultValue);
  }

  NavigationDestinationLabelBehavior? getNavigationDestinationLabelBehavior(
      String propertyName,
      [NavigationDestinationLabelBehavior? defaultValue]) {
    return parseNavigationDestinationLabelBehavior(
        get(propertyName), defaultValue);
  }

  PopupMenuPosition? getPopupMenuPosition(String propertyName,
      [PopupMenuPosition? defaultValue]) {
    return parsePopupMenuPosition(get(propertyName), defaultValue);
  }

  ListTileTitleAlignment? getListTileTitleAlignment(String propertyName,
      [ListTileTitleAlignment? defaultValue]) {
    return parseListTileTitleAlignment(get(propertyName), defaultValue);
  }

  NavigationRailLabelType? getNavigationRailLabelType(String propertyName,
      [NavigationRailLabelType? defaultValue]) {
    return parseNavigationRailLabelType(get(propertyName), defaultValue);
  }

  FloatingLabelBehavior? getFloatingLabelBehavior(String propertyName,
      [FloatingLabelBehavior? defaultValue]) {
    return parseFloatingLabelBehavior(get(propertyName), defaultValue);
  }

  TabAlignment? getTabAlignment(String propertyName,
      [TabAlignment? defaultValue]) {
    return parseTabAlignment(get(propertyName), defaultValue);
  }
}
