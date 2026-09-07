import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_page_scaffold.dart';
import 'material_page_scaffold.dart';
import 'platform_page_scaffold_controller.dart';

export 'platform_page_scaffold_controller.dart';

/// One page-shell entry point with independent Material and Cupertino trees.
class PlatformPageScaffold extends StatelessWidget {
  final PageDesign design;
  final PlatformPageScaffoldController controller;
  final Color? backgroundColor;
  final Widget? appBar;
  final Widget body;
  final Widget? drawer;
  final Widget? endDrawer;
  final ValueChanged<bool>? onDrawerChanged;
  final ValueChanged<bool>? onEndDrawerChanged;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final dynamic floatingActionButtonLocation;

  const PlatformPageScaffold({
    super.key,
    required this.design,
    required this.controller,
    required this.body,
    this.backgroundColor,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.onDrawerChanged,
    this.onEndDrawerChanged,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    return switch (design) {
      PageDesign.cupertino => RufletCupertinoPageScaffold(
          controller: controller,
          backgroundColor: backgroundColor,
          navigationBar: appBar,
          body: body,
          drawer: drawer,
          endDrawer: endDrawer,
          onDrawerChanged: onDrawerChanged,
          onEndDrawerChanged: onEndDrawerChanged,
          bottomNavigationBar: bottomNavigationBar,
          bottomSheet: bottomSheet,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
        ),
      PageDesign.material => RufletMaterialPageScaffold(
          controller: controller,
          backgroundColor: backgroundColor,
          appBar: appBar,
          body: body,
          drawer: drawer,
          endDrawer: endDrawer,
          onDrawerChanged: onDrawerChanged,
          onEndDrawerChanged: onEndDrawerChanged,
          bottomNavigationBar: bottomNavigationBar,
          bottomSheet: bottomSheet,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
        ),
    };
  }
}
