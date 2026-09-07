import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_scrollbar.dart';
import 'material_scrollbar.dart';
import 'platform_design.dart';

class PlatformScrollbar extends StatelessWidget {
  final ScrollController controller;
  final bool thumbVisibility;
  final double? thickness;
  final Widget child;

  const PlatformScrollbar(
      {super.key,
      required this.controller,
      required this.thumbVisibility,
      required this.child,
      this.thickness});

  @override
  Widget build(BuildContext context) => switch (effectivePageDesign(context)) {
        PageDesign.cupertino => RufletCupertinoScrollbar(
            controller: controller,
            thumbVisibility: thumbVisibility,
            thickness: thickness,
            child: child),
        PageDesign.material => RufletMaterialScrollbar(
            controller: controller,
            thumbVisibility: thumbVisibility,
            thickness: thickness,
            child: child),
      };
}
