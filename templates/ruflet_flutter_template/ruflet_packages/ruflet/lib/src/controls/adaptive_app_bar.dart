import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/page_design.dart';
import '../widgets/platform_design.dart';
import 'app_bar.dart';
import 'app_bar_core.dart';
import 'cupertino_app_bar.dart';

class AdaptiveAppBarControl extends StatelessWidget {
  final Control control;

  const AdaptiveAppBarControl({super.key, required this.control});

  /// Scaffolds need the selected renderer's size and obstruction contract
  /// before building it; an intervening Widget wrapper hides that metadata.
  /// So the skin is the widget they get, and it hosts the core
  /// (`CoreHost.adopt`).
  static PreferredSizeWidget resolve({
    required Control control,
    required PageDesign design,
  }) {
    final core = AppBarCore(control);
    return switch (design) {
      PageDesign.cupertino => CupertinoAppBarSkin(core: core),
      PageDesign.material => MaterialAppBarSkin(core: core),
    };
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveAppBarControl build: ${control.id}");

    return resolve(control: control, design: effectivePageDesign(context));
  }
}
