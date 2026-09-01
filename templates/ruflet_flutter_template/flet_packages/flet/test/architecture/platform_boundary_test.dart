import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final coreFile = File('lib/src/flet_core_extension.dart');
  final coreSource = coreFile.readAsStringSync();

  test('the engine packages assets for both platform icon families', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('cupertino_icons:'));
  });

  test('the canonical control registry has no design-specific protocol cases',
      () {
    expect(coreSource, isNot(contains('case "Cupertino')));
    expect(coreSource, isNot(contains('case "Material')));
  });

  test('every canonical registry entry point is design-system neutral', () {
    final imports = RegExp(r"^import 'controls/([^']+)';$", multiLine: true)
        .allMatches(coreSource)
        .map((match) => match.group(1)!)
        .toList();

    expect(imports, isNotEmpty);
    final coupled = <String>[];
    for (final path in imports) {
      final source = File('lib/src/controls/$path').readAsStringSync();
      if (source.contains('package:flutter/material.dart') ||
          source.contains('package:flutter/cupertino.dart')) {
        coupled.add(path);
      }
    }
    expect(
      coupled,
      isEmpty,
      reason:
          'Registry entry points must delegate to separate renderers or use '
          'only design-neutral Flutter widgets.',
    );
  });
}
