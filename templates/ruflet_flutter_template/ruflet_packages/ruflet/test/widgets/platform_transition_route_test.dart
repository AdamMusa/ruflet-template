import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/animated_transition_page.dart';
import 'package:ruflet/src/widgets/cupertino_transition_route.dart';
import 'package:ruflet/src/widgets/material_transition_route.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

class _Transitions extends material.PageTransitionsBuilder {
  const _Transitions();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      KeyedSubtree(key: const Key('material-transitions'), child: child);
}

Widget app(PageDesign design, Widget home) => PageContext(
      themeMode: null,
      brightness: null,
      widgetsDesign: design,
      child: design == PageDesign.cupertino
          ? CupertinoApp(home: home)
          : material.MaterialApp(
              theme: material.ThemeData(
                pageTransitionsTheme:
                    const material.PageTransitionsTheme(builders: {
                  TargetPlatform.android: _Transitions(),
                }),
              ),
              home: home),
    );

void main() {
  for (final design in PageDesign.values) {
    testWidgets('$design page settings, duration and updated child stay intact',
        (tester) async {
      var detail = false;
      var title = 'Detail';
      late StateSetter update;
      final key = GlobalKey<NavigatorState>();
      await tester
          .pumpWidget(app(design, StatefulBuilder(builder: (context, setState) {
        update = setState;
        return Navigator(
            key: key,
            pages: [
              const AnimatedTransitionPage<void>(
                  key: ValueKey('home'),
                  duration: Duration.zero,
                  child: SizedBox.expand()),
              if (detail)
                AnimatedTransitionPage<void>(
                    key: const ValueKey('detail'),
                    name: '/detail',
                    arguments: const {'id': 42},
                    restorationId: 'detail',
                    duration: const Duration(milliseconds: 180),
                    child: SizedBox.expand(child: Center(child: Text(title)))),
            ],
            onDidRemovePage: (_) => update(() => detail = false));
      })));
      update(() => detail = true);
      await tester.pump();
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text('Detail')))!
          as PageRoute<void>;
      expect(route.settings.name, '/detail');
      expect(route.settings.arguments, {'id': 42});
      expect((route.settings as Page).restorationId, 'detail');
      expect(route.transitionDuration, const Duration(milliseconds: 180));
      expect(
          route.reverseTransitionDuration, const Duration(milliseconds: 180));
      if (design == PageDesign.cupertino) {
        expect(route, isA<CupertinoPageRoute<void>>());
        expect(route, isA<CupertinoAnimatedTransitionRoute<void>>());
        expect(route.popGestureEnabled, isTrue);
        expect(find.byType(CupertinoPageTransition), findsWidgets);
        expect(find.byKey(const Key('material-transitions')), findsNothing);
      } else {
        expect(route, isA<MaterialAnimatedTransitionRoute<void>>());
        expect(find.byKey(const Key('material-transitions')), findsWidgets);
      }
      update(() => title = 'Updated detail');
      await tester.pumpAndSettle();
      expect(find.text('Updated detail'), findsOneWidget);
      expect(ModalRoute.of(tester.element(find.text('Updated detail'))),
          same(route));
      if (design == PageDesign.cupertino) {
        await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
      } else {
        key.currentState!.pop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Updated detail'), findsNothing);
    });

    testWidgets('$design fullscreen pages and explicit fade remain supported',
        (tester) async {
      late PageRoute<void> fullscreen;
      late PageRoute<void> fade;
      late PageRoute<void> instant;
      await tester.pumpWidget(app(design, Builder(builder: (context) {
        fullscreen = const AnimatedTransitionPage<void>(
                fullscreenDialog: true,
                duration: Duration(milliseconds: 240),
                child: Text('Fullscreen'))
            .createRoute(context) as PageRoute<void>;
        fade = const AnimatedTransitionPage<void>(
                fadeTransition: true,
                duration: Duration(milliseconds: 200),
                child: Text('Fade'))
            .createRoute(context) as PageRoute<void>;
        instant = const AnimatedTransitionPage<void>(
                duration: Duration.zero, child: Text('Instant'))
            .createRoute(context) as PageRoute<void>;
        expect(fullscreen.fullscreenDialog, isTrue);
        expect(
            fullscreen.transitionDuration, const Duration(milliseconds: 240));
        expect(
            fade.buildTransitions(context, const AlwaysStoppedAnimation(0.5),
                const AlwaysStoppedAnimation(0), const Text('Fade')),
            isA<FadeTransition>());
        const child = Text('Instant');
        expect(
            instant.buildTransitions(context, const AlwaysStoppedAnimation(1),
                const AlwaysStoppedAnimation(0), child),
            same(child));
        return const SizedBox();
      })));
      fullscreen.dispose();
      fade.dispose();
      instant.dispose();
    });
  }
}
