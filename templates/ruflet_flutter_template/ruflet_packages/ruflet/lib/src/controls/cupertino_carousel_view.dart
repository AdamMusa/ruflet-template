import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/style_theme.dart';
import 'carousel_view_model.dart';

const EdgeInsets _kItemPadding = EdgeInsets.all(4);
const double _kItemRadius = 20;

/// Cupertino renderer for Ruby `carousel_view`.
///
/// Flutter has no Cupertino carousel, so this is built from widgets-layer and
/// Cupertino pieces only (no Material). `item_extent` uses a fixed-extent
/// [ListView] with bouncing physics (snapping per item when `item_snapping`);
/// each item is a rounded [PhysicalShape] filled with `bgcolor` (default
/// `secondarySystemBackground`) that dims to 0.6 opacity while pressed.
/// `flex_weights` is approximated by a [PageView] whose viewport fraction is
/// the first weight's share, so every item is as wide as the leading one.
class CupertinoCarouselViewControl extends StatefulWidget {
  final Control control;
  final CarouselViewModel model;

  const CupertinoCarouselViewControl(
      {super.key, required this.control, required this.model});

  @override
  State<CupertinoCarouselViewControl> createState() =>
      _CupertinoCarouselViewControlState();
}

class _CupertinoCarouselViewControlState
    extends State<CupertinoCarouselViewControl> {
  ScrollController? _scrollController;
  PageController? _pageController;
  double _itemExtent = 0;

  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _scrollController?.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name != "animate_to_item") return null;
    final request = CarouselAnimateToItem.parse(args);
    if (request == null) return null;
    final index = widget.model.clampIndex(request.index);
    final pages = _pageController;
    final scroll = _scrollController;
    if (pages != null && pages.hasClients) {
      await pages.animateToPage(index,
          duration: request.duration, curve: request.curve);
    } else if (scroll != null && scroll.hasClients) {
      final position = scroll.position;
      await scroll.animateTo(
          (index * _itemExtent)
              .clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: request.duration,
          curve: request.curve);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoCarouselView build: ${widget.control.id}");

    final model = widget.model;
    return LayoutBuilder(builder: (context, constraints) {
      final viewport = model.scrollDirection == Axis.horizontal
          ? constraints.maxWidth
          : constraints.maxHeight;
      return model.weighted
          ? _buildWeighted(context)
          : _buildFixedExtent(context, viewport);
    });
  }

  Widget _buildFixedExtent(BuildContext context, double viewport) {
    final model = widget.model;
    // Like Material, an item never exceeds the viewport.
    _itemExtent = math.min(model.itemExtent!, viewport);
    final controller = _scrollController ??=
        ScrollController(initialScrollOffset: model.initialItem * _itemExtent);
    const bouncing = BouncingScrollPhysics();
    return ListView.builder(
      controller: controller,
      scrollDirection: model.scrollDirection,
      reverse: model.reverse,
      itemExtent: _itemExtent,
      physics: model.itemSnapping
          ? _ItemSnapScrollPhysics(itemExtent: _itemExtent, parent: bouncing)
          : bouncing,
      itemCount: model.items.length,
      itemBuilder: (context, index) => _item(context, index),
    );
  }

  Widget _buildWeighted(BuildContext context) {
    final model = widget.model;
    final weights = model.flexWeights!;
    final fraction = weights.first / weights.fold<int>(0, (a, b) => a + b);
    var controller = _pageController;
    if (controller == null || controller.viewportFraction != fraction) {
      controller?.dispose();
      controller = _pageController = PageController(
          viewportFraction: fraction, initialPage: model.initialItem);
    }
    return PageView.builder(
      controller: controller,
      scrollDirection: model.scrollDirection,
      reverse: model.reverse,
      padEnds: false,
      pageSnapping: model.itemSnapping,
      physics: const BouncingScrollPhysics(),
      itemCount: model.items.length,
      itemBuilder: (context, index) => _item(context, index),
    );
  }

  Widget _item(BuildContext context, int index) {
    final control = widget.control;
    final model = widget.model;
    final theme = RufletStyleTheme.of(context);
    final shape = control.getShape("shape", theme) ??
        const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_kItemRadius)));
    final color = control.getColor("bgcolor", context) ??
        CupertinoDynamicColor.resolve(
            CupertinoColors.secondarySystemBackground, context);
    final onItemClick = model.onItemClick;
    return Padding(
      key: ValueKey(model.items[index].id),
      padding: model.padding ?? _kItemPadding,
      child: _PressFeedback(
        enabled: model.enableSplash,
        overlayColor: control
            .getWidgetStateColor("overlay_color", theme)
            ?.resolve({WidgetState.pressed}),
        onTap: onItemClick == null ? null : () => onItemClick(index),
        child: PhysicalShape(
          clipper: ShapeBorderClipper(
              shape: shape, textDirection: Directionality.maybeOf(context)),
          clipBehavior: model.itemClipBehavior,
          elevation: model.elevation ?? 0,
          color: color,
          shadowColor: CupertinoColors.black,
          child: model.buildItem(index),
        ),
      ),
    );
  }
}

/// Dims the item (or paints `overlayColor` over it) while it is pressed, like
/// a CupertinoButton, without any Material ink.
class _PressFeedback extends StatefulWidget {
  final bool enabled;
  final Color? overlayColor;
  final VoidCallback? onTap;
  final Widget child;

  const _PressFeedback(
      {required this.enabled,
      required this.overlayColor,
      required this.onTap,
      required this.child});

  @override
  State<_PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<_PressFeedback> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (widget.enabled && _pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) return widget.child;
    final overlay = widget.overlayColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: onTap,
      child: overlay == null
          ? AnimatedOpacity(
              opacity: _pressed ? 0.6 : 1,
              duration: const Duration(milliseconds: 120),
              child: widget.child,
            )
          : Stack(
              fit: StackFit.passthrough,
              children: [
                widget.child,
                if (_pressed)
                  Positioned.fill(
                      child: IgnorePointer(child: ColoredBox(color: overlay))),
              ],
            ),
    );
  }
}

/// Settles a fling on the nearest whole item, the per-item equivalent of
/// [PageScrollPhysics] for a fixed-extent list.
class _ItemSnapScrollPhysics extends ScrollPhysics {
  final double itemExtent;

  const _ItemSnapScrollPhysics({required this.itemExtent, super.parent});

  @override
  _ItemSnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ItemSnapScrollPhysics(
          itemExtent: itemExtent, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, Tolerance tolerance, double velocity) {
    var item = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      item -= 0.5;
    } else if (velocity > tolerance.velocity) {
      item += 0.5;
    }
    return (item.roundToDouble() * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent) ||
        itemExtent <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _target(position, tolerance, velocity);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}
