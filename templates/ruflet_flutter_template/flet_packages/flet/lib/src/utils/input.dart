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
  return typeMap[value?.toLowerCase()] ?? defaultValue;
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
}
