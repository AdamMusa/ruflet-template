import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/utils/style_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native theme preserves all common semantic overrides',
      (tester) async {
    late CupertinoThemeData parsed;
    late RufletStyleTheme styles;
    await tester.pumpWidget(CupertinoApp(
      home: Builder(builder: (context) {
        parsed = parseCupertinoTheme({
          'color_scheme_seed': '#112233',
          'color_scheme': {
            'secondary': '#445566',
            'on_surface': '#778899',
            'surface': '#eeeeee',
          },
          'font_family': 'Example',
          'text_theme': {
            'body_medium': {'size': 19},
            'body_small': {'size': 11, 'color': 'secondary'},
          },
        }, context, Brightness.light);
        return CupertinoTheme(
          data: parsed,
          child: Builder(builder: (context) {
            styles = cupertinoStyleTheme(context);
            return const SizedBox();
          }),
        );
      }),
    ));

    expect(parsed, isA<RufletCupertinoThemeData>());
    expect(parsed.primaryColor, const Color(0xff112233));
    expect(parsed.scaffoldBackgroundColor, const Color(0xffeeeeee));
    expect(parsed.textTheme.textStyle.fontSize, 19);
    expect(parsed.textTheme.textStyle.fontFamily, 'Example');
    expect(styles.color('secondary'), const Color(0xff445566));
    expect(styles.textStyle('body_small')?.fontSize, 11);
    expect(styles.textStyle('body_small')?.color, const Color(0xff445566));
  });

  testWidgets('default dark theme retains native dynamic color behavior',
      (tester) async {
    late Color background;
    late Color label;
    late Color expectedBackground;
    late Color expectedLabel;
    await tester.pumpWidget(CupertinoApp(
      home: Builder(builder: (context) {
        final theme = parseCupertinoTheme(null, context, Brightness.dark);
        return CupertinoTheme(
          data: theme,
          child: Builder(builder: (context) {
            final styles = cupertinoStyleTheme(context);
            background = styles.color('surface')!;
            label = styles.color('on_surface')!;
            expectedBackground =
                CupertinoColors.systemBackground.resolveFrom(context);
            expectedLabel = CupertinoColors.label.resolveFrom(context);
            return const SizedBox();
          }),
        );
      }),
    ));
    expect(background.toARGB32(), expectedBackground.toARGB32());
    expect(label.toARGB32(), expectedLabel.toARGB32());
    expect(background, const Color(0xff000000));
    expect(label, const Color(0xffffffff));
  });

  testWidgets('nested native themes inherit custom roles and apply local ones',
      (tester) async {
    late CupertinoThemeData parent;
    late RufletStyleTheme styles;
    await tester.pumpWidget(CupertinoApp(
      home: Builder(builder: (context) {
        parent = parseCupertinoTheme({
          'color_scheme': {'secondary': '#abcdef'},
          'text_theme': {
            'body_small': {'size': 13}
          },
        }, context, Brightness.light);
        final nested = parseCupertinoTheme({
          'color_scheme_seed': '#123456',
        }, context, Brightness.dark, parentTheme: parent);
        return CupertinoTheme(
          data: nested,
          child: Builder(builder: (context) {
            styles = cupertinoStyleTheme(context);
            return const SizedBox();
          }),
        );
      }),
    ));
    expect(styles.brightness, Brightness.dark);
    expect(styles.color('primary'), const Color(0xff123456));
    expect(styles.color('secondary'), const Color(0xffabcdef));
    expect(styles.color('surface'), const Color(0xff000000));
    expect(styles.textStyle('body_small')?.fontSize, 13);
    final copied = (parent as RufletCupertinoThemeData)
        .copyWith(primaryColor: const Color(0xff654321));
    expect(copied.colorOverrides['primary'], const Color(0xff654321));
    expect(copied.colorOverrides['secondary'], const Color(0xffabcdef));
    expect(() => copied.colorOverrides['secondary'] = const Color(0xff000000),
        throwsUnsupportedError);
  });
}
