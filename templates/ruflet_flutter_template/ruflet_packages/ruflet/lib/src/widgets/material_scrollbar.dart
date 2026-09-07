import 'package:flutter/material.dart';

class RufletMaterialScrollbar extends StatelessWidget {
  final ScrollController controller;
  final bool thumbVisibility;
  final double? thickness;
  final Widget child;

  const RufletMaterialScrollbar(
      {super.key,
      required this.controller,
      required this.thumbVisibility,
      required this.child,
      this.thickness});

  @override
  Widget build(BuildContext context) {
    final scrollbar = Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      thickness: thickness,
      child: child,
    );
    final theme = Theme.of(context);
    // Flutter's Material Scrollbar otherwise substitutes a Cupertino widget
    // when a Material page is explicitly rendered on an iOS host.
    return theme.platform == TargetPlatform.iOS
        ? Theme(
            data: theme.copyWith(platform: TargetPlatform.android),
            child: scrollbar)
        : scrollbar;
  }
}
