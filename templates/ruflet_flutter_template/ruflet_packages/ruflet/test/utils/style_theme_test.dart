import 'dart:io';

import 'package:ruflet/src/utils/borders.dart';
import 'package:ruflet/src/utils/colors.dart';
import 'package:ruflet/src/utils/gradient.dart';
import 'package:ruflet/src/utils/material_style_theme.dart';
import 'package:ruflet/src/utils/overlay_style.dart';
import 'package:ruflet/src/utils/style_theme.dart';
import 'package:ruflet/src/utils/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire style parsers accept native semantic values without ThemeData',
      () {
    const style = RufletStyleTheme(colors: {
      'primary': Color(0xff123456),
      'outline': Color(0xff654321),
    });
    expect(parseColor('primary,0.5', style),
        const Color(0xff123456).withValues(alpha: 0.5));
    expect(parseTextStyle({'color': 'primary', 'size': 19}, style)?.color,
        const Color(0xff123456));
    expect(parseBorderSide({'color': 'outline'}, style)?.color,
        const Color(0xff654321));
    expect(parseColors(['primary', '#ffffff'], style),
        [const Color(0xff123456), const Color(0xffffffff)]);
  });

  test('protocol color swatches retain exact values and shade fallbacks', () {
    for (final entry in {
      'red': Colors.red,
      'blue100': Colors.blue.shade100,
      'green900': Colors.green.shade900,
      'pinkaccent200': Colors.pinkAccent.shade200,
      'black54': Colors.black54,
      'white70': Colors.white70,
      'transparent': Colors.transparent,
    }.entries) {
      expect(parseColor(entry.key, null)?.toARGB32(), entry.value.toARGB32(),
          reason: entry.key);
    }
  });

  test('Material adapter preserves Material roles only at its boundary', () {
    final material = ThemeData(colorSchemeSeed: Colors.teal);
    final style = materialStyleTheme(material);
    expect(style.color('primary'), material.colorScheme.primary);
    expect(style.color('on_surface'), material.colorScheme.onSurface);
    expect(style.textStyle('body_medium'), material.textTheme.bodyMedium);
  });

  test(
      'system chrome parses native roles without constructing a Material theme',
      () {
    const native = RufletStyleTheme(
      brightness: Brightness.dark,
      colors: {'surface': Color(0xff010203), 'primary': Color(0xffaabbcc)},
    );
    final overlay = parseSystemUiOverlayStyle({
      'status_bar_color': 'surface',
      'system_navigation_bar_color': 'primary',
    }, native, native.brightness)!;
    expect(overlay.statusBarColor, const Color(0xff010203));
    expect(overlay.systemNavigationBarColor, const Color(0xffaabbcc));
    expect(overlay.statusBarBrightness, Brightness.dark);
    expect(overlay.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('shared parsers work inside a plain WidgetsApp', (tester) async {
    Color? color;
    TextStyle? text;
    await tester.pumpWidget(WidgetsApp(
      color: const Color(0xff000000),
      builder: (context, child) => RufletStyleThemeScope(
        data: const RufletStyleTheme(
          colors: {'primary': Color(0xffaabbcc)},
          textStyles: {'bodymedium': TextStyle(fontSize: 23)},
        ),
        child: Builder(builder: (context) {
          color = RufletStyleTheme.of(context).color('primary');
          text = parseTextThemeStyle('bodymedium', context);
          return const SizedBox();
        }),
      ),
    ));
    expect(color, const Color(0xffaabbcc));
    expect(text?.fontSize, 23);
    expect(find.byType(Theme), findsNothing);
  });

  test('generic parser files never import either design library or adapter',
      () {
    for (final file in [
      'style_theme',
      'platform_theme',
      'colors',
      'color_palette',
      'text',
      'borders',
      'box',
      'gradient',
      'drawing',
      'icons',
      'images',
      'input',
      'alignment',
      'geometry',
      'misc',
      'time',
      'widget_state',
      'auto_complete',
      'dismissible',
      'overlay_style',
    ]) {
      final source = File('lib/src/utils/$file.dart').readAsStringSync();
      expect(source, isNot(contains('package:flutter/material.dart')),
          reason: file);
      expect(source, isNot(contains('package:flutter/cupertino.dart')),
          reason: file);
      expect(source, isNot(contains('material_style_theme.dart')),
          reason: file);
      expect(source, isNot(contains('cupertino_theme.dart')), reason: file);
    }
  });
}
