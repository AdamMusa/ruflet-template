import 'package:flutter/widgets.dart';
import '../models/page_design.dart';

class PlatformAppConfig {
  final String title;
  final bool showSemanticsDebugger;
  final Widget? home;
  final dynamic routerDelegate;
  final dynamic routeInformationParser;
  final RouteInformationProvider? routeInformationProvider;
  final Map<dynamic, dynamic>? theme;
  final Map<dynamic, dynamic>? darkTheme;
  final RufletThemeMode? themeMode;
  final Brightness platformBrightness;
  final TargetPlatform? targetPlatform;
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
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.platformBrightness = Brightness.light,
    this.targetPlatform,
    required this.localizationsDelegates,
    required this.supportedLocales,
    required this.locale,
  });
}
