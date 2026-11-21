// ruflet-coverage: SecureStorage
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_secure_storage/ruflet_secure_storage.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _events =
    EventChannel('plugins.it_nomads.com/flutter_secure_storage/events');
const _timeout = Duration(seconds: 2);

/// Records the events sent to Ruby. Services fire events through the real
/// [RufletBackend.triggerControlEvent], which sends only those Ruby
/// subscribed to with `on_<name>: true`; this records what it sends.
class _Backend extends RufletBackend {
  _Backend()
      : super(
            pageUri: Uri.parse('ruflet://secure-storage-test'),
            assetsDir: '',
            extensions: [Extension()],
            multiView: false);

  final events = <List<Object?>>[];

  @override
  void triggerControlEventById(int controlId, String eventName,
      [dynamic eventData]) {
    events.add([eventName, eventData]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final platformCalls = <MethodCall>[];
  Object? platformError;
  bool protectedDataAvailable = true;

  setUp(() {
    platformCalls.clear();
    platformError = null;
    protectedDataAvailable = true;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      platformCalls.add(call);
      if (platformError != null) throw platformError!;
      return switch (call.method) {
        'read' => 'stored',
        'containsKey' => true,
        'readAll' => <String, String>{'k': 'stored'},
        'isProtectedDataAvailable' => protectedDataAvailable,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockStreamHandler(_events, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// A SecureStorage service from its wire map, mounted as ServiceBinding
  /// does: created by the extension, initialized, attached, and updated
  /// whenever the control changes.
  (Control, _Backend) storage([Map<String, dynamic> props = const {}]) {
    final backend = _Backend();
    final control = Control.fromMap(
        {'_c': 'SecureStorage', '_i': 10, ...props}, backend);
    final service = Extension().createService(control)!..init();
    control.attach();
    control.addListener(service.update);
    addTearDown(() {
      control.removeListener(service.update);
      control.detach();
      service.dispose();
    });
    return (control, backend);
  }

  Future<Object?> error(Control control, String method, Object? args) async {
    Object? caught;
    await control.invokeMethod(method, args, _timeout).then((_) {},
        onError: (Object e) {
      caught = e;
    });
    return caught;
  }

  Map<Object?, Object?> optionsOf(MethodCall call) =>
      (call.arguments as Map)['options'] as Map<Object?, Object?>;

  test('the extension creates the service for its wire type only', () {
    final backend = _Backend();
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(Extension().createService(control('SecureStorage')), isNotNull);
    expect(Extension().createService(control('LocalAuthentication')), isNull);
  });

  test('missing key or value is an error and never reaches the platform',
      () async {
    final (control, _) = storage();
    for (final args in [null, <String, dynamic>{}]) {
      for (final method in ['set', 'get', 'contains_key', 'remove']) {
        expect(
            await error(control, method, args),
            isA<ArgumentError>().having((e) => e.message, 'message',
                'SecureStorage.$method requires a "key" argument'),
            reason: '$method($args)');
      }
    }
    // flutter_secure_storage would turn write(value: null) into a delete.
    expect(
        await error(control, 'set', {'key': 'k'}),
        isA<ArgumentError>().having((e) => e.message, 'message',
            'SecureStorage.set requires a "value" argument'));
    expect(platformCalls, isEmpty);
  });

  test('complete calls reach the platform; get_all needs no args', () async {
    final (control, _) = storage();
    await control.invokeMethod('set', {'key': 'k', 'value': 5}, _timeout);
    expect(await control.invokeMethod('get', {'key': 'k'}, _timeout),
        'stored');
    expect(await control.invokeMethod('get_all', null, _timeout),
        {'k': 'stored'});

    expect(platformCalls.map((c) => c.method), ['write', 'read', 'readAll']);
    final write = platformCalls.first.arguments as Map;
    expect(write['key'], 'k');
    expect(write['value'], '5');
  });

  test('every Ruby method reaches its platform call and returns its value',
      () async {
    final (control, _) = storage();
    final results = <String, Object?>{
      'set': await control.invokeMethod(
          'set', {'key': 'token', 'value': 'abc'}, _timeout),
      'get': await control.invokeMethod('get', {'key': 'token'}, _timeout),
      'get_all': await control.invokeMethod('get_all', null, _timeout),
      'contains_key': await control.invokeMethod(
          'contains_key', {'key': 'token'}, _timeout),
      'remove':
          await control.invokeMethod('remove', {'key': 'token'}, _timeout),
      'clear': await control.invokeMethod('clear', null, _timeout),
    };

    expect(results, {
      'set': null,
      'get': 'stored',
      'get_all': {'k': 'stored'},
      'contains_key': true,
      'remove': null,
      'clear': null,
    });
    expect(platformCalls.map((c) => c.method),
        ['write', 'read', 'readAll', 'containsKey', 'delete', 'deleteAll']);
    expect(
        [for (final c in platformCalls) (c.arguments as Map)['key']],
        ['token', 'token', null, 'token', 'token', null]);
    expect((platformCalls.first.arguments as Map)['value'], 'abc');
  });

  test('a key Ruby sends as a number reaches the platform as a string',
      () async {
    final (control, _) = storage();
    await control.invokeMethod('get', {'key': 42}, _timeout);
    expect((platformCalls.single.arguments as Map)['key'], '42');
  });

  test('android_options set the defaults; a call\'s "android" overrides them',
      () async {
    final (control, _) = storage({
      'android_options': {
        'reset_on_error': false,
        'enforce_biometrics': true,
        'key_cipher_algorithm': 'RSA_ECB_PKCS1Padding',
        'storage_cipher_algorithm': 'AES_CBC_PKCS7Padding',
        'shared_preferences_name': 'vault',
        'preferences_key_prefix': 'app_',
        'biometric_prompt_title': 'Unlock vault',
        'biometric_prompt_subtitle': 'Touch the sensor',
      },
    });

    await control.invokeMethod('get', {'key': 'k'}, _timeout);
    await control.invokeMethod(
        'get',
        {
          'key': 'k',
          'android': {
            'shared_preferences_name': 'other',
            'migrate_on_algorithm_change': false,
          },
        },
        _timeout);

    final defaults = optionsOf(platformCalls[0]);
    expect(defaults['resetOnError'], 'false');
    expect(defaults['migrateOnAlgorithmChange'], 'true');
    expect(defaults['enforceBiometrics'], 'true');
    expect(defaults['keyCipherAlgorithm'], 'RSA_ECB_PKCS1Padding');
    expect(defaults['storageCipherAlgorithm'], 'AES_CBC_PKCS7Padding');
    expect(defaults['sharedPreferencesName'], 'vault');
    expect(defaults['preferencesKeyPrefix'], 'app_');
    expect(defaults['biometricPromptTitle'], 'Unlock vault');
    expect(defaults['biometricPromptSubtitle'], 'Touch the sensor');

    // The fields the call's map leaves out take the service's defaults, not
    // the control's. The cipher defaults decide whether data already
    // stored can still be read.
    expect(optionsOf(platformCalls[1]), {
      'encryptedSharedPreferences': 'false',
      'resetOnError': 'true',
      'migrateOnAlgorithmChange': 'false',
      'enforceBiometrics': 'false',
      'keyCipherAlgorithm': 'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
      'storageCipherAlgorithm': 'AES_GCM_NoPadding',
      'sharedPreferencesName': 'other',
      // No prefix: the plugin uses its own.
      'preferencesKeyPrefix': '',
      'biometricPromptTitle': 'Authenticate to access',
      'biometricPromptSubtitle': 'Use biometrics or device credentials',
    });
  });

  test('a call\'s "android" without a preferences name uses the plugin\'s',
      () async {
    final (control, _) = storage({
      'android_options': {'shared_preferences_name': 'vault'},
    });
    await control.invokeMethod(
        'contains_key',
        {
          'key': 'k',
          'android': {'enforce_biometrics': true},
        },
        _timeout);

    expect(optionsOf(platformCalls.single), {
      'encryptedSharedPreferences': 'false',
      'resetOnError': 'true',
      'migrateOnAlgorithmChange': 'true',
      'enforceBiometrics': 'true',
      'keyCipherAlgorithm': 'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
      'storageCipherAlgorithm': 'AES_GCM_NoPadding',
      'sharedPreferencesName': '',
      'preferencesKeyPrefix': '',
      'biometricPromptTitle': 'Authenticate to access',
      'biometricPromptSubtitle': 'Use biometrics or device credentials',
    });
  });

  test('on iOS ios_options set the defaults; a call\'s "ios" overrides them',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (control, _) = storage({
      'ios_options': {
        'account_name': 'vault',
        'group_id': 'group.app',
        'accessibility': 'first_unlock_this_device',
        'synchronizable': true,
        'label': 'Vault',
        'description': 'Login token',
        'comment': 'v1',
        'is_invisible': true,
        'is_negative': false,
        'result_limit': 3,
        'auth_ui_behavior': 'kSecUseAuthenticationUIFail',
        'access_control_flags': ['biometry_any', 'device_passcode'],
      },
      // Not the running platform, so never used.
      'android_options': {'shared_preferences_name': 'unused'},
    });

    await control.invokeMethod('set', {'key': 'k', 'value': 'v'}, _timeout);
    await control.invokeMethod(
        'set',
        {
          'key': 'k',
          'value': 'v',
          'ios': {'accessibility': 'passcode', 'is_persistent': true},
        },
        _timeout);

    final defaults = optionsOf(platformCalls[0]);
    expect(defaults['accountName'], 'vault');
    expect(defaults['groupId'], 'group.app');
    expect(defaults['accessibility'], 'first_unlock_this_device');
    expect(defaults['synchronizable'], 'true');
    expect(defaults['label'], 'Vault');
    expect(defaults['description'], 'Login token');
    expect(defaults['comment'], 'v1');
    expect(defaults['isInvisible'], 'true');
    expect(defaults['isNegative'], 'false');
    expect(defaults['resultLimit'], '3');
    expect(defaults['shouldReturnPersistentReference'], 'false');
    expect(defaults['authenticationUIBehavior'], 'kSecUseAuthenticationUIFail');
    expect(defaults['accessControlFlags'], '[biometryAny, devicePasscode]');
    expect(defaults.containsKey('sharedPreferencesName'), isFalse);

    // The fields the call's map leaves out take the service's defaults:
    // not synchronizable, no access control flags.
    expect(optionsOf(platformCalls[1]), {
      'accessibility': 'passcode',
      'synchronizable': 'false',
      'shouldReturnPersistentReference': 'true',
    });
  });

  /// The Apple targets and the control-level and per-call option keys
  /// Ruby sends for them.
  const apple = [
    (TargetPlatform.iOS, 'ios_options', 'ios'),
    (TargetPlatform.macOS, 'macos_options', 'macos'),
  ];

  test('keychain dates Ruby sends as strings reach the platform', () async {
    // A Ruby Time on the wire is its to_s: "UTC" for a UTC Time, else
    // its offset. Time#iso8601 strings work too.
    const dates = {
      '2024-05-01 10:00:00 UTC': '2024-05-01T10:00:00.000Z',
      '2024-05-01 10:00:00 +0000': '2024-05-01T10:00:00.000Z',
      '2024-05-01 10:00:00 -0500': '2024-05-01T15:00:00.000Z',
      '2024-05-01 10:00:00 +0530': '2024-05-01T04:30:00.000Z',
      '2024-06-01T08:30:00Z': '2024-06-01T08:30:00.000Z',
      '2024-06-01T08:30:00+02:00': '2024-06-01T06:30:00.000Z',
    };
    for (final (target, options, perCall) in apple) {
      debugDefaultTargetPlatformOverride = target;
      for (final MapEntry(key: ruby, value: sent) in dates.entries) {
        platformCalls.clear();
        final (control, _) = storage({
          options: {'creation_date': ruby},
        });

        await control.invokeMethod('get_all', null, _timeout);
        await control.invokeMethod(
            'get_all',
            {
              perCall: {
                'creation_date': DateTime.utc(2024, 1, 2),
                'last_modified_date': ruby,
              },
            },
            _timeout);

        final reason = '${target.name} $ruby';
        expect(platformCalls, hasLength(2), reason: reason);
        expect(optionsOf(platformCalls[0])['creationDate'], sent,
            reason: reason);
        expect(optionsOf(platformCalls[1])['creationDate'],
            '2024-01-02T00:00:00.000Z',
            reason: reason);
        expect(optionsOf(platformCalls[1])['lastModifiedDate'], sent,
            reason: reason);
      }
    }
  });

  test('a keychain date that is not a date is left out, not an error',
      () async {
    for (final (target, options, _) in apple) {
      debugDefaultTargetPlatformOverride = target;
      platformCalls.clear();
      final (control, _) = storage({
        options: {
          'creation_date': 'not a date',
          'last_modified_date': 1714557600,
        },
      });

      expect(await control.invokeMethod('get_all', null, _timeout),
          {'k': 'stored'},
          reason: target.name);
      final sent = optionsOf(platformCalls.single);
      expect(sent.containsKey('creationDate'), isFalse, reason: target.name);
      expect(sent.containsKey('lastModifiedDate'), isFalse,
          reason: target.name);
    }
  });

  test('keychain items take the defaults for the fields Ruby leaves out',
      () async {
    // "unlocked", not synchronizable, no access control flags; iOS
    // returns no persistent reference, macOS uses the data protection
    // keychain.
    final defaults = {
      TargetPlatform.iOS: {
        'accessibility': 'unlocked',
        'synchronizable': 'false',
        'shouldReturnPersistentReference': 'false',
      },
      TargetPlatform.macOS: {
        'accessibility': 'unlocked',
        'synchronizable': 'false',
        'usesDataProtectionKeychain': 'true',
      },
    };
    for (final (target, options, perCall) in apple) {
      debugDefaultTargetPlatformOverride = target;
      platformCalls.clear();
      final (control, _) = storage({
        options: {'account_name': 'vault'},
      });

      await control.invokeMethod('get', {'key': 'k'}, _timeout);
      await control.invokeMethod(
          'get',
          {
            'key': 'k',
            perCall: {'label': 'Vault'},
          },
          _timeout);

      expect([for (final c in platformCalls) optionsOf(c)], [
        {'accountName': 'vault', ...defaults[target]!},
        {'label': 'Vault', ...defaults[target]!},
      ], reason: target.name);
    }
  });

  test('on macOS macos_options and a call\'s "macos" reach the platform',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final (control, _) = storage({
      'macos_options': {
        'account_name': 'desk',
        'group_id': 'group.desk',
        'accessibility': 'unlocked_this_device',
        'synchronizable': true,
        'label': 'Desk vault',
        'result_limit': 5,
        'access_control_flags': ['user_presence'],
        'description': 'Login token',
        'comment': 'v1',
        'is_invisible': false,
        'is_negative': true,
        'is_persistent': true,
        'auth_ui_behavior': 'kSecUseAuthenticationUISkip',
        'uses_data_protection_keychain': false,
      },
    });

    await control.invokeMethod('get_all', null, _timeout);
    await control.invokeMethod(
        'clear',
        {
          'macos': {'account_name': 'other', 'is_persistent': false},
        },
        _timeout);

    final defaults = optionsOf(platformCalls[0]);
    expect(defaults['accountName'], 'desk');
    expect(defaults['groupId'], 'group.desk');
    expect(defaults['accessibility'], 'unlocked_this_device');
    expect(defaults['synchronizable'], 'true');
    expect(defaults['label'], 'Desk vault');
    expect(defaults['resultLimit'], '5');
    expect(defaults['accessControlFlags'], '[userPresence]');
    expect(defaults['description'], 'Login token');
    expect(defaults['comment'], 'v1');
    expect(defaults['isInvisible'], 'false');
    expect(defaults['isNegative'], 'true');
    expect(defaults['shouldReturnPersistentReference'], 'true');
    expect(defaults['authenticationUIBehavior'], 'kSecUseAuthenticationUISkip');
    expect(defaults['usesDataProtectionKeychain'], 'false');

    // The fields the call's map leaves out take the service's defaults:
    // unlocked, not synchronizable, no access control flags, the data
    // protection keychain.
    expect(optionsOf(platformCalls[1]), {
      'accountName': 'other',
      'accessibility': 'unlocked',
      'synchronizable': 'false',
      'shouldReturnPersistentReference': 'false',
      'usesDataProtectionKeychain': 'true',
    });
  });

  test('on Windows windows_options and a call\'s "windows" reach the platform',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final (control, _) = storage({
      'windows_options': {'use_backward_compatibility': true},
    });

    await control.invokeMethod('contains_key', {'key': 'k'}, _timeout);
    await control.invokeMethod(
        'remove',
        {
          'key': 'k',
          'windows': {'use_backward_compatibility': false},
        },
        _timeout);
    // A call's map without the field (Ruby drops nil values) takes the
    // default, not the control's.
    await control.invokeMethod('get_all', {'windows': {}}, _timeout);

    expect([for (final c in platformCalls) optionsOf(c)], [
      {'useBackwardCompatibility': 'true'},
      {'useBackwardCompatibility': 'false'},
      {'useBackwardCompatibility': 'false'},
    ]);
  });

  test('options Ruby changes after a call apply to the next call', () async {
    for (final (target, options, first, second, sentKey, sent) in [
      (
        TargetPlatform.android,
        'android_options',
        {'shared_preferences_name': 'first'},
        {'shared_preferences_name': 'second'},
        'sharedPreferencesName',
        ['first', 'second'],
      ),
      (
        TargetPlatform.iOS,
        'ios_options',
        {'account_name': 'first'},
        {'account_name': 'second'},
        'accountName',
        ['first', 'second'],
      ),
      (
        TargetPlatform.macOS,
        'macos_options',
        {'account_name': 'first'},
        {'account_name': 'second'},
        'accountName',
        ['first', 'second'],
      ),
      (
        TargetPlatform.windows,
        'windows_options',
        {'use_backward_compatibility': true},
        {'use_backward_compatibility': false},
        'useBackwardCompatibility',
        ['true', 'false'],
      ),
    ]) {
      debugDefaultTargetPlatformOverride = target;
      platformCalls.clear();
      final (control, _) = storage({options: first});

      await control.invokeMethod('get_all', null, _timeout);
      control.update({options: second}, shouldNotify: true);
      await control.invokeMethod('get_all', null, _timeout);

      expect([for (final c in platformCalls) optionsOf(c)[sentKey]], sent,
          reason: target.name);
    }
  });

  test('get_availability asks the platform on iOS and macOS only', () async {
    for (final target in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = target;
      platformCalls.clear();
      protectedDataAvailable = false;
      final (control, _) = storage();
      expect(await control.invokeMethod('get_availability', null, _timeout),
          isFalse,
          reason: target.name);
      expect(platformCalls.map((c) => c.method), ['isProtectedDataAvailable'],
          reason: target.name);
    }

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    platformCalls.clear();
    final (control, _) = storage();
    expect(
        await control.invokeMethod('get_availability', null, _timeout), isNull);
    expect(platformCalls, isEmpty);
  });

  test('a platform failure is returned to Ruby as the invoke error', () async {
    final (control, _) = storage();
    platformError =
        PlatformException(code: 'KeyStoreError', message: 'Keystore locked');
    for (final (method, args) in [
      ('set', {'key': 'k', 'value': 'v'}),
      ('get', {'key': 'k'}),
      ('get_all', null),
      ('contains_key', {'key': 'k'}),
      ('remove', {'key': 'k'}),
      ('clear', null),
    ]) {
      expect(
          await error(control, method, args),
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'KeyStoreError')
              .having((e) => e.message, 'message', 'Keystore locked'),
          reason: method);
    }
  });

  test('an unknown method fails without reaching the platform', () async {
    final (control, _) = storage();
    expect((await error(control, 'erase_everything', null)).toString(),
        'Exception: Unknown SecureStorage method: erase_everything');
    expect(platformCalls, isEmpty);
  });

  test('after dispose the service no longer answers invokes', () async {
    final backend = _Backend();
    final control =
        Control.fromMap({'_c': 'SecureStorage', '_i': 10}, backend);
    final service = Extension().createService(control)!..init();
    control.attach();
    service.dispose();

    expect(
        await error(control, 'get', {'key': 'k'}),
        isA<UnsupportedError>().having(
            (e) => e.message, 'message', contains('SecureStorage(10).get')));
    control.detach();
    expect(platformCalls, isEmpty);
  });

  group('on_change', () {
    late List<Object?> listens;
    late int cancels;
    MockStreamHandlerEventSink? sink;

    setUp(() {
      listens = [];
      cancels = 0;
      sink = null;
      messenger.setMockStreamHandler(
          _events,
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              listens.add(arguments);
              sink = events;
            },
            onCancel: (_) => cancels++,
          ));
    });

    test('availability changes reach Ruby when it subscribed', () async {
      final (_, backend) = storage({'on_change': true});
      await pumpEventQueue();
      expect(listens, hasLength(1));

      sink!.success(false);
      sink!.success(true);
      // Not a bool: the plugin drops it.
      sink!.success('locked');
      await pumpEventQueue();

      expect(backend.events, [
        ['change', {'available': false}],
        ['change', {'available': true}],
      ]);
    });

    test('nothing listens until Ruby subscribes, and unsubscribing cancels',
        () async {
      final (control, backend) = storage();
      await pumpEventQueue();
      expect(listens, isEmpty);

      control.update({'on_change': true}, shouldNotify: true);
      await pumpEventQueue();
      expect(listens, hasLength(1));
      sink!.success(true);
      await pumpEventQueue();
      expect(backend.events, [
        ['change', {'available': true}],
      ]);

      control.update({'on_change': false}, shouldNotify: true);
      await pumpEventQueue();
      expect(cancels, 1);

      // Subscribing again listens again, once.
      control.update({'on_change': true}, shouldNotify: true);
      control.update({'data': 'unrelated'}, shouldNotify: true);
      await pumpEventQueue();
      expect(listens, hasLength(2));
    });

    test('options Ruby changes apply while Ruby listens to on_change',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final (control, _) = storage({
        'on_change': true,
        'ios_options': {'account_name': 'first'},
      });
      await control.invokeMethod('get_all', null, _timeout);
      control.update({
        'ios_options': {'account_name': 'second'},
      }, shouldNotify: true);
      await control.invokeMethod('get_all', null, _timeout);
      await pumpEventQueue();

      expect([for (final c in platformCalls) optionsOf(c)['accountName']],
          ['first', 'second']);
      // The availability stream is not restarted.
      expect(listens, hasLength(1));
      expect(cancels, 0);
    });

    test('disposing the service stops listening', () async {
      final backend = _Backend();
      final control = Control.fromMap(
          {'_c': 'SecureStorage', '_i': 10, 'on_change': true}, backend);
      final service = Extension().createService(control)!..init();
      await pumpEventQueue();
      expect(listens, hasLength(1));

      service.dispose();
      await pumpEventQueue();
      expect(cancels, 1);
    });
  });
}
