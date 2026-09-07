import 'package:flutter/material.dart';

import 'animated_transition_page.dart';

class MaterialAnimatedTransitionRoute<T> extends PageRoute<T> {
  MaterialAnimatedTransitionRoute(AnimatedTransitionPage<T> page)
      : super(settings: page, fullscreenDialog: page.fullscreenDialog);

  AnimatedTransitionPage<T> get _page => settings as AnimatedTransitionPage<T>;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => _page.duration;

  @override
  Duration get reverseTransitionDuration => _page.duration;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      Semantics(
          scopesRoute: true, explicitChildNodes: true, child: _page.child);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (_page.duration == Duration.zero) return child;
    if (_page.fadeTransition) {
      return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeIn)),
          child: child);
    }
    return Theme.of(context).pageTransitionsTheme.buildTransitions<T>(
        this, context, animation, secondaryAnimation, child);
  }
}
