import 'package:flutter/cupertino.dart';

class RufletCupertinoScrollbar extends StatelessWidget {
  final ScrollController controller;
  final bool thumbVisibility;
  final double? thickness;
  final Widget child;

  const RufletCupertinoScrollbar(
      {super.key,
      required this.controller,
      required this.thumbVisibility,
      required this.child,
      this.thickness});

  @override
  Widget build(BuildContext context) => CupertinoScrollbar(
        controller: controller,
        thumbVisibility: thumbVisibility,
        thickness: thickness ?? CupertinoScrollbar.defaultThickness,
        child: child,
      );
}
