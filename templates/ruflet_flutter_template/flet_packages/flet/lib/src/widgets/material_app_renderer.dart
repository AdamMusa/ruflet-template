import 'package:flutter/material.dart';

import '../models/page_design.dart';
import 'platform_app_config.dart';

class MaterialAppRenderer extends StatelessWidget {
  final PlatformAppConfig config;

  const MaterialAppRenderer({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final common = (
      debugShowCheckedModeBanner: false,
      showSemanticsDebugger: config.showSemanticsDebugger,
      title: config.title,
      theme: config.materialTheme as ThemeData?,
      darkTheme: config.materialDarkTheme as ThemeData?,
      themeMode: _materialThemeMode(config.materialThemeMode),
      localizationsDelegates: config.localizationsDelegates,
      supportedLocales: config.supportedLocales,
      locale: config.locale,
    );
    return config.home != null
        ? MaterialApp(
            debugShowCheckedModeBanner: common.debugShowCheckedModeBanner,
            showSemanticsDebugger: common.showSemanticsDebugger,
            title: common.title,
            theme: common.theme,
            darkTheme: common.darkTheme,
            themeMode: common.themeMode,
            localizationsDelegates: common.localizationsDelegates,
            supportedLocales: common.supportedLocales,
            locale: common.locale,
            home: config.home,
          )
        : MaterialApp.router(
            debugShowCheckedModeBanner: common.debugShowCheckedModeBanner,
            showSemanticsDebugger: common.showSemanticsDebugger,
            title: common.title,
            theme: common.theme,
            darkTheme: common.darkTheme,
            themeMode: common.themeMode,
            localizationsDelegates: common.localizationsDelegates,
            supportedLocales: common.supportedLocales,
            locale: common.locale,
            routerDelegate: config.routerDelegate,
            routeInformationParser: config.routeInformationParser,
            routeInformationProvider: config.routeInformationProvider,
          );
  }
}

ThemeMode? _materialThemeMode(Object? value) => switch (value) {
      ThemeMode mode => mode,
      FletThemeMode.system => ThemeMode.system,
      FletThemeMode.light => ThemeMode.light,
      FletThemeMode.dark => ThemeMode.dark,
      _ => null,
    };
