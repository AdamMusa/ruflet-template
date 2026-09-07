import 'package:flutter/cupertino.dart';

import 'animated_transition_page.dart';

/// A native route retains interactive back navigation and modal transitions.
class CupertinoAnimatedTransitionRoute<T> extends CupertinoPageRoute<T> {
  CupertinoAnimatedTransitionRoute(AnimatedTransitionPage<T> page)
      : super(
            builder: (_) => page.child,
            settings: page,
            fullscreenDialog: page.fullscreenDialog);

  AnimatedTransitionPage<T> get _page => settings as AnimatedTransitionPage<T>;

  @override
  Duration get transitionDuration => _page.duration;

  @override
  Duration get reverseTransitionDuration => _page.duration;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (_page.duration == Duration.zero) return child;
    if (_page.fadeTransition) {
      return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeIn)),
          child: child);
    }
    return super
        .buildTransitions(context, animation, secondaryAnimation, child);
  }
}
