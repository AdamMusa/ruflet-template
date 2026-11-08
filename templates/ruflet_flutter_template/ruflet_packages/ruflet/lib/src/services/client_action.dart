/// Client actions (Flet 1.0's `ClientAction`): service calls the client makes
/// itself the moment a control is tapped, before it sends the click to Ruby.
///
/// Browsers only let a page write to the clipboard, open a new tab, show a
/// file picker or the share sheet while they are still handling the user's
/// gesture. Ruby's reply to a click arrives after that, so the same calls
/// made from an `on_click` handler are dropped on the web (iOS Safari above
/// all). A control's `action` key carries them instead, as Flet sends them,
/// with the service named by its wire type rather than a page-scoped id:
///
/// ```json
/// {"service": "UrlLauncher", "method": "launch_url",
///  "args": {"url": "https://ruflet.dev", "web_only_window_name": "_blank"}}
/// ```
///
/// or a list of such maps. `args` are what the matching `page.*` call sends
/// to that service. [performClientActions] starts every action synchronously
/// inside the tap callback, and the caller fires `click` afterwards. Each
/// action is performed by the page's service of that type when Ruby has
/// mounted one (so a FilePicker keeps the picked files for `page.upload`),
/// otherwise by the same service code without a service control. Each
/// outcome goes back to Ruby as the control's `action_result` event.
library;

import 'package:flutter/foundation.dart';

import '../models/control.dart';
import '../models/control_type.dart';
import 'clipboard.dart' show invokeClipboardMethod;
import 'file_picker.dart' show pickFilesWithoutService;
import 'share.dart' show invokeShareMethod;
import 'url_launcher.dart' show invokeUrlLauncherMethod;

/// The wire key a control carries its client actions in.
const clientActionKey = 'action';

/// The event each action's outcome is reported as.
const clientActionResultEvent = 'action_result';

/// One parsed client action.
@immutable
class ClientAction {
  const ClientAction(this.service, this.method, this.args);

  /// The service's wire type (`Clipboard`, `UrlLauncher`...).
  final String service;

  /// The service method the client calls.
  final String method;

  /// The method's arguments, as Ruby's `page.*` call would send them.
  final Map<String, Object?> args;

  @override
  String toString() => 'ClientAction($service.$method $args)';
}

typedef _ServiceMethod = Future<Object?> Function(String method, Object? args);

/// The service methods a client action may call, with the engine's own
/// implementation of each service.
final Map<String, (Set<String>, _ServiceMethod)> _services = {
  'UrlLauncher': (const {'launch_url'}, invokeUrlLauncherMethod),
  'Clipboard': (const {'set'}, invokeClipboardMethod),
  'FilePicker': (const {'pick_files'}, pickFilesWithoutService),
  'Share': (
    const {'share_text', 'share_uri', 'share_files'},
    invokeShareMethod
  ),
};

/// The actions in a control's `action` value: one action map or a list of
/// them. Anything that is not an action map is skipped.
List<ClientAction> parseClientActions(Object? value) {
  final items = value is List ? value : [value];
  final actions = <ClientAction>[];
  for (final item in items) {
    if (item is! Map) continue;
    final service = item['service'];
    final method = item['method'];
    final args = item['args'];
    if (service is! String || method is! String) {
      debugPrint('Ignoring malformed client action: $item');
      continue;
    }
    actions.add(ClientAction(service, method, {
      if (args is Map)
        for (final entry in args.entries) entry.key.toString(): entry.value
    }));
  }
  return actions;
}

/// Starts every action in [value] (a control's `action`) now, in order and
/// without awaiting any of them, so each reaches the platform while the
/// browser still treats the tap as a user gesture. Calls [onResult] with each
/// outcome when it completes: `{index, service, method, result}`, or
/// `{index, service, method, error}` when it failed.
void performClientActions(Control control, Object? value,
    void Function(Map<String, Object?> outcome) onResult) {
  final actions = parseClientActions(value);
  for (var index = 0; index < actions.length; index++) {
    final action = actions[index];
    final outcome = <String, Object?>{
      'index': index,
      'service': action.service,
      'method': action.method,
    };
    Future<Object?> pending;
    try {
      pending = _start(control, action);
    } catch (error) {
      pending = Future.error(error);
    }
    pending.then((result) => onResult({...outcome, 'result': result}),
        onError: (Object error) {
      debugPrint('Client action $action failed: $error');
      onResult({...outcome, 'error': '$error'});
    });
  }
}

Future<Object?> _start(Control control, ClientAction action) {
  final service = _services[action.service];
  if (service == null || !service.$1.contains(action.method)) {
    throw UnsupportedError(
        '${action.service}.${action.method} is not a client action');
  }
  final mounted = _mountedService(control, action.service);
  if (mounted != null) {
    return mounted.invokeMethod(
        action.method, action.args, const Duration(seconds: 10));
  }
  return service.$2(action.method, action.args);
}

/// The page's running service of wire type [type], if Ruby mounted one.
Control? _mountedService(Control control, String type) {
  final registry = control.backend.page.child('_services', visibleOnly: false);
  if (registry == null) return null;
  for (final service in registry.children('_services', visibleOnly: false)) {
    if (service.canonicalType == type && service.isAttached) return service;
  }
  return null;
}

/// For controls not on the shared control core: whether [control] carries
/// client actions, which makes it tappable.
bool controlHasClientActions(Control control) =>
    parseClientActions(control.get(clientActionKey)).isNotEmpty;

/// For controls not on the shared control core: performs [control]'s
/// client actions from its tap callback, before the caller fires `click`,
/// and reports each outcome as its `action_result` event (through [send]
/// when the renderer routes its events, as text spans do).
void runControlClientActions(Control control,
    [void Function(Control control, String name, [dynamic data])? send]) {
  performClientActions(control, control.get(clientActionKey), (outcome) {
    if (send != null) {
      send(control, clientActionResultEvent, outcome);
    } else {
      control.triggerEvent(clientActionResultEvent, outcome);
    }
  });
}
