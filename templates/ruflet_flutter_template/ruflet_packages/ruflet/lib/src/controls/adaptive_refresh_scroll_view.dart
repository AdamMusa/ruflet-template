import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_refresh_scroll_view.dart';
import 'material_refresh_scroll_view.dart';
import 'refresh_coordinator.dart';

/// A pull-to-refresh scroll view for a Ruby control with `on_refresh`.
///
/// Material renders a `RefreshIndicator`, Cupertino a
/// `CupertinoSliverRefreshControl`; both run the same [RefreshCoordinator],
/// which fires `refresh` and waits for Ruby's `end_refresh`. The coordinator
/// lives in this State, so a rebuild (or a design switch) keeps a pending
/// refresh.
class AdaptiveRefreshScrollView extends StatefulWidget {
  final Control control;
  final ScrollController? controller;
  final List<Widget> slivers;
  final bool shrinkWrap;
  final double? cacheExtent;
  final Clip clipBehavior;
  final int? semanticChildCount;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  const AdaptiveRefreshScrollView({
    super.key,
    required this.control,
    required this.controller,
    required this.slivers,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.clipBehavior = Clip.hardEdge,
    this.semanticChildCount,
    this.keyboardDismissBehavior,
  });

  @override
  State<AdaptiveRefreshScrollView> createState() =>
      _AdaptiveRefreshScrollViewState();
}

class _AdaptiveRefreshScrollViewState extends State<AdaptiveRefreshScrollView> {
  late final RefreshCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = RefreshCoordinator(widget.control);
  }

  @override
  void didUpdateWidget(covariant AdaptiveRefreshScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _coordinator.control = widget.control;
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialRefreshScrollView(
        control: widget.control,
        controller: widget.controller,
        slivers: widget.slivers,
        shrinkWrap: widget.shrinkWrap,
        cacheExtent: widget.cacheExtent,
        clipBehavior: widget.clipBehavior,
        semanticChildCount: widget.semanticChildCount,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        onRefresh: _coordinator.refresh,
      ),
      cupertino: (_) => CupertinoRefreshScrollView(
        control: widget.control,
        controller: widget.controller,
        slivers: widget.slivers,
        shrinkWrap: widget.shrinkWrap,
        cacheExtent: widget.cacheExtent,
        clipBehavior: widget.clipBehavior,
        semanticChildCount: widget.semanticChildCount,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        onRefresh: _coordinator.refresh,
      ),
    );
  }
}
