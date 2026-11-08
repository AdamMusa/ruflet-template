import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';

/// The `animation_end` payload of an explicit transition. LayoutControl's
/// implicit animations report what they animated ("opacity", "rotation",
/// ...); a transition on the same control reports this instead.
const transitionEndEventData = "transition";

/// Builds the Flutter transition (FadeTransition, RotationTransition, ...)
/// for the value an [ExplicitTransition] currently shows.
typedef ExplicitTransitionBuilder<T> = Widget Function(
    BuildContext context, Animation<T> animation, Widget? child);

/// Drives one explicit transition of a Ruby control with an
/// [AnimationController], so a loop costs Ruby nothing per frame.
///
/// The control's `begin` and `end` arrive parsed ([begin], [end]); the
/// timing comes from the control: `duration` (ms, default 1000), `curve`,
/// `repeat`, `reverse` (ping-pong while repeating), `animating` (false
/// pauses, default true) and `delay` (ms before the first run).
///
/// A Ruby patch takes effect without a jump where it can:
/// - a new `end` retargets a single run: it animates from the value shown
///   now to the new end; a new `begin` alone replays from it;
/// - a loop keeps its phase and continues between the new values;
/// - `duration` and `curve` apply to the rest of the run, `animating`
///   pauses or resumes where it is, `repeat` off finishes at `end`.
///
/// `on_animation_end` fires once per completed single run, never for a
/// loop. With `MediaQuery.disableAnimations` every run that would start
/// shows its end state at once (and reports its end) and loops do not run.
/// The controller and the delay timer go with the widget.
class ExplicitTransition<T extends Object> extends StatefulWidget {
  const ExplicitTransition({
    super.key,
    required this.control,
    required this.begin,
    required this.end,
    required this.builder,
    this.child,
  });

  final Control control;
  final T begin;
  final T end;
  final ExplicitTransitionBuilder<T> builder;
  final Widget? child;

  @override
  State<ExplicitTransition<T>> createState() => _ExplicitTransitionState<T>();
}

/// What a patch can change, read from the control on every build.
class _Timing<T extends Object> {
  _Timing(ExplicitTransition<T> widget)
      : begin = widget.begin,
        end = widget.end,
        duration = _nonNegative(widget.control
            .getDuration("duration", const Duration(milliseconds: 1000))!),
        delay =
            _nonNegative(widget.control.getDuration("delay", Duration.zero)!),
        curve = widget.control.getCurve("curve", Curves.linear)!,
        repeat = widget.control.getBool("repeat", false)!,
        reverse = widget.control.getBool("reverse", false)!,
        animating = widget.control.getBool("animating", true)!;

  final T begin;
  final T end;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final bool repeat;
  final bool reverse;
  final bool animating;

  /// A loop needs a period: a zero-length one shows its end state.
  bool get loops => repeat && duration > Duration.zero;
}

Duration _nonNegative(Duration value) =>
    value.isNegative ? Duration.zero : value;

class _ExplicitTransitionState<T extends Object>
    extends State<ExplicitTransition<T>> with SingleTickerProviderStateMixin {
  late _Timing<T> _timing;
  late final AnimationController _controller;
  late final CurvedAnimation _curved;

  /// The values the controller runs between: Ruby's begin and end, or the
  /// value shown when a new end arrived and that end.
  late Animation<T> _animation;

  bool _started = false;
  bool _disableAnimations = false;

  /// The first run still waits for `delay`.
  bool _delayPending = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _timing = _Timing(widget);
    _controller = AnimationController(vsync: this, duration: _timing.duration)
      ..addStatusListener(_onStatus);
    _curved = CurvedAnimation(parent: _controller, curve: _timing.curve);
    _setRange(_timing.begin, _timing.end);
    _delayPending = _timing.delay > Duration.zero;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started || disable != _disableAnimations) {
      _started = true;
      _disableAnimations = disable;
      _play();
    }
  }

  @override
  void didUpdateWidget(ExplicitTransition<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The Control is one mutable model: compare with what was last applied,
    // not with the old widget.
    final previous = _timing;
    final next = _Timing(widget);
    _timing = next;

    if (next.duration != previous.duration) {
      _controller.duration = next.duration;
    }
    if (next.curve != previous.curve) _curved.curve = next.curve;

    final endChanged = next.end != previous.end;
    if (endChanged || next.begin != previous.begin) {
      if (next.repeat) {
        // A loop keeps its phase between the new values.
        _setRange(next.begin, next.end);
      } else if (endChanged) {
        // Retarget a single run from what is shown now.
        _setRange(_animation.value, next.end);
        _controller.value = 0;
      } else {
        // A new begin alone replays the run from it.
        _setRange(next.begin, next.end);
        _controller.value = 0;
      }
      _play();
    } else if (next.repeat != previous.repeat ||
        next.reverse != previous.reverse ||
        next.animating != previous.animating ||
        next.duration != previous.duration) {
      if (next.repeat && !previous.repeat) {
        _setRange(next.begin, next.end);
      }
      _play();
    }
  }

  void _setRange(T from, T to) {
    _animation = _curved.drive(Tween<T>(begin: from, end: to));
  }

  /// Runs, loops, pauses or settles the controller for the current timing.
  void _play() {
    if (!_timing.animating) {
      _cancelDelay();
      _controller.stop();
      return;
    }
    if (_disableAnimations || (_timing.repeat && !_timing.loops)) {
      // Reduced motion (or a loop with no length): the end state, no loop.
      _cancelDelay();
      _delayPending = false;
      _controller.value = 1;
      return;
    }
    if (_delayTimer != null) return;
    if (_delayPending) {
      _delayPending = false;
      _delayTimer = Timer(_timing.delay, () {
        _delayTimer = null;
        if (mounted) _play();
      });
      return;
    }
    if (_timing.repeat) {
      _controller.repeat(reverse: _timing.reverse);
    } else if (_controller.value < 1) {
      _controller.forward();
    }
  }

  void _cancelDelay() {
    _delayTimer?.cancel();
    _delayTimer = null;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_timing.repeat) {
      widget.control.triggerEvent("animation_end", transitionEndEventData);
    }
  }

  @override
  void dispose() {
    _cancelDelay();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _animation, widget.child);
}

/// A transition value from Ruby: a number, else [defaultValue].
double transitionNumber(Control control, String name, double defaultValue) {
  final value = parseDouble(control.get(name));
  return value == null || !value.isFinite ? defaultValue : value;
}
