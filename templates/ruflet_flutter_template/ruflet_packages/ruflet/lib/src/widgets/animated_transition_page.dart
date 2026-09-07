// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_transition_route.dart';
import 'material_transition_route.dart';
import 'platform_design.dart';

class AnimatedTransitionPage<T> extends Page<T> {
  final bool fadeTransition;
  final Widget child;
  final Duration duration;
  final bool fullscreenDialog;

  const AnimatedTransitionPage({
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    required this.child,
    this.fadeTransition = false,
    this.fullscreenDialog = false,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Route<T> createRoute(BuildContext context) =>
      switch (effectivePageDesign(context)) {
        PageDesign.cupertino => CupertinoAnimatedTransitionRoute<T>(this),
        PageDesign.material => MaterialAnimatedTransitionRoute<T>(this),
      };
}
