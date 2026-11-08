import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth_darwin/types/auth_messages_macos.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_local_auth/ruflet_local_auth.dart';
import 'package:ruflet_local_auth/src/utils/local_auth.dart';

const _timeout = Duration(seconds: 2);

/// Dart fake of the local_auth platform, so no platform channel is used.
class _FakeLocalAuth extends LocalAuthPlatform {
  final calls = <String>[];
  String? reason;
  List<AuthMessages>? messages;
  AuthenticationOptions? options;
  Object? error;
  bool authenticated = true;
  List<BiometricType> biometrics = [];

  Future<T> _answer<T>(String call, T value) async {
    calls.add(call);
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) {
    reason = localizedReason;
    messages = authMessages.toList();
    this.options = options;
    return _answer('authenticate', authenticated);
  }

  @override
  Future<bool> deviceSupportsBiometrics() =>
      _answer('deviceSupportsBiometrics', true);

  @override
  Future<bool> isDeviceSupported() => _answer('isDeviceSupported', false);

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() =>
      _answer('getEnrolledBiometrics', biometrics);

  @override
  Future<bool> stopAuthentication() => _answer('stopAuthentication', true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeLocalAuth platform;

  setUp(() {
    platform = _FakeLocalAuth();
    LocalAuthPlatform.instance = platform;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  /// A LocalAuthentication service as ServiceBinding mounts it: created by
  /// the extension, initialized, then attached.
  Control service() {
    final backend = RufletBackend(
        pageUri: Uri.parse('ruflet://local-auth-test'),
        assetsDir: '',
        extensions: [Extension()],
        multiView: false);
    final control = Control(
        id: 1, type: 'LocalAuthentication', properties: {}, backend: backend);
    Extension().createService(control)!.init();
    control.attach();
    return control;
  }

  Future<Object?> error(Control control, String method, Object? args) async {
    Object? caught;
    await control.invokeMethod(method, args, _timeout).then((_) {},
        onError: (Object e) {
      caught = e;
    });
    return caught;
  }

  test('the extension creates the service for its wire type only', () {
    final backend = RufletBackend(
        pageUri: Uri.parse('ruflet://local-auth-test'),
        assetsDir: '',
        extensions: [],
        multiView: false);
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(
        Extension().createService(control('LocalAuthentication')), isNotNull);
    expect(Extension().createService(control('SecureStorage')), isNull);
  });

  test('authenticate passes the reason and options to local_auth', () async {
    final control = service();
    final result = await control.invokeMethod(
        'authenticate',
        {
          'localized_reason': 'Unlock your notes',
          'biometric_only': true,
          'sensitive_transaction': false,
          'persist_across_backgrounding': true,
          'android_messages': {
            'sign_in_title': 'Notes',
            'sign_in_hint': 'Touch the sensor',
            'cancel_button': 'Not now',
          },
          'ios_messages': {
            'cancel_button': 'Later',
            'localized_fallback_title': 'Use passcode',
          },
          'macos_messages': {'cancel_button': 'Stop'},
        },
        _timeout);

    expect(result, isTrue);
    expect(platform.calls, ['authenticate']);
    expect(platform.reason, 'Unlock your notes');
    expect(platform.options!.biometricOnly, isTrue);
    expect(platform.options!.sensitiveTransaction, isFalse);
    expect(platform.options!.stickyAuth, isTrue);
    expect(platform.options!.useErrorDialogs, isFalse);

    final android = platform.messages!.whereType<AndroidAuthMessages>().single;
    expect(android.signInTitle, 'Notes');
    expect(android.signInHint, 'Touch the sensor');
    expect(android.cancelButton, 'Not now');
    final ios = platform.messages!.whereType<IOSAuthMessages>().single;
    expect(ios.cancelButton, 'Later');
    expect(ios.localizedFallbackTitle, 'Use passcode');
    final macos = platform.messages!.whereType<MacOSAuthMessages>().single;
    expect(macos.cancelButton, 'Stop');
    expect(macos.localizedFallbackTitle, isNull);
  });

  test('authenticate defaults match local_auth and accept Flet\'s "reason"',
      () async {
    final control = service();
    platform.authenticated = false;
    expect(
        await control.invokeMethod(
            'authenticate', {'reason': 'Confirm payment'}, _timeout),
        isFalse);

    expect(platform.reason, 'Confirm payment');
    expect(platform.options!.biometricOnly, isFalse);
    expect(platform.options!.sensitiveTransaction, isTrue);
    expect(platform.options!.stickyAuth, isFalse);
    expect(platform.messages!.map((m) => m.runtimeType), [
      IOSAuthMessages,
      AndroidAuthMessages,
      WindowsAuthMessages,
    ]);
    expect(platform.messages!.whereType<AndroidAuthMessages>().single.args,
        const AndroidAuthMessages().args);
  });

  test('a missing or blank reason is an error and never reaches the platform',
      () async {
    final control = service();
    for (final args in <Object?>[
      null,
      <String, dynamic>{},
      {'localized_reason': ''},
      {'localized_reason': '   '},
    ]) {
      expect(
          await error(control, 'authenticate', args),
          isA<ArgumentError>().having((e) => e.message, 'message',
              'LocalAuthentication.authenticate requires a "localized_reason" argument'),
          reason: '$args');
    }
    expect(platform.calls, isEmpty);
  });

  test('queries return plain values; biometrics are snake_case names',
      () async {
    final control = service();
    platform.biometrics = [
      BiometricType.face,
      BiometricType.fingerprint,
      BiometricType.strong,
    ];

    expect(await control.invokeMethod('can_check_biometrics', null, _timeout),
        isTrue);
    expect(await control.invokeMethod('is_device_supported', null, _timeout),
        isFalse);
    expect(
        await control.invokeMethod('get_available_biometrics', null, _timeout),
        ['face', 'fingerprint', 'strong']);
    expect(await control.invokeMethod('stop_authentication', null, _timeout),
        isTrue);
    expect(platform.calls, [
      'deviceSupportsBiometrics',
      'isDeviceSupported',
      'getEnrolledBiometrics',
      'stopAuthentication',
    ]);
  });

  test('every biometric type and error code has a snake_case name', () {
    expect(BiometricType.values.map(biometricTypeName),
        ['face', 'fingerprint', 'iris', 'strong', 'weak']);
    expect(snakeCase('biometricHardwareTemporarilyUnavailable'),
        'biometric_hardware_temporarily_unavailable');
    for (final code in LocalAuthExceptionCode.values) {
      final error = LocalAuthenticationError.fromLocalAuthException(
          'authenticate', LocalAuthException(code: code));
      expect(error.code, snakeCase(code.name));
      expect(error.message, isNotEmpty, reason: code.name);
      expect(error.message, isNot(code.name), reason: code.name);
    }
  });

  test('LocalAuthException becomes an error with a code and readable message',
      () async {
    final control = service();

    platform.error =
        const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
    final canceled =
        await error(control, 'authenticate', {'localized_reason': 'Unlock'});
    expect(
        canceled,
        isA<LocalAuthenticationError>()
            .having((e) => e.code, 'code', 'user_canceled')
            .having((e) => e.method, 'method', 'authenticate'));
    expect(
        canceled.toString(),
        'LocalAuthentication.authenticate failed [user_canceled]: '
        'The user canceled authentication.');

    platform.error = const LocalAuthException(
        code: LocalAuthExceptionCode.uiUnavailable,
        description: 'The current Activity must be a FragmentActivity.');
    expect(
        (await error(control, 'get_available_biometrics', null)).toString(),
        'LocalAuthentication.get_available_biometrics failed '
        '[ui_unavailable]: The current Activity must be a FragmentActivity.');
  });

  test('PlatformException keeps the platform code and message', () async {
    final control = service();

    platform.error =
        PlatformException(code: 'NotAvailable', message: 'No passcode set');
    expect(
        (await error(control, 'is_device_supported', null)).toString(),
        'LocalAuthentication.is_device_supported failed [NotAvailable]: '
        'No passcode set');

    platform.error = PlatformException(code: 'channel-error');
    expect(
        (await error(control, 'can_check_biometrics', null)).toString(),
        'LocalAuthentication.can_check_biometrics failed [channel-error]: '
        'channel-error');
  });

  test('an unknown method fails fast without reaching the platform', () async {
    final control = service();
    final stopwatch = Stopwatch()..start();
    expect(
        (await error(control, 'authenticate_with_pin', null)).toString(),
        'Exception: Unknown LocalAuthentication method: '
        'authenticate_with_pin');
    expect(stopwatch.elapsed, lessThan(_timeout));
    expect(platform.calls, isEmpty);
  });

  for (final platformCase in [TargetPlatform.linux, TargetPlatform.fuchsia]) {
    test('on ${platformCase.name} every method fails fast as unsupported',
        () async {
      debugDefaultTargetPlatformOverride = platformCase;
      final control = service();
      for (final method in [
        'authenticate',
        'can_check_biometrics',
        'is_device_supported',
        'get_available_biometrics',
        'stop_authentication',
      ]) {
        expect(
            await error(control, method, {'localized_reason': 'Unlock'}),
            isA<UnsupportedError>().having((e) => e.message, 'message',
                contains('LocalAuthentication(1).$method is not supported')),
            reason: method);
      }
      expect(platform.calls, isEmpty);
    });
  }

  test('each supported platform handles invokes', () async {
    for (final target in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = target;
      expect(
          await service().invokeMethod('is_device_supported', null, _timeout),
          isFalse,
          reason: target.name);
    }
    expect(platform.calls, hasLength(4));
  });
}
