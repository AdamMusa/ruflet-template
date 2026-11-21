import 'package:flutter/material.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';

/// Material pull-to-refresh: a [RefreshIndicator] over a [CustomScrollView].
class MaterialRefreshScrollView extends StatelessWidget {
  final Control control;
  final ScrollController? controller;
  final List<Widget> slivers;
  final bool shrinkWrap;
  final double? cacheExtent;
  final Clip clipBehavior;
  final int? semanticChildCount;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final RefreshCallback onRefresh;

  const MaterialRefreshScrollView({
    super.key,
    required this.control,
    required this.controller,
    required this.slivers,
    required this.shrinkWrap,
    required this.cacheExtent,
    required this.clipBehavior,
    required this.semanticChildCount,
    required this.keyboardDismissBehavior,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialRefreshScrollView build: ${control.id}");
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: control.getColor("refresh_color", context),
      backgroundColor: control.getColor("refresh_bgcolor", context),
      displacement: control.getDouble("refresh_displacement", 40.0)!,
      child: CustomScrollView(
        controller: controller,
        // Overscroll must be possible even when the content is shorter than
        // the viewport, or a short list could never be pulled.
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        cacheExtent: cacheExtent,
        clipBehavior: clipBehavior,
        semanticChildCount: semanticChildCount,
        keyboardDismissBehavior: keyboardDismissBehavior,
        slivers: slivers,
      ),
    );
  }
}
