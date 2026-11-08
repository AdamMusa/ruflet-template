import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_button.dart';
import 'icon_button_core.dart';
import 'material_icon_button.dart';

/// Registry entry of the IconButton, FilledIconButton, FilledTonalIconButton
/// and OutlinedIconButton wire types.
class IconButtonControl extends StatelessWidget {
  final Control control;

  const IconButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("IconButton build: ${control.id}");

    return CoreHost<IconButtonCore>(
      // The legacy key plus the wire type: a core serves one wire type.
      key: ValueKey("control_${control.canonicalType}_${control.id}"),
      control: control,
      create: IconButtonCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialIconButtonSkin(core: core),
        cupertino: (_) => CupertinoIconButtonSkin(core: core),
      ),
    );
  }
}
