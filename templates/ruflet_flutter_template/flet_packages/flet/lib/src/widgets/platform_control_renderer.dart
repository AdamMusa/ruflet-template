import 'package:flutter/widgets.dart';

import 'flet_store_mixin.dart';

/// The native visual language used to render a Flet control.
enum FletControlDesign { material, cupertino }

/// Resolves the visual language once for every platform-aware control.
///
/// Apple platforms use Cupertino widgets. Android, Windows, Linux, Fuchsia,
/// and web targets use Material widgets unless the page reports an Apple
/// target platform.
FletControlDesign controlDesignForPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => FletControlDesign.cupertino,
    _ => FletControlDesign.material,
  };
}

bool usesCupertinoControls(TargetPlatform platform) {
  return controlDesignForPlatform(platform) == FletControlDesign.cupertino;
}

/// A single control entry point with separate Material and Cupertino
/// renderers selected from the page's effective platform.
class PlatformControlRenderer extends StatelessWidget with FletStoreMixin {
  final WidgetBuilder material;
  final WidgetBuilder cupertino;

  const PlatformControlRenderer({
    super.key,
    required this.material,
    required this.cupertino,
  });

  @override
  Widget build(BuildContext context) {
    return withPagePlatform((context, platform) {
      return usesCupertinoControls(platform)
          ? cupertino(context)
          : material(context);
    });
  }
}
