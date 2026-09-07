import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'platform_design.dart';

/// The native visual language used to render a Ruflet control.
enum RufletControlDesign { material, cupertino }

/// Resolves the visual language once for every platform-aware control.
///
/// Apple platforms use Cupertino widgets. Android, Windows, Linux, Fuchsia,
/// and web targets use Material widgets unless the page reports an Apple
/// target platform.
RufletControlDesign controlDesignForPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => RufletControlDesign.cupertino,
    _ => RufletControlDesign.material,
  };
}

bool usesCupertinoControls(TargetPlatform platform) {
  return controlDesignForPlatform(platform) == RufletControlDesign.cupertino;
}

/// A single control entry point with separate Material and Cupertino
/// renderers selected from the page's effective platform.
class PlatformControlRenderer extends StatelessWidget {
  final WidgetBuilder material;
  final WidgetBuilder cupertino;

  const PlatformControlRenderer({
    super.key,
    required this.material,
    required this.cupertino,
  });

  @override
  Widget build(BuildContext context) {
    return effectivePageDesign(context) == PageDesign.cupertino
        ? cupertino(context)
        : material(context);
  }
}
