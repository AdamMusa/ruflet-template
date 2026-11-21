// Mounts a service from a protocol map the way the engine does, with a
// backend that records what the service sends to Ruby.
import 'package:flutter/foundation.dart';
import 'package:ruflet/ruflet.dart';

/// One event a service sent to Ruby.
class SentEvent {
  SentEvent(this.id, this.name, this.data);

  final int id;
  final String name;
  final Object? data;

  @override
  String toString() => 'SentEvent($id, $name, $data)';
}

/// Records events exactly as the real backend sends them (only when Ruby
/// subscribed, i.e. the control has `on_<event>: true`) and every property
/// write-back, without a connection.
class RecordingBackend extends RufletBackend {
  RecordingBackend(RufletExtension extension, TargetPlatform platform)
      : super(
            pageUri: Uri.parse('ruflet://service-test'),
            assetsDir: '',
            extensions: [extension],
            multiView: false) {
    this.platform = platform;
  }

  final List<SentEvent> events = [];
  final List<Map<String, dynamic>> updates = [];

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    if (control.get("on_$eventName") == true) {
      events.add(SentEvent(control.id, eventName, eventData));
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    updates.add({'_i': id, ...props});
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

/// A service mounted as ServiceBinding mounts it: created by the extension,
/// initialized, attached, and updated whenever Ruby patches its control.
class MountedService {
  MountedService._(this.backend, this.control, this.service);

  final RecordingBackend backend;
  final Control control;
  final RufletService service;

  /// Applies a patch from Ruby and lets the service react to it.
  void patch(Map<String, dynamic> props) =>
      control.update(props, shouldNotify: true);

  Future<dynamic> invoke(String method, [Object? args]) =>
      control.invokeMethod(method, args, invokeTimeout);

  /// The error an invoke completes with, or null when it succeeds.
  Future<Object?> invokeError(String method, [Object? args]) async {
    Object? caught;
    await invoke(method, args).then((_) {}, onError: (Object e) {
      caught = e;
    });
    return caught;
  }

  void dispose() {
    control.removeListener(service.update);
    control.detach();
    service.dispose();
  }
}

const invokeTimeout = Duration(seconds: 2);

/// Mounts the service for [wire] (a protocol map with `_c` and `_i`) under
/// [platform], which selects both the backend platform and
/// [defaultTargetPlatform] (reset it with [resetTargetPlatform]).
MountedService mountService(
    RufletExtension extension, Map<String, dynamic> wire,
    {TargetPlatform platform = TargetPlatform.android}) {
  debugDefaultTargetPlatformOverride = platform;
  final backend = RecordingBackend(extension, platform);
  final control = Control.fromMap({'_i': 1, ...wire}, backend);
  final service = extension.createService(control)!;
  service.init();
  control.attach();
  control.addListener(service.update);
  return MountedService._(backend, control, service);
}

void resetTargetPlatform() => debugDefaultTargetPlatformOverride = null;
