import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_content_controls.dart';
import 'material_tabs.dart';

class TabsControl extends StatelessWidget {
  final Control control;

  const TabsControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialTabsControl(control: control),
        cupertino: (_) => CupertinoTabsControl(control: control),
      );
}

class TabBarViewControl extends StatelessWidget {
  final Control control;

  const TabBarViewControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialTabBarViewControl(control: control),
        cupertino: (_) => CupertinoTabBarViewControl(control: control),
      );
}

class TabControl extends StatelessWidget {
  final Control control;

  const TabControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialTabControl(control: control),
        cupertino: (_) => CupertinoTabControl(control: control),
      );
}

class TabBarControl extends StatelessWidget {
  final Control control;

  const TabBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialTabBarControl(control: control),
        cupertino: (_) => CupertinoTabBarControl(control: control),
      );
}
