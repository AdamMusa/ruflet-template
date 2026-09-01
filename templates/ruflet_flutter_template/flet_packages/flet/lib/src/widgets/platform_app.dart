import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_app_renderer.dart';
import 'material_app_renderer.dart';
import 'platform_app_config.dart';

export 'platform_app_config.dart';

class PlatformApp extends StatelessWidget {
  final PageDesign design;
  final PlatformAppConfig config;

  const PlatformApp({super.key, required this.design, required this.config});

  @override
  Widget build(BuildContext context) => switch (design) {
        PageDesign.material => MaterialAppRenderer(config: config),
        PageDesign.cupertino => CupertinoAppRenderer(config: config),
      };
}
