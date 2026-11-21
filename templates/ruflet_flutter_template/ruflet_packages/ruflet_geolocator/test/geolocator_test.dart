// ruflet-coverage: Geolocator
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart'
    show GeolocatorAndroid;
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_geolocator/ruflet_geolocator.dart';

import 'support/service_harness.dart';

/// Dart fake of the geolocator platform, so no platform channel is used.
class _FakeGeolocator extends GeolocatorPlatform {
  final calls = <String>[];
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.always;
  bool serviceEnabled = true;
  bool openedAppSettings = true;
  bool openedLocationSettings = false;
  Position? lastKnown;
  Position current = _position(52.52, 13.405);
  Object? error;

  final currentSettings = <LocationSettings?>[];
  final streamSettings = <LocationSettings?>[];
  final streams = <StreamController<Position>>[];
  final distances = <List<double>>[];

  Future<T> _answer<T>(String call, T value) async {
    calls.add(call);
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<LocationPermission> checkPermission() =>
      _answer('checkPermission', permission);

  @override
  Future<LocationPermission> requestPermission() =>
      _answer('requestPermission', requested);

  @override
  Future<bool> isLocationServiceEnabled() =>
      _answer('isLocationServiceEnabled', serviceEnabled);

  @override
  Future<bool> openAppSettings() =>
      _answer('openAppSettings', openedAppSettings);

  @override
  Future<bool> openLocationSettings() =>
      _answer('openLocationSettings', openedLocationSettings);

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      _answer('getLastKnownPosition', lastKnown);

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    currentSettings.add(locationSettings);
    return _answer('getCurrentPosition', current);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    calls.add('getPositionStream');
    streamSettings.add(locationSettings);
    final controller = StreamController<Position>();
    streams.add(controller);
    return controller.stream;
  }

  @override
  double distanceBetween(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    calls.add('distanceBetween');
    distances.add([startLatitude, startLongitude, endLatitude, endLongitude]);
    return super.distanceBetween(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }
}

final _timestamp = DateTime.utc(2026, 11, 16, 9, 30);

Position _position(double latitude, double longitude) => Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: _timestamp,
      accuracy: 4.5,
      altitude: 34.0,
      altitudeAccuracy: 2.5,
      heading: 90.0,
      headingAccuracy: 1.5,
      speed: 1.25,
      speedAccuracy: 0.5,
      floor: 2,
      isMocked: true,
    );

/// The map Ruby receives for a position.
Map<String, dynamic> _positionMap(double latitude, double longitude) => {
      'latitude': latitude,
      'longitude': longitude,
      'speed': 1.25,
      'altitude': 34.0,
      'timestamp': _timestamp,
      'accuracy': 4.5,
      'altitude_accuracy': 2.5,
      'heading': 90.0,
      'heading_accuracy': 1.5,
      'speed_accuracy': 0.5,
      'floor': 2,
      'mocked': true,
    };

