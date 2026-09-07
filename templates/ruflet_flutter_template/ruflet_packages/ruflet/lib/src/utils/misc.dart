import 'style_theme.dart';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../models/control.dart';
import 'borders.dart';
import 'enums.dart';
import 'numbers.dart';

Clip? parseClip(String? value, [Clip? defaultValue]) {
  return parseEnum(Clip.values, value, defaultValue);
}

Orientation? parseOrientation(String? value, [Orientation? defaultValue]) {
  return parseEnum(Orientation.values, value, defaultValue);
}

StrokeCap? parseStrokeCap(String? value, [StrokeCap? defaultValue]) {
  return parseEnum(StrokeCap.values, value, defaultValue);
}

StrokeJoin? parseStrokeJoin(String? value, [StrokeJoin? defaultValue]) {
  return parseEnum(StrokeJoin.values, value, defaultValue);
}

BoxShape? parseBoxShape(String? value, [BoxShape? defaultValue]) {
  return parseEnum(BoxShape.values, value, defaultValue);
}

NotchedShape? parseNotchedShape(dynamic value, RufletStyleTheme? theme,
    [NotchedShape? defaultValue]) {
  if (value == null) return defaultValue;

  var type = value["_type"];
  if (type == "circular") {
    return CircularNotchedRectangle(
        inverted: parseBool(value["inverted"], false)!);
  } else if (type == "auto") {
    return AutomaticNotchedShape(
        parseShapeBorder(value["host"], (theme),
            const ContinuousRectangleBorder())!,
        parseShapeBorder(value["guest"], (theme)));
  } else {
    return defaultValue;
  }
}

StackFit? parseStackFit(String? value, [StackFit? defaultValue]) {
  return parseEnum(StackFit.values, value, defaultValue);
}

enum CardVariant { elevated, filled, outlined }

CardVariant? parseCardVariant(String? value, [CardVariant? defaultValue]) {
  return parseEnum(CardVariant.values, value, defaultValue);
}

enum ScrollMode { none, auto, adaptive, always, hidden }

ScrollMode? parseScrollMode(String? value,
    [ScrollMode? defaultValue = ScrollMode.none]) {
  return parseEnum(ScrollMode.values, value, defaultValue);
}

enum LabelPosition { right, left }

LabelPosition? parseLabelPosition(String? value,
    [LabelPosition? defaultValue]) {
  return parseEnum(LabelPosition.values, value, defaultValue);
}

Assertiveness? parseAssertiveness(String? value,
    [Assertiveness? defaultValue]) {
  return parseEnum(Assertiveness.values, value, defaultValue);
}

Axis? parseAxis(String? value, [Axis? defaultValue]) {
  return parseEnum(Axis.values, value, defaultValue);
}

PointerDeviceKind? parsePointerDeviceKind(String? value,
    [PointerDeviceKind? defaultValue]) {
  return parseEnum(PointerDeviceKind.values, value, defaultValue);
}

BlurStyle? parseBlurStyle(String? value, [BlurStyle? defaultValue]) {
  return parseEnum(BlurStyle.values, value, defaultValue);
}

extension MiscParsers on Control {
  Clip? getClipBehavior(String propertyName, [Clip? defaultValue]) {
    return parseClip(get(propertyName), defaultValue);
  }

  Orientation? getOrientation(String propertyName,
      [Orientation? defaultValue]) {
    return parseOrientation(get(propertyName), defaultValue);
  }

  StrokeCap? getStrokeCap(String propertyName, [StrokeCap? defaultValue]) {
    return parseStrokeCap(get(propertyName), defaultValue);
  }

  StrokeJoin? getStrokeJoin(String propertyName, [StrokeJoin? defaultValue]) {
    return parseStrokeJoin(get(propertyName), defaultValue);
  }

  BoxShape? getBoxShape(String propertyName, [BoxShape? defaultValue]) {
    return parseBoxShape(get(propertyName), defaultValue);
  }

  NotchedShape? getNotchedShape(String propertyName, RufletStyleTheme? theme,
      [NotchedShape? defaultValue]) {
    return parseNotchedShape(get(propertyName), theme, defaultValue);
  }

  StackFit? getStackFit(String propertyName, [StackFit? defaultValue]) {
    return parseStackFit(get(propertyName), defaultValue);
  }

  CardVariant? getCardVariant(String propertyName,
      [CardVariant? defaultValue]) {
    return parseCardVariant(get(propertyName), defaultValue);
  }

  ScrollMode? getScrollMode(String propertyName,
      [ScrollMode? defaultValue = ScrollMode.none]) {
    return parseScrollMode(get(propertyName), defaultValue);
  }

  LabelPosition? getLabelPosition(String propertyName,
      [LabelPosition? defaultValue]) {
    return parseLabelPosition(get(propertyName), defaultValue);
  }

  Assertiveness? getAssertiveness(String propertyName,
      [Assertiveness? defaultValue]) {
    return parseAssertiveness(get(propertyName), defaultValue);
  }

  Axis? getAxis(String propertyName, [Axis? defaultValue]) {
    return parseAxis(get(propertyName), defaultValue);
  }

  PointerDeviceKind? getPointerDeviceKind(String propertyName,
      [PointerDeviceKind? defaultValue]) {
    return parsePointerDeviceKind(get(propertyName), defaultValue);
  }

  BlurStyle? getBlurStyle(String propertyName, [BlurStyle? defaultValue]) {
    return parseBlurStyle(get(propertyName), defaultValue);
  }
}
