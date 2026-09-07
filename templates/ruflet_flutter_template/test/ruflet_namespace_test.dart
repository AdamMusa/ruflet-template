import 'dart:io';

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/ruflet_app_control.dart';
import 'package:ruflet/src/ruflet_core_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('Ruby RufletApp wire name reaches its renderer', () {
    final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://test'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    );
    final control = Control(
      id: 1,
      type: 'RufletApp',
      properties: {'url': 'https://example.invalid/app'},
      backend: backend,
    );
    expect(RufletCoreExtension().createWidget(null, control),
        isA<RufletAppControl>());
    const app = RufletApp(pageUrl: 'ruflet://embedded', assetsDir: '');
    expect(app, isA<RufletApp>());
  });

  test('all bundled engine and extension packages use the Ruflet namespace', () {
    final root = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final dependencies = root['dependencies'] as YamlMap;
    for (final entry in Directory('ruflet_packages').listSync()) {
      if (entry is! Directory) continue;
      final manifest = loadYaml(
          File('${entry.path}/pubspec.yaml').readAsStringSync()) as YamlMap;
      final name = manifest['name'] as String;
      expect(name == 'ruflet' || name.startsWith('ruflet_'), isTrue);
      expect((dependencies[name] as YamlMap)['path'], entry.path);
      if (name == 'ruflet') continue;
      final deps = manifest['dependencies'] as YamlMap;
      expect((deps['ruflet'] as YamlMap)['path'], '../ruflet');
      for (final mode in ['self', 'server']) {
        final main = File('lib/main.$mode.dart').readAsStringSync();
        expect(main, contains('package:$name/$name.dart'));
      }
    }
  });
}
