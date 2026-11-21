import 'package:flutter/material.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';

/// Material 3 surface of a `DraggableScrollableSheet`: a rounded, elevated
/// sheet whose pinned header holds the M3 drag handle and the Ruby `header`.
class MaterialDraggableScrollableSheetSurface extends StatelessWidget {
  final Control control;
  final ScrollController scrollController;
  final Widget? header;
  final Widget list;

  const MaterialDraggableScrollableSheetSurface({
    super.key,
    required this.control,
    required this.scrollController,
    required this.header,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        control.getColor("bgcolor", context, scheme.surfaceContainerLow)!;
    final showHandle = control.getBool("show_drag_handle", true)!;

    return Material(
      color: color,
      elevation: control.getDouble("elevation", 1)!,
      shape: RoundedRectangleBorder(
          borderRadius: control.getBorderRadius("border_radius",
              const BorderRadius.vertical(top: Radius.circular(28)))!),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          if (showHandle || header != null)
            PinnedHeaderSliver(
              child: ColoredBox(
                color: color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHandle)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const SizedBox(width: 32, height: 4),
                          ),
                        ),
                      ),
                    if (header != null) header!,
                  ],
                ),
              ),
            ),
          list,
        ],
      ),
    );
  }
}
