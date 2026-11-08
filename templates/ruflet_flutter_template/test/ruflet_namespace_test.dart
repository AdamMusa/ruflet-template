import 'dart:io';

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/ruflet_app_control.dart';
import 'package:ruflet/src/ruflet_core_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The bundled packages that `pubspec.yaml` and both entrypoints reference.
///
/// Every published gem copies this template's `pubspec.yaml` and entrypoints
/// into the client it builds. Gems before 0.0.22 prune only the package names
/// in their own extension map (`flet_*`, plus `ruflet_qrcode_scanner` from
/// 0.0.20), so they keep every other dependency listed here, and its native
/// plugins are linked into every app they build. This set is therefore frozen
/// at what the template referenced before engine abd906b9 (e32c873).
const referencedPackages = {
  'ruflet',
  'ruflet_ads',
  'ruflet_audio',
  'ruflet_audio_recorder',
  'ruflet_camera',
  'ruflet_charts',
  'ruflet_code_editor',
  'ruflet_color_pickers',
  'ruflet_datatable2',
  'ruflet_flashlight',
  'ruflet_geolocator',
  'ruflet_lottie',
  'ruflet_map',
  'ruflet_permission_handler',
  'ruflet_qrcode_scanner',
  'ruflet_rive',
  'ruflet_secure_storage',
  'ruflet_spinkit',
  'ruflet_video',
  'ruflet_webview',
};

/// Vendored packages that no template file references.
///
/// The sync copies them into `ruflet_packages/`, but they are not a
/// dependency, not imported or registered, and not in the committed plugin
/// registrants, so no published gem compiles or links them. A CLI that
/// selects one writes its path dependency, import and registration itself.
const optInPackages = {'ruflet_local_auth'};

/// The extension packages that released gems 0.0.22 and 0.0.23 know by name
/// (their `CLIENT_EXTENSION_MAP`).
///
/// Those gems strip the registration of any other package with
/// `/^\s*alias\.Extension\(\),\s*\n/`, after their `prune_client_main` has
/// already blanked every known registration it drops. Above
/// `// --FAT_CLIENT_END--` that match also swallows those blank lines, so the
/// entrypoints they generate change (e793cce on this branch). A registration
/// of a package outside this set may therefore only sit after the marker.
const releasedGemPackages = {
  'ruflet_ads',
  'ruflet_audio',
  'ruflet_audio_recorder',
  'ruflet_camera',
  'ruflet_charts',
  'ruflet_code_editor',
  'ruflet_color_pickers',
  'ruflet_datatable2',
  'ruflet_flashlight',
  'ruflet_geolocator',
  'ruflet_lottie',
  'ruflet_map',
  'ruflet_permission_handler',
  'ruflet_qrcode_scanner',
  'ruflet_rive',
  'ruflet_secure_storage',
  'ruflet_spinkit',
  'ruflet_video',
  'ruflet_webview',
};

const fatClientStart = '// --FAT_CLIENT_START--';
const fatClientEnd = '// --FAT_CLIENT_END--';

const entrypoints = ['lib/main.self.dart', 'lib/main.server.dart'];

const committedRegistrants = [
  'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugins.cmake',
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugins.cmake',
];

