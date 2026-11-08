import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_list_tile.dart';
import 'list_tile.dart';
import 'list_tile_core.dart';

class AdaptiveListTileControl extends StatelessWidget {
  final Control control;

  const AdaptiveListTileControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveListTileControl build: ${control.id}");

    return CoreHost<ListTileCore>(
      key: ValueKey("control_${control.id}"),
      control: control,
      create: ListTileCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialListTileSkin(core: core),
        cupertino: (_) => CupertinoListTileSkin(core: core),
      ),
    );
  }
}
