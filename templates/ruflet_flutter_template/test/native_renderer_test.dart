import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_client/main.self.dart' as self_entry;
import 'package:ruflet_client/main.server.dart' as server_entry;
import 'package:ruflet_client/native_renderer.dart';

const _channel = MethodChannel('ruflet/native_renderer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test(
    'iOS hands the exact resolved HTTP page URL to the native host',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const pageUrl = 'http://192.168.1.226:8550/gallery?mode=server';

      expect(usesNativeAppleRenderer, isTrue);
      expect(await showNativeAppleRenderer(pageUrl), isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'show');
      expect(calls.single.arguments, {'pageUrl': pageUrl});
    },
  );

  test('macOS uses the same native channel and exact page URL', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const pageUrl = 'https://example.test/ruflet/native?token=unchanged';

    expect(usesNativeAppleRenderer, isTrue);
    expect(await showNativeAppleRenderer(pageUrl), isTrue);
    expect(calls.single.arguments, {'pageUrl': pageUrl});
  });

  test('Apple requires a successful native handoff', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => false);

    await expectLater(
      requireNativeAppleRenderer('https://example.test/ruflet'),
      throwsA(isA<StateError>()),
    );
  });

  test('non-Apple platforms keep Flet and never invoke the bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(usesNativeAppleRenderer, isFalse);
    expect(await showNativeAppleRenderer('http://10.0.2.2:8550'), isFalse);
    expect(calls, isEmpty);
  });

  test('both modes preserve HTTP page URLs and reject websocket endpoints', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const pageUrl = 'https://example.test/ruflet/app?token=unchanged';

    expect(self_entry.parseBackendUrl(pageUrl), pageUrl);
    expect(server_entry.parseBackendUrl(pageUrl), pageUrl);
    expect(server_entry.resolveBackendUrl([pageUrl]), pageUrl);
    expect(self_entry.parseBackendUrl('ws://example.test/ws'), isNull);
    expect(server_entry.parseBackendUrl('wss://example.test/ws'), isNull);
  });
}
