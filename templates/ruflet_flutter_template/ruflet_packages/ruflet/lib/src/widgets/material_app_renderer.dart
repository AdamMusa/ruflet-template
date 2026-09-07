import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/page_design.dart';
import '../utils/theme.dart';
import '../utils/material_style_theme.dart';
import '../utils/style_theme.dart';
import 'platform_app_config.dart';

class MaterialAppRenderer extends StatelessWidget {
  final PlatformAppConfig config;

  const MaterialAppRenderer({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final platform = config.targetPlatform ??
        switch (defaultTargetPlatform) {
          TargetPlatform.iOS || TargetPlatform.macOS => TargetPlatform.android,
          final platform => platform,
        };
    final common = (
      debugShowCheckedModeBanner: false,
      showSemanticsDebugger: config.showSemanticsDebugger,
      title: config.title,
      theme: parseTheme(config.theme, context, Brightness.light)
          .copyWith(platform: platform),
      darkTheme:
          parseTheme(config.darkTheme ?? config.theme, context, Brightness.dark)
              .copyWith(platform: platform),
      themeMode: _materialThemeMode(config.themeMode),
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
            builder: _styleScope,
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
            builder: _styleScope,
          );
  }
}

Widget _styleScope(BuildContext context, Widget? child) => RufletStyleThemeScope(
      data: materialStyleTheme(Theme.of(context)),
      child: child ?? const SizedBox.shrink(),
    );

ThemeMode? _materialThemeMode(Object? value) => switch (value) {
      ThemeMode mode => mode,
      RufletThemeMode.system => ThemeMode.system,
      RufletThemeMode.light => ThemeMode.light,
      RufletThemeMode.dark => ThemeMode.dark,
      _ => null,
    };
