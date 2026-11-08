import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/error.dart';
import '../widgets/platform_control_renderer.dart';
import 'base_controls.dart';
import 'carousel_view_model.dart';
import 'cupertino_carousel_view.dart';
import 'material_carousel_view.dart';

class AdaptiveCarouselViewControl extends StatelessWidget {
  final Control control;

  const AdaptiveCarouselViewControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveCarouselView build: ${control.id}");

    final model = CarouselViewModel(control);
    final error = model.error;
    final renderer = PlatformControlRenderer(
      material: (_) =>
          MaterialCarouselViewControl(control: control, model: model),
      cupertino: (_) =>
          CupertinoCarouselViewControl(control: control, model: model),
    );
    return LayoutControl(
      control: control,
      child: error ??
          LayoutBuilder(builder: (context, constraints) {
            // A carousel is a scroll view: it needs a finite extent on both
            // axes (e.g. a horizontal carousel inside a Column needs height).
            final horizontal = model.scrollDirection == Axis.horizontal;
            final cross = horizontal ? "height" : "width";
            final main = horizontal ? "width" : "height";
            final crossBounded = horizontal
                ? constraints.hasBoundedHeight
                : constraints.hasBoundedWidth;
            final mainBounded = horizontal
                ? constraints.hasBoundedWidth
                : constraints.hasBoundedHeight;
            if (!crossBounded || !mainBounded) {
              final missing = crossBounded ? main : cross;
              return ErrorControl("CarouselView needs a bounded $missing",
                  description: "Set $missing or expand");
            }
            return renderer;
          }),
    );
  }
}
