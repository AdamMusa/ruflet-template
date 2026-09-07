import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../ruflet_backend.dart';
import '../models/page_design.dart';
import 'page_context.dart';

/// Resolves chrome even before a backend exists, while honoring per-view design.
PageDesign effectivePageDesign(BuildContext context) {
  final page = PageContext.of(context);
  if (page != null) return page.widgetsDesign;
  return switch (effectiveTargetPlatform(context)) {
    TargetPlatform.iOS || TargetPlatform.macOS => PageDesign.cupertino,
    _ => PageDesign.material,
  };
}

TargetPlatform effectiveTargetPlatform(BuildContext context) =>
    PageContext.of(context)?.targetPlatform ??
    context.select<RufletBackend?, TargetPlatform>(
        (backend) => backend?.platform ?? defaultTargetPlatform);
