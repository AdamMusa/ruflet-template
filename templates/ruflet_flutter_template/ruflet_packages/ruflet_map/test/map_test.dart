// Map: the options Ruby's wire map configures, the events it subscribes to,
// and every camera method Ruby's MapControl invokes, on both designs.
//
// ruflet-coverage: Map
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_map/ruflet_map.dart';

import 'support/harness.dart';

const designs = [TargetPlatform.iOS, TargetPlatform.android];

/// A Map as Ruby's `Ruflet.map(layers, initial_center: [51.5, -0.09], ...)`
/// serializes it.
Map<String, dynamic> mapWire([Map<String, dynamic> props = const {}]) => {
      '_c': 'Map',
      '_i': 1,
      'width': 400,
      'height': 300,
      'initial_center': {'latitude': 51.5, 'longitude': -0.09},
      'initial_zoom': 13,
      'layers': <Object>[],
      ...props,
    };

Future<Mounted> mountMap(WidgetTester tester, TargetPlatform design,
        [Map<String, dynamic> props = const {}]) =>
    mountWire(tester, design, mapWire(props), extensions: [Extension()]);

FlutterMap flutterMap(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap));

MapCamera camera(WidgetTester tester) =>
    flutterMap(tester).mapController!.camera;

/// Invokes [name] the way the backend does for a Ruby `page.invoke`, running
/// the camera animation to its end.
Future<Object?> invoke(WidgetTester tester, Control control, String name,
    [Map<String, dynamic>? args]) async {
  Object? result;
  Object? error;
  var settled = false;
  unawaited(control.invokeMethod(name, args, const Duration(seconds: 5)).then(
      (value) {
    result = value;
    settled = true;
  }, onError: (Object e) {
    error = e;
    settled = true;
  }));
  await tester.pumpAndSettle();
  expect(settled, isTrue, reason: '$name did not settle');
  if (error != null) throw error!;
  return result;
}

