import 'package:flutter/material.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/style_theme.dart';
import 'carousel_view_model.dart';

/// Material renderer for Ruby `carousel_view`: Flutter's M3 [CarouselView]
/// (or [CarouselView.weighted] when `flex_weights` is set).
class MaterialCarouselViewControl extends StatefulWidget {
  final Control control;
  final CarouselViewModel model;

  const MaterialCarouselViewControl(
      {super.key, required this.control, required this.model});

  @override
  State<MaterialCarouselViewControl> createState() =>
      _MaterialCarouselViewControlState();
}

class _MaterialCarouselViewControlState
    extends State<MaterialCarouselViewControl> {
  late final CarouselController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CarouselController(initialItem: widget.model.initialItem);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _controller.dispose();
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name != "animate_to_item") return null;
    final request = CarouselAnimateToItem.parse(args);
    if (request != null) {
      await _controller.animateToItem(request.index,
          duration: request.duration, curve: request.curve);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialCarouselView build: ${widget.control.id}");

    final control = widget.control;
    final model = widget.model;
    final theme = RufletStyleTheme.of(context);
    final children = [
      for (var i = 0; i < model.items.length; i++) model.buildItem(i)
    ];
    final backgroundColor = control.getColor("bgcolor", context);
    final shape = control.getShape("shape", theme);
    final overlayColor = control.getWidgetStateColor("overlay_color", theme);

    return model.weighted
        ? CarouselView.weighted(
            controller: _controller,
            flexWeights: model.flexWeights!,
            consumeMaxWeight: model.consumeMaxWeight,
            shrinkExtent: model.shrinkExtent,
            itemSnapping: model.itemSnapping,
            scrollDirection: model.scrollDirection,
            reverse: model.reverse,
            padding: model.padding,
            backgroundColor: backgroundColor,
            elevation: model.elevation,
            shape: shape,
            itemClipBehavior: model.itemClipBehavior,
            overlayColor: overlayColor,
            enableSplash: model.enableSplash,
            onTap: model.onItemClick,
            children: children,
          )
        : CarouselView(
            controller: _controller,
            itemExtent: model.itemExtent!,
            shrinkExtent: model.shrinkExtent,
            itemSnapping: model.itemSnapping,
            scrollDirection: model.scrollDirection,
            reverse: model.reverse,
            padding: model.padding,
            backgroundColor: backgroundColor,
            elevation: model.elevation,
            shape: shape,
            itemClipBehavior: model.itemClipBehavior,
            overlayColor: overlayColor,
            enableSplash: model.enableSplash,
            onTap: model.onItemClick,
            children: children,
          );
  }
}
