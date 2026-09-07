import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_pumping_heart.dart';
import 'material_pumping_heart.dart';

class PlatformPumpingHeart extends StatelessWidget {
  const PlatformPumpingHeart(
      {super.key,
      required this.color,
      required this.size,
      required this.duration});

  final Color color;
  final double size;
  final Duration duration;

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) =>
            MaterialPumpingHeart(color: color, size: size, duration: duration),
        cupertino: (_) =>
            CupertinoPumpingHeart(color: color, size: size, duration: duration),
      );
}
