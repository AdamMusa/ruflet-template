import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/images.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoCircleAvatarControl extends StatelessWidget {
  final Control control;

  const CupertinoCircleAvatarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final foreground =
        control.getImageProvider("foreground_image_src", context);
    final background =
        control.getImageProvider("background_image_src", context);
    final radius = control.getDouble("radius", 20)!;
    final minRadius = control.getDouble("min_radius", radius)!;
    final maxRadius = control.getDouble("max_radius", radius)!;
    final diameter = radius * 2;

    Widget layer(ImageProvider image, String source) => Positioned.fill(
          child: Image(
            image: image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              control.triggerEvent("image_error", source);
              return const SizedBox.shrink();
            },
          ),
        );

    final avatar = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minRadius * 2,
        minHeight: minRadius * 2,
        maxWidth: maxRadius * 2,
        maxHeight: maxRadius * 2,
      ),
      child: SizedBox.square(
        dimension: diameter,
        child: ClipOval(
          child: ColoredBox(
            color: control.getColor("bgcolor", context) ??
                CupertinoColors.systemGrey5.resolveFrom(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (background != null) layer(background, "background"),
                Center(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: control.getColor("color", context)),
                    child: control.buildTextOrWidget("content") ??
                        const SizedBox.shrink(),
                  ),
                ),
                if (foreground != null) layer(foreground, "foreground"),
              ],
            ),
          ),
        ),
      ),
    );
    return LayoutControl(control: control, child: avatar);
  }
}
