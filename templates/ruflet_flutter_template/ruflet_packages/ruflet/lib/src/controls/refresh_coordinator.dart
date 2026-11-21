import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/control.dart';
import '../utils/time.dart';

/// Connects a native pull-to-refresh indicator to the Ruby `on_refresh`
/// handler.
///
/// [refresh] sends the `refresh` event and returns a future the indicator
/// awaits: it completes when Ruby invokes `end_refresh` (Ruflet's Page does
/// that automatically once the handler returns) or, as a safety net, after
/// `refresh_timeout` (default 30 s). A pull while a refresh is pending joins
/// the pending one instead of firing a second event.
class RefreshCoordinator {
  static const defaultTimeout = Duration(seconds: 30);

  Control _control;
  Completer<void>? _pending;
  Future<void>? _pendingFuture;

  RefreshCoordinator(this._control) {
    _control.addInvokeMethodListener(_invokeMethod);
  }

  Control get control => _control;

  bool get isRefreshing => _pending != null;

  /// Re-binds the coordinator when its widget is rebuilt for a different
  /// control object.
  set control(Control value) {
    if (identical(value, _control)) return;
    _control.removeInvokeMethodListener(_invokeMethod);
    _control = value;
    _control.addInvokeMethodListener(_invokeMethod);
  }

  Future<void> refresh() {
    final pendingFuture = _pendingFuture;
    if (pendingFuture != null) return pendingFuture;

    final completer = Completer<void>();
    _pending = completer;
    debugPrint("RefreshCoordinator(${_control.id}).refresh");
    _control.triggerEvent("refresh");
    final timeout = _control.getDuration("refresh_timeout", defaultTimeout)!;
    final future = completer.future.timeout(timeout, onTimeout: () {
      debugPrint("RefreshCoordinator(${_control.id}) timed out after $timeout");
      _finish(completer);
    }).whenComplete(() {
      if (identical(_pending, completer)) {
        _pending = null;
        _pendingFuture = null;
      }
    });
    _pendingFuture = future;
    return future;
  }

  void _finish(Completer<void> completer) {
    if (!completer.isCompleted) completer.complete();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    // Several listeners share a control (ScrollableControl answers
    // `scroll_to`); only `end_refresh` belongs here.
    if (name != "end_refresh") return null;
    final pending = _pending;
    if (pending != null) _finish(pending);
    return null;
  }

  void dispose() {
    _control.removeInvokeMethodListener(_invokeMethod);
    final pending = _pending;
    if (pending != null) _finish(pending);
  }
}