YamlMap _yaml(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

Map<String, dynamic> _section(YamlMap manifest, String key) {
  final value = manifest[key];
  return value is YamlMap ? Map<String, dynamic>.from(value) : {};
}

Set<String> _vendoredPackageNames() => Directory('ruflet_packages')
    .listSync()
    .whereType<Directory>()
    .map((dir) => _yaml('${dir.path}/pubspec.yaml')['name'] as String)
    .toSet();

/// The alias the entrypoint imports [package] under, or null.
String? _importAlias(String source, String package) {
  final match = RegExp(
    "^import 'package:$package/$package\\.dart'\\s+as\\s+([A-Za-z0-9_]+);",
    multiLine: true,
  ).firstMatch(source);
  return match?.group(1);
}

/// Every `import 'package:<package>/...' as <alias>;` in [source], by alias.
Map<String, String> _importedPackagesByAlias(String source) => {
  for (final match in RegExp(
    r"^import 'package:([^/]+)/[^']+'\s+as\s+([A-Za-z0-9_]+);",
    multiLine: true,
  ).allMatches(source))
    match.group(2)!: match.group(1)!,
};

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
    for (final entry in Directory('ruflet_packages').listSync()) {
      if (entry is! Directory) continue;
      final manifest = loadYaml(
          File('${entry.path}/pubspec.yaml').readAsStringSync()) as YamlMap;
      final name = manifest['name'] as String;
      expect(name == 'ruflet' || name.startsWith('ruflet_'), isTrue);
      expect(entry.path, 'ruflet_packages/$name');
      if (name == 'ruflet') continue;
      final deps = manifest['dependencies'] as YamlMap;
      expect((deps['ruflet'] as YamlMap)['path'], '../ruflet');
    }
  });

  test('every vendored package is either referenced or opt-in', () {
    expect(referencedPackages.intersection(optInPackages), isEmpty);
    expect(
      _vendoredPackageNames(),
      unorderedEquals({...referencedPackages, ...optInPackages}),
      reason:
          'A package new to ruflet_packages/ must be added to '
          'optInPackages. Referencing it from pubspec.yaml or an entrypoint '
          'links its plugins into every app that gems before 0.0.22 build.',
    );
  });

  test('referenced packages are dependencies imported and registered by both '
      'entrypoints', () {
    final dependencies = _section(_yaml('pubspec.yaml'), 'dependencies');
    for (final name in referencedPackages) {
      expect(
        (dependencies[name] as YamlMap?)?['path'],
        'ruflet_packages/$name',
        reason: '$name must be a path dependency',
      );
      for (final path in entrypoints) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains("import 'package:$name/$name.dart'"),
          reason: '$path must import $name',
        );
        if (name == 'ruflet') continue;
        final alias = _importAlias(source, name);
        expect(alias, isNotNull, reason: '$path must import $name as an alias');
        expect(
          RegExp(
            '^\\s*$alias\\.Extension\\(\\),\\s*\$',
            multiLine: true,
          ).hasMatch(source),
          isTrue,
          reason: '$path must register $alias.Extension()',
        );
      }
    }
  });

  test('opt-in packages are vendored but never referenced', () {
    final root = _yaml('pubspec.yaml');
    final referencedDeps = <String>{};
    for (final name in referencedPackages) {
      referencedDeps.addAll(
        _section(
          _yaml('ruflet_packages/$name/pubspec.yaml'),
          'dependencies',
        ).keys,
      );
    }
    for (final name in optInPackages) {
      expect(Directory('ruflet_packages/$name').existsSync(), isTrue);
      for (final section in ['dependencies', 'dependency_overrides']) {
        expect(
          _section(root, section).containsKey(name),
          isFalse,
          reason: 'pubspec.yaml $section must not list $name',
        );
      }
      for (final path in entrypoints) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('package:$name/')),
          reason: '$path must not import $name',
        );
        expect(
          source,
          isNot(contains('$name.Extension(')),
          reason: '$path must not register $name',
        );
      }
      // Nor may the plugins only this package brings be registered.
      // `flutter test` resolves packages first, which rewrites these files
      // from the resolved plugin set (as every build does), so this checks
      // that set rather than a hand edit of the committed copy.
      final ownDeps =
          _section(_yaml('ruflet_packages/$name/pubspec.yaml'), 'dependencies')
              .keys
              .where(
                (dep) =>
                    dep != 'flutter' &&
                    dep != 'ruflet' &&
                    !referencedDeps.contains(dep),
              )
              .toList();
      expect(ownDeps, isNotEmpty);
      for (final path in committedRegistrants) {
        final source = File(path).readAsStringSync();
        for (final dep in ownDeps) {
          expect(
            source,
            isNot(contains(dep)),
            reason: '$path must not register $dep, which only $name uses',
          );
        }
      }
    }
  });

  test('a package released gems do not know registers after the list\'s '
      'fat-client block', () {
    for (final path in entrypoints) {
      final lines = File(path).readAsLinesSync();
      final listStart = lines.indexWhere(
        (line) => line.contains('final extensions = <RufletExtension>['),
      );
      expect(listStart, isNot(-1), reason: '$path must build the list');
      final listEnd = lines.indexWhere((line) => line.trim() == '];', listStart);
      expect(listEnd, greaterThan(listStart));

      List<int> marker(String text) => [
        for (var i = listStart + 1; i < listEnd; i++)
          if (lines[i].trim() == text) i,
      ];
      final starts = marker(fatClientStart);
      final ends = marker(fatClientEnd);
      expect(starts, hasLength(1), reason: '$path list needs one $fatClientStart');
      expect(ends, hasLength(1), reason: '$path list needs one $fatClientEnd');
      final end = ends.single;
      expect(starts.single, lessThan(end));

      final packages = _importedPackagesByAlias(lines.join('\n'));
      final registration = RegExp(r'^\s*([A-Za-z0-9_]+)\.Extension\(\),\s*$');
      for (var i = listStart + 1; i < listEnd; i++) {
        final match = registration.firstMatch(lines[i]);
        if (match == null) continue;
        final package = packages[match.group(1)];
        expect(package, isNotNull,
            reason: '$path line ${i + 1} registers an alias it never imports');
        if (releasedGemPackages.contains(package)) continue;
        expect(i, greaterThan(end),
            reason: '$path registers $package, which released gems do not '
                'know, above $fatClientEnd');
      }
    }
  });
}
