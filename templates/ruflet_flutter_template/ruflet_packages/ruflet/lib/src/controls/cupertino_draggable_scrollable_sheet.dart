import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';

/// iOS surface of a `DraggableScrollableSheet`: a rounded system-background
/// card with a soft shadow whose pinned header holds the 36x5 grabber and the
/// Ruby `header`.
class CupertinoDraggableScrollableSheetSurface extends StatelessWidget {
  final Control control;
  final ScrollController scrollController;
  final Widget? header;
  final Widget list;

  const CupertinoDraggableScrollableSheetSurface({
    super.key,
    required this.control,
    required this.scrollController,
    required this.header,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    final color = control.getColor("bgcolor", context,
        CupertinoColors.systemBackground.resolveFrom(context))!;
    final radius = control.getBorderRadius("border_radius",
        const BorderRadius.vertical(top: Radius.circular(12)))!;
    final showHandle = control.getBool("show_drag_handle", true)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 12),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
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
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey3
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                              child: const SizedBox(width: 36, height: 5),
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
      ),
    );
  }
}
