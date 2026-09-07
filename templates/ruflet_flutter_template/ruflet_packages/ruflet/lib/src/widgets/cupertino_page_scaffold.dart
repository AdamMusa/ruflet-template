import 'package:flutter/cupertino.dart';

import 'platform_page_scaffold_controller.dart';

class RufletCupertinoPageScaffold extends StatefulWidget {
  final PlatformPageScaffoldController controller;
  final Color? backgroundColor;
  final Widget? navigationBar;
  final Widget body;
  final Widget? drawer;
  final Widget? endDrawer;
  final ValueChanged<bool>? onDrawerChanged;
  final ValueChanged<bool>? onEndDrawerChanged;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final dynamic floatingActionButtonLocation;

  const RufletCupertinoPageScaffold({
    super.key,
    required this.controller,
    required this.body,
    this.backgroundColor,
    this.navigationBar,
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
  State<RufletCupertinoPageScaffold> createState() =>
      _RufletCupertinoPageScaffoldState();
}

class _RufletCupertinoPageScaffoldState extends State<RufletCupertinoPageScaffold> {
  bool _drawerOpen = false;
  bool _endDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant RufletCupertinoPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detach(this);
    }
    _attachController();
  }

  void _attachController() {
    widget.controller.attach(
      owner: this,
      showDrawer: () => _setDrawer(drawer: true, open: true),
      closeDrawer: () => _setDrawer(drawer: true, open: false),
      showEndDrawer: () => _setDrawer(drawer: false, open: true),
      closeEndDrawer: () => _setDrawer(drawer: false, open: false),
    );
  }

  void _setDrawer({required bool drawer, required bool open}) {
    if (!mounted) {
      return;
    }
    if (drawer && widget.drawer == null ||
        !drawer && widget.endDrawer == null) {
      return;
    }
    final wasOpen = drawer ? _drawerOpen : _endDrawerOpen;
    if (wasOpen == open) {
      return;
    }
    setState(() {
      if (drawer) {
        _drawerOpen = open;
        if (open) _endDrawerOpen = false;
      } else {
        _endDrawerOpen = open;
        if (open) _drawerOpen = false;
      }
    });
    if (drawer) {
      widget.onDrawerChanged?.call(open);
    } else {
      widget.onEndDrawerChanged?.call(open);
    }
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  Alignment _floatingActionButtonAlignment() {
    final value = widget.floatingActionButtonLocation;
    if (value is Map) {
      return Alignment.bottomRight;
    }
    final name = value?.toString().toLowerCase().replaceAll('_', '') ?? '';
    final horizontal = name.contains('start')
        ? -1.0
        : name.contains('center')
            ? 0.0
            : 1.0;
    final vertical = name.contains('top') ? -1.0 : 1.0;
    return Alignment(horizontal, vertical);
  }

  Widget _buildContent() {
    Widget content = widget.body;
    if (widget.bottomNavigationBar != null) {
      content = Column(
        children: [
          Expanded(child: content),
          widget.bottomNavigationBar!,
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (widget.bottomSheet != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: widget.bottomSheet!,
          ),
        if (widget.floatingActionButton != null)
          Align(
            alignment: _floatingActionButtonAlignment(),
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: widget.floatingActionButton!,
            ),
          ),
        if (_drawerOpen || _endDrawerOpen) _buildDrawerOverlay(),
      ],
    );
  }

  Widget _buildDrawerOverlay() {
    final showStart = _drawerOpen;
    final drawer = showStart ? widget.drawer! : widget.endDrawer!;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setDrawer(drawer: showStart, open: false),
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Align(
            alignment: showStart
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.82,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: CupertinoPopupSurface(
                  child: SafeArea(child: drawer),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationBar = widget.navigationBar;
    return CupertinoPageScaffold(
      backgroundColor: widget.backgroundColor,
      navigationBar: navigationBar == null
          ? null
          : navigationBar is ObstructingPreferredSizeWidget
              ? navigationBar
              : _CupertinoNavigationBarHost(child: navigationBar),
      // CupertinoPageScaffold exposes the obstructed area as MediaQuery
      // padding when its navigation bar is translucent. The shared View body
      // is a Stack, not an inset-aware Cupertino scroll view, so consume it
      // here before laying out the canonical controls. Opaque bars already
      // consume their top inset and therefore are not padded twice.
      child: SafeArea(child: _buildContent()),
    );
  }
}

class _CupertinoNavigationBarHost extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  final Widget child;

  const _CupertinoNavigationBarHost({required this.child});

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => false;

  @override
  Widget build(BuildContext context) => child;
}
