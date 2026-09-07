import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class MaterialPumpingHeart extends StatelessWidget {
  const MaterialPumpingHeart(
      {super.key,
      required this.color,
      required this.size,
      required this.duration});

  final Color color;
  final double size;
  final Duration duration;

  @override
  Widget build(BuildContext context) =>
      SpinKitPumpingHeart(color: color, size: size, duration: duration);
}
