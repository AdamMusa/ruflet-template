import 'package:flutter/foundation.dart';

/// Normalizes the args of a control or service method invoke to a map.
///
/// Ruby's `Page#invoke` sends `args: nil` for methods called without
/// arguments, so handlers must never index a null payload. Missing keys then
/// read as `null` and each handler falls back to a default or a no-op.
Map<dynamic, dynamic> invokeArgs(dynamic args) {
  if (args is Map) return args;
  if (args != null) {
    debugPrint("Ignoring non-map invoke args: $args");
  }
  return const {};
}

/// Returns the [argument] that [method] cannot run without.
///
/// A missing value throws an [ArgumentError] naming the method and argument;
/// the backend returns it as the invoke's error, so Ruby raises (or gets it
/// in `on_result`) instead of mistaking a no-op for success.
dynamic requireInvokeArg(Map args, String argument, String method) {
  final value = args[argument];
  if (value == null) {
    throw ArgumentError('$method requires a "$argument" argument');
  }
  return value;
}

/// Logs an invoke skipped because an argument with no meaningful default is
/// missing, and returns `null`. Use only where doing nothing is the expected
/// outcome (e.g. Tabs.move_to without an index); otherwise use
/// [requireInvokeArg].
dynamic skipInvoke(String method, String argument) {
  debugPrint("$method skipped: missing \"$argument\" argument");
  return null;
}
