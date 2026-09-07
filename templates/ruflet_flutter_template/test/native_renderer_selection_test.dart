import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/native_renderer.dart';

void main() {
  const experimental = bool.fromEnvironment('RUFLET_EXPERIMENTAL_NATIVE_RENDERER');
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platform in TargetPlatform.values) {
    test('Flutter engine stays default on $platform (experimental=$experimental)', () {
      debugDefaultTargetPlatformOverride = platform;
      final apple = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
      expect(usesNativeAppleRenderer, experimental && apple);
    });
  }
}