const _designs = [TargetPlatform.iOS, TargetPlatform.android];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeGeolocator platform;
  final mounted = <MountedService>[];

  setUp(() {
    platform = _FakeGeolocator();
    GeolocatorPlatform.instance = platform;
  });

  tearDown(() {
    for (final service in mounted) {
      service.dispose();
    }
    mounted.clear();
    resetTargetPlatform();
  });

  MountedService geolocator(
      {Map<String, dynamic> props = const {},
      TargetPlatform platform = TargetPlatform.android}) {
    final service = mountService(Extension(), {'_c': 'Geolocator', ...props},
        platform: platform);
    mounted.add(service);
    return service;
  }

  test('the extension creates the service for its wire type only', () {
    final backend = RecordingBackend(Extension(), TargetPlatform.android);
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(Extension().createService(control('Geolocator')), isNotNull);
    expect(Extension().createService(control('PermissionHandler')), isNull);
    expect(Extension().createService(control('Map')), isNull);
  });

  for (final design in _designs) {
    group('on ${design.name}', () {
      test('permission and settings methods return plain values', () async {
        final service = geolocator(platform: design);

        expect(await service.invoke('get_permission_status'), 'whileInUse');
        expect(await service.invoke('request_permission'), 'always');
        expect(await service.invoke('is_location_service_enabled'), isTrue);
        expect(await service.invoke('open_app_settings'), isTrue);
        expect(await service.invoke('open_location_settings'), isFalse);
        expect(
            platform.calls,
            containsAllInOrder([
              'checkPermission',
              'requestPermission',
              'isLocationServiceEnabled',
              'openAppSettings',
              'openLocationSettings',
            ]));
      });

      test('every permission status reaches Ruby by its name', () async {
        final service = geolocator(platform: design);
        for (final status in LocationPermission.values) {
          platform.permission = status;
          platform.requested = status;
          expect(await service.invoke('get_permission_status'), status.name);
          expect(await service.invoke('request_permission'), status.name);
        }
        expect(LocationPermission.values.map((s) => s.name), [
          'denied',
          'deniedForever',
          'whileInUse',
          'always',
          'unableToDetermine'
        ]);
      });

      test('get_last_known_position returns the position map, or nil',
          () async {
        final service = geolocator(platform: design);

        expect(await service.invoke('get_last_known_position'), isNull);

        platform.lastKnown = _position(48.8566, 2.3522);
        expect(await service.invoke('get_last_known_position'),
            _positionMap(48.8566, 2.3522));
        expect(platform.calls.where((c) => c == 'getLastKnownPosition'),
            hasLength(2));
      });

      test('get_current_position returns every position field to Ruby',
          () async {
        final service = geolocator(platform: design);

        expect(await service.invoke('get_current_position'),
            _positionMap(52.52, 13.405));
        expect(await service.invoke('get_current_position', null),
            _positionMap(52.52, 13.405));
      });

      test('a get_current_position failure is the invoke error and on_error',
          () async {
        final quiet = geolocator(platform: design);
        final listening =
            geolocator(platform: design, props: {'on_error': true});
        platform.error = const LocationServiceDisabledException();

        for (final service in [quiet, listening]) {
          expect(await service.invokeError('get_current_position'),
              isA<LocationServiceDisabledException>());
        }
        expect(quiet.backend.events, isEmpty);
        expect(listening.backend.events.single.name, 'error');
        expect(listening.backend.events.single.data,
            'The location service on the device is disabled.');

        // Other methods already returned their platform errors to Ruby.
        expect(await listening.invokeError('get_permission_status'),
            isA<LocationServiceDisabledException>());
        expect(listening.backend.events, hasLength(1));
      });

      test('distance_between measures between the four coordinates', () async {
        final service = geolocator(platform: design);

        final metres = await service.invoke('distance_between', {
          'start_latitude': 52.52,
          'start_longitude': 13.405,
          'end_latitude': 48.8566,
          'end_longitude': 2.3522,
        });
        expect(metres, closeTo(878446.29, 0.01));
        expect(platform.distances.single, [52.52, 13.405, 48.8566, 2.3522]);

        // Integers and numeric strings are coordinates too.
        expect(
            await service.invoke('distance_between', {
              'start_latitude': 0,
              'start_longitude': '0',
              'end_latitude': 0,
              'end_longitude': 0,
            }),
            0.0);
        expect(platform.distances.last, [0.0, 0.0, 0.0, 0.0]);
      });

      test('distance_between without a number for every coordinate fails',
          () async {
        final service = geolocator(platform: design);
        const complete = {
          'start_latitude': 52.52,
          'start_longitude': 13.405,
          'end_latitude': 48.8566,
          'end_longitude': 2.3522,
        };

        expect(
            await service.invokeError('distance_between'),
            isA<ArgumentError>().having((e) => e.message, 'message',
                'Geolocator.distance_between requires a "start_latitude" argument'));
        for (final key in complete.keys) {
          expect(
              await service.invokeError(
                  'distance_between', {...complete}..remove(key)),
              isA<ArgumentError>().having((e) => e.message, 'message',
                  'Geolocator.distance_between requires a "$key" argument'),
              reason: key);
        }
        expect(
            await service.invokeError(
                'distance_between', {...complete, 'end_longitude': 'east'}),
            isA<ArgumentError>().having((e) => e.message, 'message',
                'Geolocator.distance_between "end_longitude" must be a number, got "east"'));
        expect(platform.distances, isEmpty);
      });

      test('an unknown method fails fast without reaching the platform',
          () async {
        final service = geolocator(platform: design);
        platform.calls.clear();

        expect((await service.invokeError('get_heading')).toString(),
            'Exception: Unknown Geolocator method: get_heading');
        expect(platform.calls, isEmpty);
      });
    });
  }

  group('get_current_position settings', () {
    test('Android: Ruby\'s settings become AndroidSettings', () async {
      final service = geolocator(platform: TargetPlatform.android);
      await service.invoke('get_current_position', {
        'settings': {
          'accuracy': 'best_for_navigation',
          'distance_filter': 25,
          'time_limit': {'seconds': 30},
          'interval_duration': 2500,
          'use_msl_altitude': true,
          'foreground_notification_text': 'Tracking your ride',
          'foreground_notification_title': 'Ride',
          'foreground_notification_enable_wake_lock': true,
          'foreground_notification_enable_wifi_lock': true,
          'foreground_notification_channel_name': 'Rides',
          'foreground_notification_set_ongoing': false,
        },
      });

      final settings = platform.currentSettings.single as AndroidSettings;
      expect(settings.accuracy, LocationAccuracy.bestForNavigation);
      expect(settings.distanceFilter, 25);
      expect(settings.timeLimit, const Duration(seconds: 30));
      expect(settings.intervalDuration, const Duration(milliseconds: 2500));
      expect(settings.useMSLAltitude, isTrue);
      final notification = settings.foregroundNotificationConfig!;
      expect(notification.notificationText, 'Tracking your ride');
      expect(notification.notificationTitle, 'Ride');
      expect(notification.enableWakeLock, isTrue);
      expect(notification.enableWifiLock, isTrue);
      expect(notification.notificationChannelName, 'Rides');
      expect(notification.setOngoing, isFalse);
    });

    test('Android: defaults, and a notification from either text field',
        () async {
      final service = geolocator(platform: TargetPlatform.android);
      await service.invoke('get_current_position', {'settings': {}});
      await service.invoke('get_current_position', {
        'settings': {'foreground_notification_title': 'Tracking'}
      });

      final defaults = platform.currentSettings.first as AndroidSettings;
      expect(defaults.accuracy, LocationAccuracy.best);
      expect(defaults.distanceFilter, 0);
      expect(defaults.timeLimit, isNull);
      expect(defaults.intervalDuration, const Duration(milliseconds: 5000));
      expect(defaults.useMSLAltitude, isFalse);
      expect(defaults.foregroundNotificationConfig, isNull);

      final titled = (platform.currentSettings.last as AndroidSettings)
          .foregroundNotificationConfig!;
      expect(titled.notificationTitle, 'Tracking');
      expect(titled.notificationText, 'Location Updates');
      expect(titled.notificationChannelName, 'Background Location');
      expect(titled.enableWakeLock, isFalse);
      expect(titled.enableWifiLock, isFalse);
      expect(titled.setOngoing, isTrue);
    });

    for (final apple in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      test('${apple.name}: Ruby\'s settings become AppleSettings', () async {
        final service = geolocator(platform: apple);
        await service.invoke('get_current_position', {
          'settings': {
            'accuracy': 'reduced',
            'distance_filter': 10,
            'time_limit': 1500,
            'activity_type': 'automotive_navigation',
            'pause_location_updates_automatically': true,
            'show_background_location_indicator': true,
            'allow_background_location_updates': false,
          },
        });
        await service.invoke('get_current_position', {'settings': {}});

        final settings = platform.currentSettings.first as AppleSettings;
        expect(settings.accuracy, LocationAccuracy.reduced);
        expect(settings.distanceFilter, 10);
        expect(settings.timeLimit, const Duration(milliseconds: 1500));
        expect(settings.activityType, ActivityType.automotiveNavigation);
        expect(settings.pauseLocationUpdatesAutomatically, isTrue);
        expect(settings.showBackgroundLocationIndicator, isTrue);
        expect(settings.allowBackgroundLocationUpdates, isFalse);

        final defaults = platform.currentSettings.last as AppleSettings;
        expect(defaults.accuracy, LocationAccuracy.best);
        expect(defaults.activityType, ActivityType.other);
        expect(defaults.pauseLocationUpdatesAutomatically, isFalse);
        expect(defaults.showBackgroundLocationIndicator, isFalse);
        expect(defaults.allowBackgroundLocationUpdates, isTrue);
      });
    }

    for (final desktop in [TargetPlatform.windows, TargetPlatform.linux]) {
      test('${desktop.name}: Ruby\'s settings become LocationSettings',
          () async {
        final service = geolocator(platform: desktop);
        await service.invoke('get_current_position', {
          'settings': {
            'accuracy': 'low',
            'distance_filter': 100,
            'time_limit': {'minutes': 1},
            'activity_type': 'fitness',
          },
        });

        final settings = platform.currentSettings.single!;
        expect(settings.runtimeType, LocationSettings);
        expect(settings.accuracy, LocationAccuracy.low);
        expect(settings.distanceFilter, 100);
        expect(settings.timeLimit, const Duration(minutes: 1));
      });
    }

    test('without settings geolocator picks its own platform defaults',
        () async {
      await geolocator(platform: TargetPlatform.android)
          .invoke('get_current_position');
      await geolocator(platform: TargetPlatform.iOS)
          .invoke('get_current_position');

      expect(platform.currentSettings.first, isA<AndroidSettings>());
      expect(platform.currentSettings.last.runtimeType, LocationSettings);
      expect(platform.currentSettings.last!.accuracy, LocationAccuracy.best);
    });

    test('every accuracy and activity type parses from its snake_case name',
        () async {
      final service = geolocator(platform: TargetPlatform.iOS);
      for (final (accuracy, name) in [
        (LocationAccuracy.lowest, 'lowest'),
        (LocationAccuracy.low, 'low'),
        (LocationAccuracy.medium, 'medium'),
        (LocationAccuracy.high, 'high'),
        (LocationAccuracy.best, 'best'),
        (LocationAccuracy.bestForNavigation, 'best_for_navigation'),
        (LocationAccuracy.reduced, 'reduced'),
      ]) {
        await service.invoke('get_current_position', {
          'settings': {'accuracy': name}
        });
        expect(platform.currentSettings.last!.accuracy, accuracy, reason: name);
      }
      for (final (activity, name) in [
        (ActivityType.automotiveNavigation, 'automotive_navigation'),
        (ActivityType.fitness, 'fitness'),
        (ActivityType.otherNavigation, 'other_navigation'),
        (ActivityType.airborne, 'airborne'),
        (ActivityType.other, 'other'),
        (ActivityType.maritime, 'maritime'),
      ]) {
        await service.invoke('get_current_position', {
          'settings': {'activity_type': name}
        });
        expect((platform.currentSettings.last as AppleSettings).activityType,
            activity,
            reason: name);
      }
    });
  });

  group('position stream', () {
    for (final design in _designs) {
      test('on ${design.name} positions reach Ruby when it subscribed',
          () async {
        final service = geolocator(platform: design, props: {
          'on_position_change': true,
          'configuration': {'accuracy': 'high', 'distance_filter': 5},
        });
        expect(platform.streams, hasLength(1));
        expect(platform.streamSettings.single!.accuracy, LocationAccuracy.high);
        expect(platform.streamSettings.single!.distanceFilter, 5);
        expect(
            platform.streamSettings.single,
            design == TargetPlatform.iOS
                ? isA<AppleSettings>()
                : isA<AndroidSettings>());

        platform.streams.single.add(_position(1, 2));
        await pumpEventQueue();

        final event = service.backend.events.single;
        expect(event.id, 1);
        expect(event.name, 'position_change');
        expect(event.data, {'position': _positionMap(1, 2)});
        expect(service.backend.updates, [
          {'_i': 1, 'position': _positionMap(1, 2)}
        ]);
        expect(service.control.get('position'), _positionMap(1, 2));
      });
    }

    test('stream errors reach Ruby only when it handles on_error', () async {
      final quiet = geolocator(props: {'on_position_change': true});
      platform.streams.last.addError(const LocationServiceDisabledException());
      await pumpEventQueue();
      expect(quiet.backend.events, isEmpty);

      final listening =
          geolocator(props: {'on_position_change': true, 'on_error': true});
      platform.streams.last
          .addError(const PermissionDeniedException('denied by user'));
      await pumpEventQueue();
      expect(listening.backend.events.single.name, 'error');
      expect(listening.backend.events.single.data, 'denied by user');
    });

    test('disposing the service stops the stream and its invokes', () async {
      final service = geolocator(props: {'on_position_change': true});
      final stream = platform.streams.single;
      expect(stream.hasListener, isTrue);

      mounted.remove(service);
      service.dispose();
      expect(stream.hasListener, isFalse);

      // A rendered control without listeners rejects invokes at once.
      service.control.attach();
      expect(await service.invokeError('get_permission_status'),
          isA<UnsupportedError>());
      expect(platform.calls, isNot(contains('checkPermission')));
    });

    test('without on_position_change no location updates start', () async {
      final service = geolocator(props: {
        'on_error': true,
        'configuration': {'accuracy': 'high'},
      });
      service.patch({'data': 'query only'});

      expect(platform.calls, isNot(contains('getPositionStream')));
      expect(platform.streams, isEmpty);
      expect(await service.invoke('get_permission_status'), 'whileInUse');
    });

    test('subscribing later starts the stream; unsubscribing stops it',
        () async {
      final service = geolocator();
      expect(platform.streams, isEmpty);

      service.patch({'on_position_change': true});
      final stream = platform.streams.single;
      expect(stream.hasListener, isTrue);

      service.patch({'on_position_change': false});
      expect(stream.hasListener, isFalse);
      expect(platform.streams, hasLength(1));
    });

    test('unrelated patches keep one stream, so a position reaches Ruby once',
        () async {
      final service = geolocator(props: {
        'on_position_change': true,
        'configuration': {'accuracy': 'high'},
      });
      service.patch({'data': 'first'});
      service.patch({'data': 'second'});
      service.patch({
        'configuration': {'accuracy': 'high'}
      });
      expect(platform.streams, hasLength(1));

      platform.streams.single.add(_position(3, 4));
      await pumpEventQueue();
      expect(service.backend.events.map((e) => e.name), ['position_change']);
    });

    test('a stream that failed or ended restarts on the next patch',
        () async {
      for (final fail in <void Function(StreamController<Position>)>[
        (stream) =>
            stream.addError(const PermissionDeniedException('not granted')),
        (stream) => stream.close(),
      ]) {
        platform.streams.clear();
        final service = geolocator(props: {
          'on_position_change': true,
          'configuration': {'accuracy': 'high'},
        });
        final first = platform.streams.single;
        fail(first);
        await pumpEventQueue();

        service.patch({'data': 'after the failure'});
        expect(platform.streams, hasLength(2));
        expect(first.hasListener, isFalse);
        expect(platform.streamSettings.last!.accuracy, LocationAccuracy.high);

        // The restarted stream is healthy: later patches keep it.
        service.patch({'data': 'later'});
        expect(platform.streams, hasLength(2));
        platform.streams.last.add(_position(7, 8));
        await pumpEventQueue();
        expect(service.backend.events.map((e) => e.name), ['position_change']);
      }
    });

    test('removing the configuration restarts the stream with the defaults',
        () async {
      final service = geolocator(props: {
        'on_position_change': true,
        'configuration': {'accuracy': 'low'},
      });
      final first = platform.streams.single;

      service.patch({'configuration': null});
      expect(platform.streams, hasLength(2));
      expect(first.hasListener, isFalse);
      expect(platform.streams.last.hasListener, isTrue);
      // Geolocator picks its platform defaults for null settings.
      expect(platform.streamSettings.last, isNull);
    });

    test('a configuration change restarts the stream with the new settings',
        () async {
      final service = geolocator(props: {
        'on_position_change': true,
        'configuration': {'accuracy': 'high'},
      });
      final first = platform.streams.single;

      // Ruby patches one key; it merges into the existing configuration.
      service.patch({
        'configuration': {'distance_filter': 50}
      });
      expect(platform.streams, hasLength(2));
      expect(first.hasListener, isFalse);
      expect(platform.streamSettings.last!.accuracy, LocationAccuracy.high);
      expect(platform.streamSettings.last!.distanceFilter, 50);

      platform.streams.last.add(_position(5, 6));
      await pumpEventQueue();
      expect(
          service.backend.events.single.data, {'position': _positionMap(5, 6)});
    });
  });

  /// The real geolocator_android plugin over a mocked updates channel. Like
  /// geolocator_apple, it caches its position stream until the last
  /// listener cancels. A listen on the channel is the device starting
  /// location updates (and checking permission); a cancel stops them.
  group('with the real Android plugin', () {
    const updates =
        EventChannel('flutter.baseflow.com/geolocator_updates_android');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const devicePosition = {
      'latitude': 1.0,
      'longitude': 2.0,
      'timestamp': 0,
      'accuracy': 1.0,
      'altitude': 0.0,
      'heading': 0.0,
      'speed': 0.0,
      'speed_accuracy': 0.0,
    };
    late List<Object?> listens;
    late int cancels;
    late bool denied;
    MockStreamHandlerEventSink? device;

    setUp(() {
      listens = [];
      cancels = 0;
      denied = false;
      device = null;
    });

    MountedService onDevice(Map<String, dynamic> props) {
      GeolocatorPlatform.instance = GeolocatorAndroid();
      messenger.setMockStreamHandler(
          updates,
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              listens.add(arguments);
              device = events;
              if (denied) {
                events.error(code: 'PERMISSION_DENIED', message: 'not granted');
              }
            },
            onCancel: (_) => cancels++,
          ));
      addTearDown(() => messenger.setMockStreamHandler(updates, null));
      final service = mountService(Extension(), {'_c': 'Geolocator', ...props});
      // Runs before the handler is removed, so the cancel reaches it.
      addTearDown(service.dispose);
      return service;
    }

    List<String> sent(MountedService service) =>
        [for (final e in service.backend.events) e.name];

    test('a failed stream restarts on the device on each patch until it works',
        () async {
      denied = true;
      final service = onDevice({'on_position_change': true, 'on_error': true});
      await pumpEventQueue();
      expect(listens, hasLength(1));
      expect(sent(service), ['error']);

      // While permission stays denied, every patch restarts location
      // updates once, and the failure reaches Ruby again.
      service.patch({'data': 'first'});
      await pumpEventQueue();
      service.patch({'data': 'second'});
      await pumpEventQueue();
      expect(listens, hasLength(3));
      expect(cancels, 2);
      expect(sent(service), ['error', 'error', 'error']);

      // Once permission is granted, the next patch's restart works and
      // later patches keep it.
      denied = false;
      service.patch({'data': 'granted'});
      await pumpEventQueue();
      service.patch({'data': 'later'});
      await pumpEventQueue();
      expect(listens, hasLength(4));
      expect(cancels, 3);
      device!.success(devicePosition);
      await pumpEventQueue();
      expect(sent(service), ['error', 'error', 'error', 'position_change']);
    });

    test('a configuration change restarts location updates on the device',
        () async {
      final service = onDevice({
        'on_position_change': true,
        'configuration': {'distance_filter': 10},
      });
      await pumpEventQueue();
      service.patch({
        'configuration': {'distance_filter': 50}
      });
      await pumpEventQueue();
      service.patch({'data': 'unrelated'});
      await pumpEventQueue();

      expect([for (final a in listens) (a as Map)['distanceFilter']], [10, 50]);
      expect(cancels, 1);
      device!.success(devicePosition);
      await pumpEventQueue();
      expect(sent(service), ['position_change']);
    });

    // testWidgets, for a fake clock to run out the time limit.
    testWidgets('a stream the time limit ended restarts once, on the next patch',
        (tester) async {
      final service = onDevice({
        'on_position_change': true,
        'on_error': true,
        'configuration': {'time_limit': 1000},
      });
      await tester.pump();
      expect(listens, hasLength(1));

      // No position within the time limit: the plugin reports a timeout,
      // closes the stream and stops location updates.
      await tester.pump(const Duration(seconds: 2));
      expect(cancels, 1);
      expect(sent(service), ['error']);

      service.patch({'data': 'first'});
      await tester.pump();
      service.patch({'data': 'second'});
      await tester.pump();
      expect(listens, hasLength(2));
      expect(cancels, 1);
      device!.success(devicePosition);
      await tester.pump();
      expect(sent(service), ['error', 'position_change']);

      // Unsubscribing stops the restarted stream and its time limit.
      service.patch({'on_position_change': false});
      await tester.pump();
      expect(cancels, 2);
      // testWidgets checks this before tear-down runs.
      resetTargetPlatform();
    });
  });
}
