import 'package:flutter/widgets.dart';

import '../utils/misc.dart' show LabelPosition;
import '../widgets/list_tile_clicks.dart';
import 'control_core.dart';

/// The label composition shared by toggles (Switch, Checkbox, Radio) on
/// every design: one merged semantics node, one tap target that toggles, the
/// same row geometry, and a click cursor over an enabled label.
class ToggleLabel extends StatelessWidget {
  const ToggleLabel({
    super.key,
    required this.child,
    required this.label,
    this.position = LabelPosition.right,
    this.onToggle,
    this.spacing = 0,
    this.mainAxisSize = MainAxisSize.min,
  });

  /// The native toggle.
  final Widget child;

  /// The built label; without one the native toggle is returned unchanged.
  final Widget? label;
  final LabelPosition position;

  /// Null while disabled: the label then neither toggles nor shows a click
  /// cursor.
  final VoidCallback? onToggle;
  final double spacing;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    if (label == null) return child;
    final text = onToggle == null
        ? label
        : MouseRegion(cursor: SystemMouseCursors.click, child: label);
    return MergeSemantics(
      child: GestureDetector(
        onTap: onToggle,
        child: Row(
          mainAxisSize: mainAxisSize,
          spacing: spacing,
          children:
              position == LabelPosition.right ? [child, text] : [text, child],
        ),
      ),
    );
  }
}

/// A toggle that an enclosing `ListTile(toggle_inputs: true)` toggles when the
/// tile is tapped. Subscribes once per core (not once per skin) and ignores
/// taps while the toggle is disabled.
mixin TileToggleCore<P extends Object> on ControlCore<P> {
  Listenable? _tileClicks;

  /// The tile was tapped and the toggle is enabled.
  @protected
  void onTileClick();

  @override
  void didChangeDependencies(BuildContext context) {
    final next = ListTileClicks.of(context)?.notifier;
    if (!identical(next, _tileClicks)) {
      _tileClicks?.removeListener(_tileTapped);
      _tileClicks = next?..addListener(_tileTapped);
    }
    super.didChangeDependencies(context);
  }

  void _tileTapped() {
    if (enabled) onTileClick();
  }

  @override
  void disposeCore() {
    _tileClicks?.removeListener(_tileTapped);
    _tileClicks = null;
    super.disposeCore();
  }
}
