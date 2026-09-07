import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

import 'platform_dependency_graph.dart';

void main() {
  final coreFile = File('lib/src/ruflet_core_extension.dart');
  final coreSource = coreFile.readAsStringSync();
  final graph = PlatformDependencyGraph.read(Directory('lib'));

  test('the dispatcher itself calls exactly one lazy design builder', () {
    expect(graph.canonicalDispatcherIsLazy, isTrue);
  });

  test('the public Flutter design exports expose icon data only', () {
    final exports = graph.units['lib/ruflet.dart']!.directives
        .whereType<ExportDirective>()
        .where((directive) => [
              'package:flutter/material.dart',
              'package:flutter/cupertino.dart',
            ].contains(directive.uri.stringValue));
    expect(exports, hasLength(2));
    for (final directive in exports) {
      expect(directive.configurations, isEmpty);
      expect(directive.combinators, hasLength(1));
      expect(directive.combinators.single, isA<ShowCombinator>());
      final show = directive.combinators.single as ShowCombinator;
      expect(show.shownNames.map((name) => name.name), [
        directive.uri.stringValue!.contains('/cupertino.dart')
            ? 'CupertinoIcons'
            : 'Icons',
      ]);
    }
  });

  test('no owned implementation mixes Material and Cupertino imports/exports',
      () {
    expect(
        graph.mixedDesignLibraries.where((path) => path.startsWith('lib/src/')),
        isEmpty);
  });

  for (final design in Design.values) {
    test('${design.name} generic style parsers have neutral transitive helpers',
        () {
      // Contract roots, not exemptions: even an unused parser added to a design
      // library will fail here instead of being classified as a native renderer.
      const generic = [
        'alignment',
        'animations',
        'auto_complete',
        'autofill',
        'borders',
        'box',
        'colors',
        'color_palette',
        'dismissible',
        'drawing',
        'edge_insets',
        'enums',
        'geometry',
        'gradient',
        'icons',
        'images',
        'input',
        'layout',
        'mouse',
        'numbers',
        'overlay_style',
        'platform_theme',
        'responsive',
        'style_theme',
        'text',
        'textfield',
        'time',
        'transforms',
        'widget_state',
      ];
      expect(
          graph.violations(
              generic.map((name) => 'lib/src/utils/$name.dart'), design),
          isEmpty);
    });

    test(
        '${design.name} registry and native renderers keep transitive boundaries',
        () {
      final roots = <String>{
        'lib/src/ruflet_core_extension.dart',
        for (final path in graph.units.keys)
          if (path.startsWith('lib/src/') &&
              graph.directDesigns(path).contains(design) &&
              !graph.isIconDataLibrary(path))
            path,
        'lib/src/widgets/platform_app.dart',
        'lib/src/widgets/platform_page_scaffold.dart',
        'lib/src/widgets/platform_startup_app.dart',
      };
      expect(graph.violations(roots, design), isEmpty,
          reason: 'Only AST-proven opposite lazy dispatcher edges may be '
              'skipped; shared helpers, exports and registry cycles stay in scope.');
      expect(graph.prunedBranches, isNotEmpty);
      expect(
          graph.iconDataLibraries,
          containsAll([
            'lib/src/utils/material_icons.dart',
            'lib/src/utils/cupertino_icons.dart',
          ]));
    });
  }

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
