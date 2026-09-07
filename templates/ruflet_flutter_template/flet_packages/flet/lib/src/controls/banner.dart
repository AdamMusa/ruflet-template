import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_banner.dart';
import 'material_banner.dart';

class BannerControl extends StatelessWidget {
  final Control control;

  const BannerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialBannerControl(control: control),
      cupertino: (_) => CupertinoBannerControl(control: control),
    );
  }
}
