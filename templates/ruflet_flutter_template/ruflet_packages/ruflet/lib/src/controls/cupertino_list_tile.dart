import 'package:flutter/cupertino.dart';

import '../widgets/ruflet_cupertino_list_tile.dart';
import 'list_tile_core.dart';

/// Cupertino skin of [ListTileCore]: the forked iOS list tile (base or
/// notched). It reports the same button, enabled and selected states to
/// accessibility as the Material tile.
class CupertinoListTileSkin extends StatelessWidget {
  const CupertinoListTileSkin({super.key, required this.core});

  final ListTileCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    final onTap = core.onTap;
    final onLongPress = core.onLongPress;
    // A tile without a title still renders, as on Material.
    final title = p.title?.build() ?? const SizedBox.shrink();
    final trailingRow =
        core.trailingWithChevron(const RufletCupertinoListTileChevron());
    final tile = p.notched
        ? RufletCupertinoListTile.notched(
            onTap: onTap,
            onLongPress: onLongPress,
            additionalInfo: p.additionalInfo?.build(),
            backgroundColor: p.bgcolor,
            backgroundColorActivated: p.bgcolorActivated,
            leading: p.leading,
            leadingSize: p.leadingSize ?? 30.0,
            leadingToTitle: p.leadingToTitle ?? 12.0,
            padding: core.tilePadding,
            title: title,
            subtitle: p.subtitle?.build(),
            trailing: trailingRow,
          )
        : RufletCupertinoListTile(
            onTap: onTap,
            onLongPress: onLongPress,
            additionalInfo: p.additionalInfo?.build(),
            backgroundColor: p.bgcolor,
            backgroundColorActivated: p.bgcolorActivated,
            leading: p.leading,
            leadingSize: p.leadingSize ?? 28.0,
            leadingToTitle: p.leadingToTitle ?? 16.0,
            padding: core.tilePadding,
            title: title,
            subtitle: p.subtitle?.build(),
            trailing: trailingRow,
          );
    return Semantics(
      button: onTap != null || onLongPress != null,
      selected: p.selected,
      enabled: core.enabled,
      child: tile,
    );
  }
}
