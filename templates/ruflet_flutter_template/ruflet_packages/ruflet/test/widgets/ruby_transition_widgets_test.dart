// Ruby's fade_transition, rotation_transition, scale_transition,
// slide_transition and size_transition (explicit, optionally repeating
// animations the engine drives without a patch per frame), clip_oval and
// clip_rsuperellipse, on both designs.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

const _box = {
  '_c': 'Container',
  '_i': 90,
  'key': 'box',
  'width': 100,
  'height': 50,
  'bgcolor': '#336699',
};

/// A transition keyed [key] over a 100x50 box, subscribed to
/// on_animation_end, with a one-second linear run unless [props] says
/// otherwise.
Map<String, dynamic> _transition(String type,
        {int id = 2,
        String key = 't',
        Map<String, dynamic> props = const {},
        Map<String, dynamic> content = _box}) =>
    {
      '_c': type,
      '_i': id,
      'key': key,
      'duration': 1000,
      'on_animation_end': true,
      'content': {...content, '_i': id + 100},
      ...props,
    };

Map<String, dynamic> _column(List<Map<String, dynamic>> controls) =>
    {'_c': 'Column', '_i': 1, 'controls': controls};

Map<String, dynamic> _one(String type,
        [Map<String, dynamic> props = const {}]) =>
    _column([_transition(type, props: props)]);

/// The Flutter transition [T] inside the Ruby control keyed [key].
T _widget<T extends Widget>(WidgetTester tester, [String key = 't']) =>
    tester.widget<T>(find
        .descendant(
            of: find.byKey(ValueKey<Object>(key)).first,
            matching: find.byType(T))
        .first);

double _opacity(WidgetTester tester, [String key = 't']) =>
    _widget<FadeTransition>(tester, key).opacity.value;
double _turns(WidgetTester tester) =>
    _widget<RotationTransition>(tester).turns.value;
double _scale(WidgetTester tester, [String key = 't']) =>
    _widget<ScaleTransition>(tester, key).scale.value;
Offset _position(WidgetTester tester) =>
    _widget<SlideTransition>(tester).position.value;
double _sizeFactor(WidgetTester tester) =>
    _widget<SizeTransition>(tester).sizeFactor.value;

Rect _boxRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey<Object>('box')).last);

/// The `animation_end` payloads sent to Ruby, in order.
List<Object?> _ends(HarnessMount mount) => [
      for (final m in mount.backend.sent)
        if (m.props == null && m.name == 'animation_end') m.data,
    ];

/// Applies a Ruby `page.update(control, **props)` patch as it arrives.
Future<void> _patch(
    WidgetTester tester, HarnessMount mount, Map<String, dynamic> props,
    {int id = 2}) async {
  mount.control(id).applyPatch([
    [0],
    for (final entry in props.entries) [0, 0, entry.key, entry.value],
  ], mount.backend);
  await tester.pump();
}

Future<void> _wait(WidgetTester tester, int milliseconds) =>
    tester.pump(Duration(milliseconds: milliseconds));