void main() {
  for (final design in designs) {
    group('$design', () {
      testWidgets('options come from the wire map', (tester) async {
        await mountMap(tester, design, {
          'initial_rotation': 30,
          'min_zoom': 3,
          'max_zoom': 17.5,
          'keep_alive': true,
          'bgcolor': '#112233',
          'interaction_configuration': {
            'flags': InteractiveFlag.drag | InteractiveFlag.pinchZoom,
            'pinch_move_threshold': 25,
            'scroll_wheel_velocity': 0.01,
            'rotation_threshold': 15,
          },
        });

        final options = flutterMap(tester).options;
        expect(options.initialCenter, const LatLng(51.5, -0.09));
        expect(options.initialZoom, 13.0);
        expect(options.initialRotation, 30.0);
        expect(options.minZoom, 3.0);
        expect(options.maxZoom, 17.5);
        expect(options.keepAlive, isTrue);
        expect(options.backgroundColor, const Color(0xFF112233));
        final interaction = options.interactionOptions;
        expect(interaction.flags,
            InteractiveFlag.drag | InteractiveFlag.pinchZoom);
        expect(interaction.pinchMoveThreshold, 25.0);
        expect(interaction.scrollWheelVelocity, 0.01);
        expect(interaction.rotationThreshold, 15.0);

        final cam = camera(tester);
        expect(cam.center.latitude, closeTo(51.5, 1e-9));
        expect(cam.center.longitude, closeTo(-0.09, 1e-9));
        expect(cam.zoom, 13.0);
        expect(cam.rotation, 30.0);
        expect(tester.getSize(find.byType(FlutterMap)), const Size(400, 300));
      });

      testWidgets('interaction configuration keeps unset thresholds',
          (tester) async {
        // Ruby sends only the keys the app set; this used to throw a null
        // check on the missing pinch_move_threshold.
        await mountMap(tester, design, {
          'interaction_configuration': {'flags': InteractiveFlag.drag},
        });
        expect(tester.takeException(), isNull);
        final interaction = flutterMap(tester).options.interactionOptions;
        expect(interaction.flags, InteractiveFlag.drag);
        expect(interaction.pinchMoveThreshold, 40.0);
        expect(interaction.pinchZoomThreshold, 0.5);
        expect(interaction.rotationThreshold, 20.0);
        expect(interaction.scrollWheelVelocity, 0.005);
        expect(interaction.enableMultiFingerGestureRace, isFalse);
      });

      testWidgets('cursor rotation triggers on the keys Ruby names',
          (tester) async {
        await mountMap(tester, design, {
          'interaction_configuration': {
            'cursor_keyboard_rotation_configuration': {
              'trigger_keys': ['Shift Left', 'alt_right'],
              'behaviour': 'set_north',
              'set_north_on_click': false,
            },
          },
        });
        final rotation = flutterMap(tester)
            .options
            .interactionOptions
            .cursorKeyboardRotationOptions;
        expect(rotation.behaviour, CursorRotationBehaviour.setNorth);
        expect(rotation.setNorthOnClick, isFalse);
        final isTrigger = rotation.isKeyTrigger!;
        expect(isTrigger(LogicalKeyboardKey.shiftLeft), isTrue);
        expect(isTrigger(LogicalKeyboardKey.altRight), isTrue);
        expect(isTrigger(LogicalKeyboardKey.shiftRight), isFalse);
        expect(isTrigger(LogicalKeyboardKey.controlLeft), isFalse);
      });

      testWidgets('cursor rotation takes one key name as a list of one',
          (tester) async {
        // Ruby sends `trigger_keys: :control_left` as one name. This map used
        // to render; reading the name as a list must not stop it rendering.
        await mountMap(tester, design, {
          'interaction_configuration': {
            'pinch_move_threshold': 40,
            'cursor_keyboard_rotation_configuration': {
              'trigger_keys': 'control_left',
            },
          },
        });
        expect(tester.takeException(), isNull);
        expect(find.byType(FlutterMap), findsOneWidget);
        final isTrigger = flutterMap(tester)
            .options
            .interactionOptions
            .cursorKeyboardRotationOptions
            .isKeyTrigger!;
        expect(isTrigger(LogicalKeyboardKey.controlLeft), isTrue);
        expect(isTrigger(LogicalKeyboardKey.controlRight), isFalse);
        expect(isTrigger(LogicalKeyboardKey.shiftLeft), isFalse);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cursor rotation ignores trigger keys that name no key',
          (tester) async {
        for (final keys in <Object>[
          5,
          {'control_left': true}
        ]) {
          await mountMap(tester, design, {
            'interaction_configuration': {
              'cursor_keyboard_rotation_configuration': {'trigger_keys': keys},
            },
          });
          expect(tester.takeException(), isNull, reason: '$keys');
          expect(find.byType(FlutterMap), findsOneWidget, reason: '$keys');
          // As without trigger keys: flutter_map's Control default.
          expect(
              flutterMap(tester)
                  .options
                  .interactionOptions
                  .cursorKeyboardRotationOptions
                  .isKeyTrigger,
              isNull,
              reason: '$keys');
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          expect(tester.takeException(), isNull, reason: '$keys');
        }
      });

      testWidgets('cursor rotation without trigger keys uses Control',
          (tester) async {
        await mountMap(tester, design, {
          'interaction_configuration': {
            'cursor_keyboard_rotation_configuration': {
              'set_north_on_click': true
            },
          },
        });
        final rotation = flutterMap(tester)
            .options
            .interactionOptions
            .cursorKeyboardRotationOptions;
        // flutter_map's default trigger: any Control key.
        expect(rotation.isKeyTrigger, isNull);
        expect(rotation.behaviour, CursorRotationBehaviour.offset);
        expect(CursorKeyboardRotationOptions.defaultTriggerKeys,
            contains(LogicalKeyboardKey.controlLeft));
      });

      testWidgets('defaults when Ruby sends only the center', (tester) async {
        await mountMap(tester, design);
        final options = flutterMap(tester).options;
        expect(options.initialZoom, 13.0);
        expect(options.initialRotation, 0.0);
        expect(options.minZoom, isNull);
        expect(options.maxZoom, isNull);
        expect(options.interactionOptions.flags, InteractiveFlag.all);
        expect(options.onTap, isNull);
        expect(options.onPositionChanged, isNull);
        expect(options.onMapEvent, isNull);
      });

      testWidgets('initial camera fit frames the coordinates', (tester) async {
        await mountMap(tester, design, {
          'initial_camera_fit': {
            'bounds': {
              'corner_1': {'latitude': 10, 'longitude': 10},
              'corner_2': {'latitude': 20, 'longitude': 20},
            },
            'max_zoom': 8,
          },
        });
        final fit = flutterMap(tester).options.initialCameraFit;
        expect(fit, isA<FitInsideBounds>());
        expect((fit as FitInsideBounds).bounds,
            LatLngBounds(const LatLng(10, 10), const LatLng(20, 20)));
        expect(fit.maxZoom, 8.0);
        final center = camera(tester).center;
        expect(center.latitude, closeTo(15, 0.5));
        expect(center.longitude, closeTo(15, 1e-6));
      });

      testWidgets('taps, long presses and pointers reach Ruby when subscribed',
          (tester) async {
        final m = await mountMap(tester, design, {
          'on_tap': true,
          'on_long_press': true,
          'on_secondary_tap': true,
          'on_pointer_down': true,
          'on_pointer_up': true,
        });
        final center = tester.getCenter(find.byType(FlutterMap));

        await tester.tapAt(center);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        final names = m.backend.events.map((e) => e.name).toList();
        expect(names, containsAllInOrder(['pointer_down', 'pointer_up']));
        final tap = m.backend.events.firstWhere((e) => e.name == 'tap');
        final data = tap.data as Map;
        expect(data['coordinates']['latitude'], closeTo(51.5, 1e-6));
        expect(data['coordinates']['longitude'], closeTo(-0.09, 1e-6));
        expect(data['gx'], center.dx);
        expect(data['gy'], center.dy);
        expect(data['lx'], 200.0);
        expect(data['ly'], 150.0);

        m.backend.events.clear();
        await tester.longPressAt(center);
        await tester.pumpAndSettle();
        expect(m.backend.events.map((e) => e.name), contains('long_press'));

        m.backend.events.clear();
        await tester.tapAt(center, buttons: kSecondaryButton);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        expect(m.backend.events.map((e) => e.name), contains('secondary_tap'));
        expect(m.backend.events.every((e) => e.id == 1), isTrue);
      });

      testWidgets('hover reaches Ruby when subscribed', (tester) async {
        final m = await mountMap(tester, design, {'on_hover': true});
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.byType(FlutterMap)));
        await tester.pump();
        final hover = m.backend.events.singleWhere((e) => e.name == 'hover');
        expect((hover.data as Map)['coordinates']['latitude'],
            closeTo(51.5, 1e-6));
      });

      testWidgets('drag moves the camera and reports position and map events',
          (tester) async {
        final m = await mountMap(tester, design, {
          'on_position_change': true,
          'on_event': true,
          'on_init': true,
        });
        expect(m.backend.events.map((e) => e.name), contains('init'));
        m.backend.events.clear();

        final before = camera(tester).center;
        await tester.drag(find.byType(FlutterMap), const Offset(-120, 0));
        await tester.pumpAndSettle();
        expect(camera(tester).center.longitude, greaterThan(before.longitude));

        final position = m.backend.events
            .lastWhere((e) => e.name == 'position_change')
            .data as Map;
        expect(position['has_gesture'], isTrue);
        expect(position['camera']['zoom'], 13.0);
        expect(position['coordinates']['longitude'],
            camera(tester).center.longitude);
        final event =
            m.backend.events.firstWhere((e) => e.name == 'event').data as Map;
        expect(event['source'], isA<String>());
        expect(event['camera']['center'], isA<Map>());
      });

      testWidgets('no events reach Ruby without subscriptions', (tester) async {
        final m = await mountMap(tester, design);
        final center = tester.getCenter(find.byType(FlutterMap));
        await tester.tapAt(center);
        await tester.longPressAt(center);
        await tester.drag(find.byType(FlutterMap), const Offset(-80, 20));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
      });

      testWidgets('zoom_in, zoom_out and zoom_to move the camera zoom',
          (tester) async {
        final m = await mountMap(tester, design);
        expect(await invoke(tester, m.root, 'zoom_in'), isNull);
        expect(camera(tester).zoom, 14.0);
        await invoke(tester, m.root, 'zoom_out');
        await invoke(tester, m.root, 'zoom_out');
        expect(camera(tester).zoom, 12.0);
        await invoke(tester, m.root, 'zoom_to', {'zoom': 9.5});
        expect(camera(tester).zoom, 9.5);
      });

      testWidgets('rotate_from and reset_rotation turn the camera',
          (tester) async {
        final m = await mountMap(tester, design);
        await invoke(tester, m.root, 'rotate_from', {'degree': 45});
        expect(camera(tester).rotation, closeTo(45, 1e-9));
        await invoke(tester, m.root, 'rotate_from', {'degree': -15});
        expect(camera(tester).rotation, closeTo(30, 1e-9));
        await invoke(tester, m.root, 'reset_rotation');
        expect(camera(tester).rotation, closeTo(0, 1e-9));
      });

      testWidgets('move_to applies destination, zoom and rotation',
          (tester) async {
        final m = await mountMap(tester, design);
        await invoke(tester, m.root, 'move_to', {
          'destination': {'latitude': 40.7, 'longitude': -74.0},
          'zoom': 11,
          'rotation': 20,
          'duration': 200,
          'curve': 'linear',
        });
        final cam = camera(tester);
        expect(cam.center.latitude, closeTo(40.7, 1e-6));
        expect(cam.center.longitude, closeTo(-74.0, 1e-6));
        expect(cam.zoom, 11.0);
        expect(cam.rotation, closeTo(20, 1e-9));
      });

      testWidgets('center_on centers the point at the requested zoom',
          (tester) async {
        final m = await mountMap(tester, design);
        // As Ruby's map.center_on([40.7, -74.0], zoom: 12) sends it.
        await invoke(tester, m.root, 'center_on', {
          'point': {'latitude': 40.7, 'longitude': -74.0},
          'zoom': 12,
        });
        final cam = camera(tester);
        expect(cam.center.latitude, closeTo(40.7, 1e-6));
        expect(cam.center.longitude, closeTo(-74.0, 1e-6));
        expect(cam.zoom, 12.0);
      });

      testWidgets('duration and curve arguments time the animation',
          (tester) async {
        final m = await mountMap(tester, design);
        var done = false;
        unawaited(m.root
            .invokeMethod(
                'zoom_to',
                {
                  'zoom': 15,
                  'duration': 1000,
                  'curve': 'linear',
                },
                const Duration(seconds: 5))
            .then((_) => done = true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(done, isFalse);
        expect(camera(tester).zoom, closeTo(14, 0.1));
        await tester.pumpAndSettle();
        expect(done, isTrue);
        expect(camera(tester).zoom, 15.0);
      });

      testWidgets('animation_duration and animation_curve set the default',
          (tester) async {
        final m = await mountMap(tester, design, {
          'animation_duration': 2000,
          'animation_curve': 'linear',
        });
        var done = false;
        unawaited(m.root
            .invokeMethod('zoom_to', {'zoom': 17}, const Duration(seconds: 5))
            .then((_) => done = true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
        expect(done, isFalse);
        expect(camera(tester).zoom, closeTo(15, 0.1));
        await tester.pumpAndSettle();
        expect(done, isTrue);
        expect(camera(tester).zoom, 17.0);
      });

      testWidgets(
          'without animation_duration or animation_curve a call animates for '
          '500 ms on fastOutSlowIn', (tester) async {
        final m = await mountMap(tester, design);
        var done = false;
        unawaited(m.root
            .invokeMethod('zoom_to', {'zoom': 17}, const Duration(seconds: 5))
            .then((_) => done = true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(camera(tester).zoom,
            closeTo(13 + 4 * Curves.fastOutSlowIn.transform(.5), 0.1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(done, isFalse);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(done, isTrue);
        expect(camera(tester).zoom, 17.0);
      });

      testWidgets('move_to offsets the destination by the pixel offset',
          (tester) async {
        final m = await mountMap(tester, design);
        await invoke(tester, m.root, 'move_to', {
          'destination': {'latitude': 0, 'longitude': 0},
          'zoom': 5,
          'offset': [100, 0],
        });
        final cam = camera(tester);
        // The destination sits 100 px right of the map center.
        final shifted = cam.latLngToScreenOffset(const LatLng(0, 0));
        expect(shifted.dx, closeTo(200 + 100, 0.5));
        expect(shifted.dy, closeTo(150, 0.5));
      });

      testWidgets('an unknown method fails the invoke', (tester) async {
        final m = await mountMap(tester, design);
        Object? error;
        try {
          await invoke(tester, m.root, 'fly_away');
        } catch (e) {
          error = e;
        }
        expect(error.toString(), contains('Unknown Map method: fly_away'));
      });
    });
  }
}
