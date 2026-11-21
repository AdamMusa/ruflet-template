import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/control.dart';
import 'numbers.dart';
import 'text.dart';
import 'enums.dart';

enum FormFieldInputBorder { outline, underline, none }

FormFieldInputBorder? parseFormFieldInputBorder(String? value,
    [FormFieldInputBorder? defaultValue]) {
  return parseEnum(FormFieldInputBorder.values, value, defaultValue);
}

TextInputType? parseTextInputType(String? value,
    [TextInputType? defaultValue]) {
  const typeMap = {
    "datetime": TextInputType.datetime,
    "email": TextInputType.emailAddress,
    "multiline": TextInputType.multiline,
    "name": TextInputType.name,
    "none": TextInputType.none,
    "number": TextInputType.number,
    "phone": TextInputType.phone,
    "streetaddress": TextInputType.streetAddress,
    "text": TextInputType.text,
    "url": TextInputType.url,
    "visiblepassword": TextInputType.visiblePassword,
    "websearch": TextInputType.webSearch,
    "twitter": TextInputType.twitter,
  };
  return typeMap[value == null ? null : normalizeEnumName(value)] ??
      defaultValue;
}

// Keyboard actions each platform's text input plugin accepts. Flutter asserts
// (services/text_input.dart) when a field requests an action outside its
// platform's list, so unsupported Ruby values fall back to the platform default.
const Set<TextInputAction> _androidTextInputActions = {
  TextInputAction.none,
  TextInputAction.unspecified,
  TextInputAction.done,
  TextInputAction.send,
  TextInputAction.go,
  TextInputAction.search,
  TextInputAction.next,
  TextInputAction.previous,
  TextInputAction.newline,
};

const Set<TextInputAction> _iOSTextInputActions = {
  TextInputAction.unspecified,
  TextInputAction.done,
  TextInputAction.send,
  TextInputAction.go,
  TextInputAction.search,
  TextInputAction.next,
  TextInputAction.newline,
  TextInputAction.continueAction,
  TextInputAction.join,
  TextInputAction.route,
  TextInputAction.emergencyCall,
};

/// Parses a Ruby `text_input_action` (camelCase or snake_case) for the
/// keyboard of [platform]. Returns `null` (the platform default) for unknown
/// values and for actions [platform]'s keyboard does not support.
TextInputAction? parseTextInputAction(String? value, TargetPlatform platform) {
  final action = parseEnum(TextInputAction.values, value?.replaceAll("_", ""));
  if (action == null) return null;
  return switch (platform) {
    TargetPlatform.android =>
      _androidTextInputActions.contains(action) ? action : null,
    TargetPlatform.iOS => _iOSTextInputActions.contains(action) ? action : null,
    _ => action,
  };
}

/// Whether Return on a multiline field ends editing (and so submits) instead
/// of inserting a newline: true for an explicit keyboard action such as
/// `done`, `send` or `next`.
bool textInputActionEndsMultilineEditing(TextInputAction? action) {
  return action != null &&
      action != TextInputAction.newline &&
      action != TextInputAction.unspecified &&
      action != TextInputAction.none;
}

StrutStyle? parseStrutStyle(dynamic value, [StrutStyle? defaultValue]) {
  if (value == null) return defaultValue;

  return StrutStyle(
    fontSize: parseDouble(value["size"]),
    fontWeight: parseFontWeight(value["weight"]),
    fontStyle: parseBool(value["italic"], false)! ? FontStyle.italic : null,
    fontFamily: value["font_family"],
    height: parseDouble(value["height"]),
    leading: parseDouble(value["leading"]),
    forceStrutHeight: parseBool(value["force_strut_height"]),
  );
}

extension InputParsers on Control {
  StrutStyle? getStrutStyle(String propertyName, [StrutStyle? defaultValue]) {
    return parseStrutStyle(get(propertyName), defaultValue);
  }

  FormFieldInputBorder? getFormFieldInputBorder(String propertyName,
      [FormFieldInputBorder? defaultValue]) {
    return parseFormFieldInputBorder(get(propertyName), defaultValue);
  }

  TextInputType? getTextInputType(String propertyName,
      [TextInputType? defaultValue]) {
    return parseTextInputType(get(propertyName), defaultValue);
  }

  /// The keyboard action for [propertyName], sanitized for the device
  /// keyboard ([defaultTargetPlatform]), not the page's design platform.
  TextInputAction? getTextInputAction(String propertyName,
      [TargetPlatform? platform]) {
    return parseTextInputAction(
        getString(propertyName), platform ?? defaultTargetPlatform);
  }
}
