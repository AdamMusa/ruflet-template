import 'dart:async';

import 'package:collection/collection.dart';
import 'package:ruflet/ruflet.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'utils/geolocator.dart';

class GeolocatorService extends RufletService {
  GeolocatorService({required super.control});

  StreamSubscription<Position>? _onPositionChangedSubscription;

  /// A copy of the configuration the running position stream was started
  /// with.
  Object? _streamConfiguration;

  /// Whether the running position stream reported an error (as when
  /// location permission is missing) or ended (a `time_limit`), so the next
  /// patch restarts it. The plugins keep an errored stream until it is
  /// cancelled, so the restart starts location updates on the device again,
  /// and a restart that fails again is retried on the patch after.
  bool _streamFailed = false;

  @override
  void init() {
    super.init();
    debugPrint("Geolocator(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
    _updatePositionStream();
  }

  @override
  void update() {
    debugPrint("Geolocator(${control.id}).update: ${control.properties}");
    _updatePositionStream();
  }

  /// Streams positions while Ruby handles `on_position_change`, with one
  /// subscription at most, restarted when the `configuration` changes or
  /// on the first patch after the stream failed.
  ///
  /// A Geolocator used only for one-off queries starts no location updates.
  void _updatePositionStream() {
    final subscribed = control.getBool("on_position_change") == true;
    final configuration = control.get("configuration");
    if (subscribed &&
        _onPositionChangedSubscription != null &&
        !_streamFailed &&
        const DeepCollectionEquality()
            .equals(configuration, _streamConfiguration)) {
      return;
    }
    _onPositionChangedSubscription?.cancel();
    _onPositionChangedSubscription = null;
    if (!subscribed) return;

    // Ruby's patches merge into the property's map in place, so compare the
    // next configuration with a copy.
    _streamConfiguration = _copy(configuration);
    _streamFailed = false;
    _onPositionChangedSubscription = Geolocator.getPositionStream(
      locationSettings: parseLocationSettings(configuration),
    ).listen(
      (Position? position) {
        if (position != null) {
          control.updateProperties({"position": position.toMap()});
          control
              .triggerEvent("position_change", {"position": position.toMap()});
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _streamFailed = true;
        control.triggerEvent("error", error.toString());
      },
      onDone: () => _streamFailed = true,
    );
  }

  static Object? _copy(Object? value) => switch (value) {
        Map() => {
            for (final entry in value.entries) entry.key: _copy(entry.value)
          },
        List() => [for (final item in value) _copy(item)],
        _ => value,
      };

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("Geolocator.$name($args)");
    switch (name) {
      case "request_permission":
        var permission = await Geolocator.requestPermission();
        return permission.name;
      case "get_permission_status":
        var permission = await Geolocator.checkPermission();
        return permission.name;
      case "is_location_service_enabled":
        var serviceEnabled = await Geolocator.isLocationServiceEnabled();
        return serviceEnabled;
      case "open_app_settings":
        if (!kIsWeb) {
          return await Geolocator.openAppSettings();
        }
        break;
      case "open_location_settings":
        if (!kIsWeb) {
          return await Geolocator.openLocationSettings();
        }
        break;
      case "get_last_known_position":
        if (!kIsWeb) {
          return (await Geolocator.getLastKnownPosition())?.toMap();
        }
        break;
      case "get_current_position":
        try {
          Position currentPosition = await Geolocator.getCurrentPosition(
            locationSettings: parseLocationSettings(args["settings"]),
          );
          return currentPosition.toMap();
        } catch (error) {
          // on_error handlers hear about it, and the invoke fails too, so
          // Ruby's on_result gets the error instead of a nil position.
          control.triggerEvent("error", error.toString());
          rethrow;
        }
      case "distance_between":
        final p = [
          for (final key in const [
            "start_latitude",
            "start_longitude",
            "end_latitude",
            "end_longitude",
          ])
            _coordinate(args, key)
        ];
        return Geolocator.distanceBetween(p[0], p[1], p[2], p[3]);
      default:
        throw Exception("Unknown Geolocator method: $name");
    }
  }

  /// The coordinate [key] of a distance_between invoke, which cannot be
  /// measured without all four.
  static double _coordinate(Map args, String key) {
    const method = "Geolocator.distance_between";
    final value = requireInvokeArg(args, key, method);
    final coordinate = parseDouble(value);
    if (coordinate == null) {
      throw ArgumentError('$method "$key" must be a number, got "$value"');
    }
    return coordinate;
  }

  @override
  void dispose() {
    debugPrint("Geolocator(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    _onPositionChangedSubscription?.cancel();
    super.dispose();
  }
}
