import 'package:flutter/cupertino.dart';

import 'platform_app_config.dart';

class CupertinoAppRenderer extends StatelessWidget {
  final PlatformAppConfig config;

  const CupertinoAppRenderer({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return config.home != null
        ? CupertinoApp(
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: config.showSemanticsDebugger,
            title: config.title,
            theme: config.cupertinoTheme as CupertinoThemeData?,
            localizationsDelegates: config.localizationsDelegates,
            supportedLocales: config.supportedLocales,
            locale: config.locale,
            home: config.home,
          )
        : CupertinoApp.router(
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: config.showSemanticsDebugger,
            title: config.title,
            theme: config.cupertinoTheme as CupertinoThemeData?,
            localizationsDelegates: config.localizationsDelegates,
            supportedLocales: config.supportedLocales,
            locale: config.locale,
            routerDelegate: config.routerDelegate,
            routeInformationParser: config.routeInformationParser,
            routeInformationProvider: config.routeInformationProvider,
          );
  }
}
