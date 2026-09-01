import 'package:flutter/widgets.dart';

class PlatformAppConfig {
  final String title;
  final bool showSemanticsDebugger;
  final Widget? home;
  final dynamic routerDelegate;
  final dynamic routeInformationParser;
  final RouteInformationProvider? routeInformationProvider;
  final Object? materialTheme;
  final Object? materialDarkTheme;
  final Object? materialThemeMode;
  final Object? cupertinoTheme;
  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final Locale? locale;

  const PlatformAppConfig({
    required this.title,
    required this.showSemanticsDebugger,
    required this.home,
    required this.routerDelegate,
    required this.routeInformationParser,
    required this.routeInformationProvider,
    required this.materialTheme,
    required this.materialDarkTheme,
    required this.materialThemeMode,
    required this.cupertinoTheme,
    required this.localizationsDelegates,
    required this.supportedLocales,
    required this.locale,
  });
}
