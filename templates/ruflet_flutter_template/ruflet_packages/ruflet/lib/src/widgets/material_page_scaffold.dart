import 'package:flutter/material.dart';

import '../utils/buttons.dart';
import 'platform_page_scaffold_controller.dart';

class RufletMaterialPageScaffold extends StatefulWidget {
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

  const RufletMaterialPageScaffold({
    super.key,
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
  State<RufletMaterialPageScaffold> createState() =>
      _RufletMaterialPageScaffoldState();
}

class _RufletMaterialPageScaffoldState extends State<RufletMaterialPageScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant RufletMaterialPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detach(this);
    }
    _attachController();
  }

  void _attachController() {
    widget.controller.attach(
      owner: this,
      showDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
      showEndDrawer: () => _scaffoldKey.currentState?.openEndDrawer(),
      closeEndDrawer: () => _scaffoldKey.currentState?.closeEndDrawer(),
    );
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      appBar: widget.appBar == null
          ? null
          : widget.appBar is PreferredSizeWidget
              ? widget.appBar as PreferredSizeWidget
              : PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: widget.appBar!,
                ),
      drawer: widget.drawer,
      onDrawerChanged: widget.onDrawerChanged,
      endDrawer: widget.endDrawer,
      onEndDrawerChanged: widget.onEndDrawerChanged,
      body: widget.body,
      bottomNavigationBar: widget.bottomNavigationBar,
      bottomSheet: widget.bottomSheet,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: parseFloatingActionButtonLocation(
        widget.floatingActionButtonLocation,
        FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
