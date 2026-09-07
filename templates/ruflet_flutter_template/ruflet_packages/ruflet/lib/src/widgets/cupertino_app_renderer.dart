import 'package:flutter/cupertino.dart';

import '../models/page_design.dart';
import '../utils/cupertino_theme.dart';
import '../utils/style_theme.dart';
import 'platform_app_config.dart';

class CupertinoAppRenderer extends StatelessWidget {
  final PlatformAppConfig config;

  const CupertinoAppRenderer({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final brightness = config.themeMode.usesLight(config.platformBrightness)
        ? Brightness.light
        : Brightness.dark;
    final theme = parseCupertinoTheme(
        brightness == Brightness.dark
            ? config.darkTheme ?? config.theme
            : config.theme,
        context,
        brightness);
    Widget withStyleTheme(BuildContext context, Widget? child) =>
        RufletStyleThemeScope(
          data: cupertinoStyleTheme(context),
          child: child ?? const SizedBox.shrink(),
        );
    return config.home != null
        ? CupertinoApp(
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: config.showSemanticsDebugger,
            title: config.title,
            theme: theme,
            localizationsDelegates: config.localizationsDelegates,
            supportedLocales: config.supportedLocales,
            locale: config.locale,
            builder: withStyleTheme,
            home: config.home,
          )
        : CupertinoApp.router(
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: config.showSemanticsDebugger,
            title: config.title,
            theme: theme,
            localizationsDelegates: config.localizationsDelegates,
            supportedLocales: config.supportedLocales,
            locale: config.locale,
            builder: withStyleTheme,
            routerDelegate: config.routerDelegate,
            routeInformationParser: config.routeInformationParser,
            routeInformationProvider: config.routeInformationProvider,
          );
  }
}
