import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ruflet/ruflet.dart';

import 'utils/local_auth.dart';

/// Whether local_auth has an implementation for the running platform
/// (Android, iOS, macOS and Windows; not Linux or the web).
bool isLocalAuthenticationSupported() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows =>
      true,
    _ => false,
  };
}

class LocalAuthenticationService extends RufletService {
  LocalAuthenticationService({required super.control});

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void init() {
    super.init();
    debugPrint(
        "LocalAuthenticationService(${control.id}).init: ${control.properties}");
    // Without a listener the mounted service rejects every invoke at once
    // with an UnsupportedError naming the method and platform, instead of
    // reaching a plugin that has no implementation there.
    if (!isLocalAuthenticationSupported()) return;
    control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("LocalAuthentication.$name($args)");
    try {
      switch (name) {
        case "authenticate":
          return await _authenticate(args);
        case "can_check_biometrics":
          return await _auth.canCheckBiometrics;
        case "is_device_supported":
          return await _auth.isDeviceSupported();
        case "get_available_biometrics":
          return (await _auth.getAvailableBiometrics())
              .map(biometricTypeName)
              .toList();
        case "stop_authentication":
          return await _auth.stopAuthentication();
        default:
          throw Exception("Unknown LocalAuthentication method: $name");
      }
    } on LocalAuthException catch (e) {
      throw LocalAuthenticationError.fromLocalAuthException(name, e);
    } on PlatformException catch (e) {
      throw LocalAuthenticationError.fromPlatformException(name, e);
    }
  }

  Future<bool> _authenticate(Map args) {
    // `reason` is the Flet spelling of the same argument.
    final reason = (args["localized_reason"] ?? args["reason"])?.toString();
    // local_auth requires a non-empty reason; iOS aborts on an empty one.
    if (reason == null || reason.trim().isEmpty) {
      throw ArgumentError(
          'LocalAuthentication.authenticate requires a "localized_reason" '
          'argument');
    }
    return _auth.authenticate(
      localizedReason: reason,
      authMessages: parseAuthMessages(args),
      biometricOnly: parseBool(args["biometric_only"], false)!,
      sensitiveTransaction: parseBool(args["sensitive_transaction"], true)!,
      persistAcrossBackgrounding:
          parseBool(args["persist_across_backgrounding"], false)!,
    );
  }

  @override
  void dispose() {
    debugPrint("LocalAuthenticationService(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }
}
