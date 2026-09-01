import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/flet_store_mixin.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_snack_bar.dart';
import 'material_snack_bar.dart';

class SnackBarControl extends StatelessWidget with FletStoreMixin {
  final Control control;

  const SnackBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return withPagePlatform((context, platform) {
      return usesCupertinoControls(platform)
          ? CupertinoSnackBarControl(control: control)
          : MaterialSnackBarControl(control: control);
    });
  }
}
