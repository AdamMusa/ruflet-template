import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_secure_storage/ruflet_secure_storage.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _timeout = Duration(seconds: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platformCalls = <MethodCall>[];

  setUp(() {
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      platformCalls.add(call);
      return switch (call.method) {
        'read' => 'stored',
        'containsKey' => true,
        'readAll' => <String, String>{'k': 'stored'},
        _ => null,
      };
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null));

  Control storage() {
    final backend = RufletBackend(
        pageUri: Uri.parse('ruflet://secure-storage-test'),
        assetsDir: '',
        extensions: [Extension()],
        multiView: false);
    final control = Control(
        id: 1, type: 'SecureStorage', properties: {}, backend: backend);
    Extension().createService(control)!.init();
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

  test('missing key or value is an error and never reaches the platform',
      () async {
    final control = storage();
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
    final control = storage();
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
}
