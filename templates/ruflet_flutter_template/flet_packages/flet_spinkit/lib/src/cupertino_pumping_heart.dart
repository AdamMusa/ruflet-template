import 'package:flutter/cupertino.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class CupertinoPumpingHeart extends StatelessWidget {
  const CupertinoPumpingHeart(
      {super.key,
      required this.color,
      required this.size,
      required this.duration});

  final Color color;
  final double size;
  final Duration duration;

  @override
  Widget build(BuildContext context) => SpinKitPumpingHeart(
        size: size,
        duration: duration,
        itemBuilder: (_, __) =>
            Icon(CupertinoIcons.heart_fill, color: color, size: size),
      );
}
