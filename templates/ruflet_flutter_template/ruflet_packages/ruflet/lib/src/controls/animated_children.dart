import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/enums.dart';
import '../utils/layout.dart';
import '../utils/time.dart';
import 'control_widget.dart';

/// Transition types of the Ruby `item_animation` map.
enum ItemAnimationType { fade, size, fadeSize, slide }

/// Ruby `item_animation` (with `animate_changes: true`), e.g.
/// `{type: "fade_size", duration: 250, curve: "easeInOut"}`.
class ItemAnimation {
  static const defaultDuration = Duration(milliseconds: 250);

  final ItemAnimationType type;
  final Duration duration;
  final Curve curve;

  const ItemAnimation({
    this.type = ItemAnimationType.fadeSize,
    this.duration = defaultDuration,
    this.curve = Curves.easeInOut,
  });

  factory ItemAnimation.of(Control control) {
    final value = control.get("item_animation");
    if (value is! Map) return const ItemAnimation();
    return ItemAnimation(
      type: parseEnum(
          ItemAnimationType.values,
          value["type"]?.toString().replaceAll("_", ""),
          ItemAnimationType.fadeSize)!,
      duration: parseDuration(value["duration"], defaultDuration)!,
      curve: parseCurve(value["curve"]?.toString(), Curves.easeInOut)!,
    );
  }
}

/// A child of an animated host: its current [Control] and the animation that
/// runs 0 → 1 when it is inserted and 1 → 0 when it is removed.
class AnimatedChildEntry {
  Control control;
  final AnimationController controller;
  final CurvedAnimation animation;
  final ItemAnimationType type;
  bool removing = false;

  AnimatedChildEntry._(this.control, this.controller, Curve curve, this.type)
      : animation = CurvedAnimation(parent: controller, curve: curve);

  int get id => control.id;

  /// Wraps [child] in this entry's transition along the host's main [axis].
  Widget transition(Axis axis, Widget child) {
    final key = ValueKey(id);
    switch (type) {
      case ItemAnimationType.fade:
        return FadeTransition(key: key, opacity: animation, child: child);
      case ItemAnimationType.size:
        return SizeTransition(
            key: key, sizeFactor: animation, axis: axis, child: child);
      case ItemAnimationType.fadeSize:
        return SizeTransition(
            key: key,
            sizeFactor: animation,
            axis: axis,
            child: FadeTransition(opacity: animation, child: child));
      case ItemAnimationType.slide:
        return SlideTransition(
            key: key,
            position: Tween<Offset>(
                    begin: axis == Axis.vertical
                        ? const Offset(1, 0)
                        : const Offset(0, 1),
                    end: Offset.zero)
                .animate(animation),
            child: child);
    }
  }

  void _dispose() {
    animation.dispose();
    controller.dispose();
  }
}

/// AnimatedList behavior for a host that rebuilds its children from Ruby
/// patches (ListView, Column).
///
/// [sync] diffs the new child list against the previous one by control id:
/// new ids animate in, missing ids stay in place and animate out before they
/// are dropped (the host is rebuilt through [onChanged]), and a reorder of the
/// same ids just rebuilds. The first [sync] does not animate.
class AnimatedChildren {
  final TickerProvider vsync;
  final VoidCallback onChanged;
  List<AnimatedChildEntry> _entries = [];
  bool _initialized = false;
  bool _disposed = false;

  AnimatedChildren({required this.vsync, required this.onChanged});

  List<AnimatedChildEntry> get entries => _entries;

  AnimatedChildEntry _entry(
      Control control, ItemAnimation animation, double value) {
    return AnimatedChildEntry._(
        control,
        AnimationController(
            vsync: vsync, duration: animation.duration, value: value),
        animation.curve,
        animation.type);
  }

  List<AnimatedChildEntry> sync(List<Control> next, ItemAnimation animation) {
    if (!_initialized) {
      _initialized = true;
      _entries = [for (final c in next) _entry(c, animation, 1.0)];
      return _entries;
    }

    final nextIds = {for (final c in next) c.id};
    final present = <int, AnimatedChildEntry>{};
    final leaving = <int, AnimatedChildEntry>{};
    for (final entry in _entries) {
      (entry.removing ? leaving : present)[entry.id] = entry;
    }

    for (final entry in _entries) {
      if (entry.removing || nextIds.contains(entry.id)) continue;
      entry.removing = true;
      entry.controller.duration = animation.duration;
      entry.controller.reverse().whenComplete(() => _drop(entry));
    }

    final result = <AnimatedChildEntry>[];
    for (final control in next) {
      var entry = present[control.id];
      if (entry == null) {
        final returning = leaving[control.id];
        if (returning != null) {
          // Re-added while animating out: animate back in from where it is.
          returning.removing = false;
          returning.controller.forward();
          entry = returning;
        } else {
          entry = _entry(control, animation, 0.0)..controller.forward();
        }
      }
      entry.control = control;
      result.add(entry);
    }

    // Keep leaving children where they were, after their old predecessor.
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (!entry.removing || result.contains(entry)) continue;
      var insertAt = 0;
      for (var j = i - 1; j >= 0; j--) {
        final index = result.indexOf(_entries[j]);
        if (index >= 0) {
          insertAt = index + 1;
          break;
        }
      }
      result.insert(insertAt, entry);
    }

    _entries = result;
    return _entries;
  }

  void _drop(AnimatedChildEntry entry) {
    if (_disposed || !entry.removing) return;
    _entries = [..._entries]..remove(entry);
    entry._dispose();
    onChanged();
  }

  void dispose() {
    _disposed = true;
    for (final entry in _entries) {
      entry._dispose();
    }
    _entries = [];
  }
}

/// Builds a flex host (Column) whose Ruby children animate in and out.
/// `expand` children are passed through unwrapped, because their `Expanded`
/// must stay a direct child of the flex.
class AnimatedChildrenBuilder extends StatefulWidget {
  final Control control;
  final Axis axis;
  final Widget Function(List<Widget> children) builder;

  const AnimatedChildrenBuilder(
      {super.key,
      required this.control,
      required this.axis,
      required this.builder});

  @override
  State<AnimatedChildrenBuilder> createState() =>
      _AnimatedChildrenBuilderState();
}

class _AnimatedChildrenBuilderState extends State<AnimatedChildrenBuilder>
    with TickerProviderStateMixin {
  late final AnimatedChildren _animated = AnimatedChildren(
      vsync: this,
      onChanged: () {
        if (mounted) setState(() {});
      });

  @override
  void dispose() {
    _animated.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _animated.sync(
        widget.control.children("controls"), ItemAnimation.of(widget.control));
    return widget.builder([
      for (final entry in entries)
        (entry.control.getExpand("expand") ?? 0) > 0
            ? ControlWidget(key: ValueKey(entry.id), control: entry.control)
            : entry.transition(widget.axis,
                ControlWidget(key: ValueKey(entry.id), control: entry.control))
    ]);
  }
}
