import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
// Public, but not re-exported by local_auth_darwin.dart.
import 'package:local_auth_darwin/types/auth_messages_macos.dart';
import 'package:local_auth_windows/local_auth_windows.dart';

AndroidAuthMessages? parseAndroidAuthMessages(dynamic value) {
  if (value is! Map) return null;
  return AndroidAuthMessages(
    signInHint: value["sign_in_hint"]?.toString(),
    cancelButton: value["cancel_button"]?.toString(),
    signInTitle: value["sign_in_title"]?.toString(),
  );
}

IOSAuthMessages? parseIosAuthMessages(dynamic value) {
  if (value is! Map) return null;
  return IOSAuthMessages(
    cancelButton: value["cancel_button"]?.toString(),
    localizedFallbackTitle: value["localized_fallback_title"]?.toString(),
  );
}

MacOSAuthMessages? parseMacOSAuthMessages(dynamic value) {
  if (value is! Map) return null;
  return MacOSAuthMessages(
    cancelButton: value["cancel_button"]?.toString(),
    localizedFallbackTitle: value["localized_fallback_title"]?.toString(),
  );
}

/// The `authMessages` for an `authenticate` invoke: local_auth's defaults with
/// each platform's entry replaced by `android_messages`, `ios_messages` or
/// `macos_messages` when Ruby sends one.
List<AuthMessages> parseAuthMessages(Map args) {
  final android = parseAndroidAuthMessages(args["android_messages"]);
  final ios = parseIosAuthMessages(args["ios_messages"]);
  final macos = parseMacOSAuthMessages(args["macos_messages"]);
  return [
    ios ?? const IOSAuthMessages(),
    android ?? const AndroidAuthMessages(),
    const WindowsAuthMessages(),
    if (macos != null) macos,
  ];
}

/// `fooBarBaz` -> `foo_bar_baz`, the spelling Ruby uses for enum values.
String snakeCase(String value) {
  final out = StringBuffer();
  for (final unit in value.runes) {
    final char = String.fromCharCode(unit);
    final lower = char.toLowerCase();
    if (char != lower && out.isNotEmpty) out.write("_");
    out.write(lower);
  }
  return out.toString();
}

String biometricTypeName(BiometricType type) => snakeCase(type.name);

const Map<LocalAuthExceptionCode, String> _defaultDescriptions = {
  LocalAuthExceptionCode.authInProgress:
      "An authentication is already in progress.",
  LocalAuthExceptionCode.uiUnavailable:
      "The authentication prompt could not be shown.",
  LocalAuthExceptionCode.userCanceled: "The user canceled authentication.",
  LocalAuthExceptionCode.timeout: "Authentication timed out.",
  LocalAuthExceptionCode.systemCanceled:
      "The system canceled authentication, for example because the app was "
          "sent to the background.",
  LocalAuthExceptionCode.noCredentialsSet:
      "The device has no biometrics, PIN, pattern or passcode set up.",
  LocalAuthExceptionCode.noBiometricsEnrolled:
      "No biometrics are enrolled on this device.",
  LocalAuthExceptionCode.noBiometricHardware:
      "This device has no biometric hardware.",
  LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      "The biometric hardware is temporarily unavailable.",
  LocalAuthExceptionCode.temporaryLockout:
      "Authentication is temporarily locked after too many failed attempts.",
  LocalAuthExceptionCode.biometricLockout:
      "Biometric authentication is locked until the user unlocks the device "
          "another way.",
  LocalAuthExceptionCode.userRequestedFallback:
      "The user chose the fallback authentication option.",
  LocalAuthExceptionCode.deviceError: "The device reported an error.",
  LocalAuthExceptionCode.unknownError: "Authentication failed.",
};

/// A failed LocalAuthentication invoke. The backend sends [toString] to Ruby
/// as the invoke's error:
///
///     LocalAuthentication.authenticate failed [user_canceled]: The user canceled authentication.
///
/// [code] is the snake_case [LocalAuthExceptionCode] name, or a
/// [PlatformException]'s code as the platform reported it.
class LocalAuthenticationError implements Exception {
  const LocalAuthenticationError(this.method, this.code, this.message);

  factory LocalAuthenticationError.fromLocalAuthException(
      String method, LocalAuthException error) {
    final description = error.description;
    return LocalAuthenticationError(
      method,
      snakeCase(error.code.name),
      description != null && description.isNotEmpty
          ? description
          : _defaultDescriptions[error.code] ?? error.code.name,
    );
  }

  factory LocalAuthenticationError.fromPlatformException(
      String method, PlatformException error) {
    final message = error.message;
    return LocalAuthenticationError(
      method,
      error.code,
      message != null && message.isNotEmpty ? message : error.code,
    );
  }

  final String method;
  final String code;
  final String message;

  @override
  String toString() => "LocalAuthentication.$method failed [$code]: $message";
}
