import 'package:flutter/widgets.dart';
import '../models/control.dart';
import '../utils/colors.dart';

/// Keep the live DSL barrier in the route's barrier overlay, never inside the
/// dialog content: Cupertino scales the content during its entrance animation.
mixin ControlBarrier<T> on ModalRoute<T> {
  Control get control;
  Color? defaultBarrierColor(BuildContext context);

  @override
  Color? get barrierColor {
    final context = navigator!.context;
    return control.getColor('barrier_color', context) ??
        defaultBarrierColor(context);
  }

  @override
  Widget buildModalBarrier() => AnimatedBuilder(
        animation: control,
        builder: (context, _) => super.buildModalBarrier(),
      );
}