void main() {
  for (final design in HarnessDesign.values) {
    final name = design.name;

    group('$name explicit transitions', () {
      testWidgets('a fade runs from begin to end once and reports it once',
          (tester) async {
        final mount = await mountWire(tester, design, _one('FadeTransition'),
            settle: false);
        expect(tester.takeException(), isNull);
        expect(_opacity(tester), 0.0);
        await _wait(tester, 500);
        expect(_opacity(tester), closeTo(0.5, 0.001));
        expect(_ends(mount), isEmpty);
        await _wait(tester, 500);
        expect(_opacity(tester), 1.0);
        await tester.pumpAndSettle();
        expect(_ends(mount), ['transition']);
      });

      testWidgets('rotation, scale, slide and size show begin, middle and end',
          (tester) async {
        Future<List<Object>> sample(String type, Map<String, dynamic> props,
            Object Function() read) async {
          await mountWire(tester, design, _one(type, props), settle: false);
          final values = [read()];
          await _wait(tester, 500);
          values.add(read());
          await _wait(tester, 500);
          values.add(read());
          return values;
        }

        expect(await sample('RotationTransition', {}, () => _turns(tester)),
            [0.0, 0.5, 1.0]);
        expect(
            await sample('ScaleTransition', {'begin': 0.5, 'end': 1.5},
                () => _scale(tester)),
            [0.5, 1.0, 1.5]);
        expect(
            await sample(
                'SlideTransition',
                {
                  'begin': {'x': -1, 'y': 0},
                  'end': {'x': 0, 'y': 0},
                },
                () => _position(tester)),
            [const Offset(-1, 0), const Offset(-0.5, 0), Offset.zero]);
        expect(await sample('SizeTransition', {}, () => _sizeFactor(tester)),
            [0.0, 0.5, 1.0]);
      });

      testWidgets('slide moves and size clips the content geometry',
          (tester) async {
        await mountWire(
            tester,
            design,
            _one('SlideTransition', {
              'begin': {'x': -1, 'y': 0.5},
              'end': {'x': 0, 'y': 0},
            }),
            settle: false);
        await _wait(tester, 500);
        final middle = _boxRect(tester);
        await tester.pumpAndSettle();
        final end = _boxRect(tester);
        // Half way: half of (-1, 0.5) of a 100x50 box.
        expect(middle.topLeft - end.topLeft, const Offset(-50, 12.5));

        await mountWire(tester, design, _one('SizeTransition'), settle: false);
        Size clip() => tester.getSize(find
            .descendant(
                of: find.byKey(const ValueKey<Object>('t')).first,
                matching: find.byType(ClipRect))
            .first);
        expect(clip().height, 0);
        await _wait(tester, 500);
        expect(clip().height, 25);
        await tester.pumpAndSettle();
        expect(clip().height, 50);

        await mountWire(tester, design,
            _one('SizeTransition', {'axis': 'horizontal', 'end': 0.5}),
            settle: false);
        await tester.pumpAndSettle();
        expect(clip().width, 50);
      });

      testWidgets('repeat with reverse ping-pongs and never reports an end',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _one('ScaleTransition',
                {'begin': 1, 'end': 2, 'repeat': true, 'reverse': true}),
            settle: false);
        final samples = [_scale(tester)];
        for (var i = 0; i < 5; i++) {
          await _wait(tester, 500);
          samples.add(_scale(tester));
        }
        expect(samples, [1.0, 1.5, 2.0, 1.5, 1.0, 1.5]);
        await _wait(tester, 5000);
        expect(tester.hasRunningAnimations, isTrue);
        expect(_ends(mount), isEmpty);
      });

      testWidgets('repeat without reverse restarts from begin', (tester) async {
        await mountWire(
            tester, design, _one('RotationTransition', {'repeat': true}),
            settle: false);
        await _wait(tester, 250);
        expect(_turns(tester), closeTo(0.25, 0.001));
        await _wait(tester, 1000);
        expect(_turns(tester), closeTo(0.25, 0.001));
        await _wait(tester, 700);
        expect(_turns(tester), closeTo(0.95, 0.001));
      });

      testWidgets('delay waits before the first run', (tester) async {
        await mountWire(tester, design, _one('FadeTransition', {'delay': 300}),
            settle: false);
        await _wait(tester, 299);
        expect(_opacity(tester), 0.0);
        await _wait(tester, 1);
        await _wait(tester, 500);
        expect(_opacity(tester), closeTo(0.5, 0.001));
      });

      testWidgets('a curve shapes the run', (tester) async {
        await mountWire(
            tester, design, _one('FadeTransition', {'curve': 'ease_in'}),
            settle: false);
        await _wait(tester, 500);
        expect(_opacity(tester), closeTo(Curves.easeIn.transform(0.5), 0.001));
      });
    });

    group('$name transition patches', () {
      testWidgets('animating false pauses where it is and true resumes',
          (tester) async {
        final mount = await mountWire(tester, design, _one('FadeTransition'),
            settle: false);
        await _wait(tester, 500);
        await _patch(tester, mount, {'animating': false});
        await _wait(tester, 2000);
        expect(_opacity(tester), closeTo(0.5, 0.001));
        expect(tester.hasRunningAnimations, isFalse);
        expect(_ends(mount), isEmpty);

        await _patch(tester, mount, {'animating': true});
        await _wait(tester, 250);
        expect(_opacity(tester), closeTo(0.75, 0.001));
        await tester.pumpAndSettle();
        expect(_opacity(tester), 1.0);
        expect(_ends(mount), ['transition']);
      });

      testWidgets('a transition mounted paused shows begin and stays',
          (tester) async {
        await mountWire(tester, design,
            _one('RotationTransition', {'repeat': true, 'animating': false}));
        expect(_turns(tester), 0.0);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('a new end retargets from the value shown, without a jump',
          (tester) async {
        final mount = await mountWire(tester, design, _one('FadeTransition'),
            settle: false);
        await _wait(tester, 500);
        await _patch(tester, mount, {'end': 0.0});
        expect(_opacity(tester), closeTo(0.5, 0.001));
        await _wait(tester, 500);
        expect(_opacity(tester), closeTo(0.25, 0.001));
        await _wait(tester, 500);
        expect(_opacity(tester), 0.0);
        await tester.pumpAndSettle();
        // The first run never finished: one end, for the retargeted run.
        expect(_ends(mount), ['transition']);
      });

      testWidgets('a new begin alone replays the run', (tester) async {
        final mount = await mountWire(tester, design, _one('FadeTransition'));
        expect(_opacity(tester), 1.0);
        expect(_ends(mount), ['transition']);
        await _patch(tester, mount, {'begin': 0.5});
        expect(_opacity(tester), 0.5);
        await _wait(tester, 500);
        expect(_opacity(tester), closeTo(0.75, 0.001));
        await tester.pumpAndSettle();
        expect(_ends(mount), ['transition', 'transition']);
      });

      testWidgets('a new duration applies to the rest of the run',
          (tester) async {
        final mount = await mountWire(tester, design, _one('FadeTransition'),
            settle: false);
        await _wait(tester, 500);
        await _patch(tester, mount, {'duration': 2000});
        // The remaining half now takes half of two seconds.
        await _wait(tester, 500);
        expect(_opacity(tester), closeTo(0.75, 0.001));
      });

      testWidgets('a loop keeps its phase when its values change',
          (tester) async {
        final mount = await mountWire(tester, design,
            _one('ScaleTransition', {'begin': 1, 'end': 2, 'repeat': true}),
            settle: false);
        await _wait(tester, 250);
        expect(_scale(tester), closeTo(1.25, 0.001));
        await _patch(tester, mount, {'end': 3});
        expect(_scale(tester), closeTo(1.5, 0.001));
        await _wait(tester, 250);
        expect(_scale(tester), closeTo(2.0, 0.001));
      });

      testWidgets('repeat off finishes at end and reports it', (tester) async {
        final mount = await mountWire(tester, design,
            _one('ScaleTransition', {'begin': 1, 'end': 2, 'repeat': true}),
            settle: false);
        await _wait(tester, 250);
        await _patch(tester, mount, {'repeat': false});
        await _wait(tester, 750);
        expect(_scale(tester), 2.0);
        await tester.pumpAndSettle();
        expect(_ends(mount), ['transition']);
      });

      testWidgets('removing a transition stops its loop and its delay',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _column([
              _transition('RotationTransition', props: {'repeat': true}),
              _transition('FadeTransition',
                  id: 4, key: 'late', props: {'delay': 5000}),
            ]),
            settle: false);
        await _wait(tester, 100);
        expect(tester.hasRunningAnimations, isTrue);

        await _patch(tester, mount, {'controls': []}, id: 1);
        expect(find.byKey(const ValueKey<Object>('t')), findsNothing);
        expect(find.byKey(const ValueKey<Object>('late')), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        // The test binding fails the test if the delay timer is left behind.
      });
    });

    group('$name transitions with animations disabled', () {
      void disableAnimations(WidgetTester tester, bool disable) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: disable);
      }

      testWidgets('show their end state at once and do not loop',
          (tester) async {
        disableAnimations(tester, true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        // Settling would time out if the loop ran.
        final mount = await mountWire(
            tester,
            design,
            _column([
              _transition('ScaleTransition', props: {
                'begin': 1,
                'end': 2,
                'repeat': true,
                'reverse': true,
              }),
              _transition('FadeTransition',
                  id: 4, key: 'fade', props: {'delay': 400}),
            ]));
        expect(_scale(tester), 2.0);
        expect(_opacity(tester, 'fade'), 1.0);
        expect(tester.hasRunningAnimations, isFalse);
        // The single run finished (at once); the loop never reports.
        expect(_ends(mount), ['transition']);
      });

      testWidgets('turning them off mid-loop settles it, back on resumes it',
          (tester) async {
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await mountWire(tester, design,
            _one('ScaleTransition', {'begin': 1, 'end': 2, 'repeat': true}),
            settle: false);
        await _wait(tester, 250);
        expect(_scale(tester), closeTo(1.25, 0.001));

        disableAnimations(tester, true);
        await tester.pump();
        expect(_scale(tester), 2.0);
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);

        disableAnimations(tester, false);
        await tester.pump();
        expect(tester.hasRunningAnimations, isTrue);
      });

      testWidgets('a paused transition stays paused', (tester) async {
        disableAnimations(tester, true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final mount = await mountWire(
            tester, design, _one('FadeTransition', {'animating': false}));
        expect(_opacity(tester), 0.0);
        await _patch(tester, mount, {'animating': true});
        expect(_opacity(tester), 1.0);
        expect(_ends(mount), ['transition']);
      });
    });

    group('$name zero-length transitions', () {
      testWidgets('a single run completes at once and a loop does not run',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _column([
              _transition('FadeTransition', props: {'duration': 0}),
              _transition('RotationTransition',
                  id: 4,
                  key: 'spin',
                  props: {'duration': 0, 'repeat': true, 'end': 0.25}),
            ]));
        expect(_opacity(tester), 1.0);
        expect(_widget<RotationTransition>(tester, 'spin').turns.value, 0.25);
        expect(tester.hasRunningAnimations, isFalse);
        expect(_ends(mount), ['transition']);
      });
    });

    group('$name clips', () {
      Map<String, dynamic> clip(String type,
              [Map<String, dynamic> props = const {}]) =>
          _column([
            {
              '_c': type,
              '_i': 2,
              'content': {..._box, '_i': 3},
              ...props,
            }
          ]);

      testWidgets('ClipOval clips its content to the oval of its box',
          (tester) async {
        final mount = await mountWire(tester, design, clip('ClipOval'));
        expect(tester.takeException(), isNull);
        final oval = tester.renderObject<RenderClipOval>(find.byType(ClipOval));
        expect(oval.size, const Size(100, 50));
        expect(oval.clipBehavior, Clip.antiAlias);
        // A corner of the box lies outside the oval; its centre and the
        // middle of each edge inside.
        bool hits(Offset position) =>
            oval.hitTest(BoxHitTestResult(), position: position);
        expect(hits(const Offset(3, 3)), isFalse);
        expect(hits(const Offset(97, 47)), isFalse);
        expect(hits(const Offset(50, 25)), isTrue);
        expect(hits(const Offset(2, 25)), isTrue);
        expect(hits(const Offset(50, 1)), isTrue);

        await _patch(tester, mount, {'clip_behavior': 'hard_edge'});
        expect(
            tester
                .renderObject<RenderClipOval>(find.byType(ClipOval))
                .clipBehavior,
            Clip.hardEdge);
      });

      testWidgets('ClipRSuperellipse clips to continuous corners',
          (tester) async {
        await mountWire(
            tester, design, clip('ClipRSuperellipse', {'border_radius': 20}));
        expect(tester.takeException(), isNull);
        final squircle = tester.renderObject<RenderClipRSuperellipse>(
            find.byType(ClipRSuperellipse));
        expect(squircle.size, const Size(100, 50));
        expect(squircle.borderRadius, BorderRadius.circular(20));
        expect(squircle.clipBehavior, Clip.antiAlias);
        // It paints its content through the superellipse of its box.
        expect(
            squircle,
            paints
              ..clipRSuperellipse(
                  rsuperellipse: RSuperellipse.fromRectAndRadius(
                      const Rect.fromLTWH(0, 0, 100, 50),
                      const Radius.circular(20))));

        await mountWire(
            tester,
            design,
            clip('ClipRSuperellipse', {
              'border_radius': {'top_left': 12, 'bottom_right': 4},
              'clip_behavior': 'anti_alias_with_save_layer',
            }));
        final corners = tester.renderObject<RenderClipRSuperellipse>(
            find.byType(ClipRSuperellipse));
        expect(
            corners.borderRadius,
            const BorderRadius.only(
                topLeft: Radius.circular(12), bottomRight: Radius.circular(4)));
        expect(corners.clipBehavior, Clip.antiAliasWithSaveLayer);
      });
    });
  }
}
