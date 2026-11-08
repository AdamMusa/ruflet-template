import 'package:flutter/material.dart';

import '../utils/material_enums.dart'
    show parseListTileStyle, parseListTileTitleAlignment;
import '../utils/theme.dart' show parseVisualDensity;
import 'list_tile_core.dart';

/// Material skin of [ListTileCore]: a ListTile on a transparent Material.
class MaterialListTileSkin extends StatelessWidget {
  const MaterialListTileSkin({super.key, required this.core});

  final ListTileCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        autofocus: p.autofocus,
        contentPadding: core.tilePadding,
        isThreeLine: p.isThreeLine,
        selected: p.selected,
        dense: p.dense,
        onTap: core.onTap,
        onLongPress: core.onLongPress,
        enabled: core.enabled,
        horizontalTitleGap: p.horizontalSpacing,
        enableFeedback: p.enableFeedback,
        minLeadingWidth: p.minLeadingWidth,
        minVerticalPadding: p.minVerticalPadding,
        minTileHeight: p.minHeight,
        selectedTileColor: p.selectedTileColor,
        selectedColor: p.selectedColor,
        focusColor: p.focusColor,
        tileColor: p.bgcolor,
        splashColor: p.splashColor,
        hoverColor: p.hoverColor,
        iconColor: p.iconColor,
        textColor: p.textColor,
        mouseCursor: p.mouseCursor,
        visualDensity: parseVisualDensity(p.visualDensity.string),
        shape: p.shape,
        titleTextStyle: p.titleTextStyle,
        leadingAndTrailingTextStyle: p.leadingAndTrailingTextStyle,
        subtitleTextStyle: p.subtitleTextStyle,
        titleAlignment: parseListTileTitleAlignment(p.titleAlignment.string),
        style: parseListTileStyle(p.style.string),
        leading: p.leading,
        title: p.title?.build(),
        subtitle: p.subtitle?.build(),
        // Uncolored, so the tile's icon color and states apply to it.
        trailing: core.trailingWithChevron(const Icon(Icons.chevron_right)),
      ),
    );
  }
}
