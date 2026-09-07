import 'package:flutter_test/flutter_test.dart';

import 'platform_dependency_graph.dart';

const entry = 'lib/src/entry.dart';
const renderer = 'lib/src/widgets/platform_control_renderer.dart';
const lazyRenderer = '''
import 'package:flutter/widgets.dart';
import '../models/page_design.dart';
import 'platform_design.dart';
class PlatformControlRenderer extends StatelessWidget {
  final WidgetBuilder material;
  final WidgetBuilder cupertino;
  const PlatformControlRenderer({super.key, required this.material, required this.cupertino});
  Widget build(BuildContext context) {
    return effectivePageDesign(context) == PageDesign.cupertino
      ? cupertino(context) : material(context);
  }
}
''';

PlatformDependencyGraph fixture(String source,
        [Map<String, String> additions = const {}]) =>
    PlatformDependencyGraph({
      entry: source,
      renderer: lazyRenderer,
      'lib/src/models/page_design.dart':
          'enum PageDesign { material, cupertino }',
      'lib/src/widgets/platform_design.dart': '''
        import '../models/page_design.dart';
        PageDesign effectivePageDesign(dynamic context) => context.design;
      ''',
      'lib/src/material.dart': '''
        import 'package:flutter/material.dart';
        class MaterialControl {}
        dynamic materialTheme() => ThemeData();
      ''',
      'lib/src/cupertino.dart': '''
        import 'package:flutter/cupertino.dart';
        class CupertinoControl {}
      ''',
      ...additions,
    });

const dispatchImports = '''
import 'widgets/platform_control_renderer.dart';
import 'material.dart';
import 'cupertino.dart';
''';
const dispatch = '''
dynamic build() => PlatformControlRenderer(
  material: (_) => MaterialControl(),
  cupertino: (_) => CupertinoControl(),
);
''';

void main() {
  test('canonical lazy dispatcher is verified rather than trusted by filename',
      () {
    final graph = fixture('$dispatchImports$dispatch');
    expect(graph.canonicalDispatcherIsLazy, isTrue);
    for (final design in Design.values) {
      expect(graph.violations([entry], design), isEmpty);
    }
    expect(graph.prunedBranches, hasLength(2));
  });

  test('eager work added to the dispatcher implementation invalidates pruning',
      () {
    final graph = fixture('$dispatchImports$dispatch', {
      renderer: lazyRenderer.replaceFirst('return effectivePageDesign',
          'material(context); return effectivePageDesign'),
    });
    expect(graph.canonicalDispatcherIsLazy, isFalse);
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('an eager theme conversion before the lazy branch is not hidden', () {
    final graph = fixture('''
      $dispatchImports
      final eagerlyConverted = materialTheme();
      $dispatch
    ''');
    expect(graph.violations([entry], Design.cupertino).single,
        contains('lib/src/material.dart'));
  });

  test('type-only references outside the branch are conservatively retained',
      () {
    final graph = fixture('''
      $dispatchImports
      MaterialControl? cached;
      $dispatch
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('metadata outside the branch is not hidden', () {
    final graph = fixture('''
      $dispatchImports
      @MaterialControl()
      class Annotated {}
      $dispatch
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('extension method uses outside a branch keep the imported helper edge',
      () {
    final graph = fixture('''
      $dispatchImports
      dynamic buildWithTheme(dynamic control) {
        control.materialTheme();
        return PlatformControlRenderer(
          material: (_) => MaterialControl(),
          cupertino: (_) => CupertinoControl());
      }
    ''', {
      'lib/src/material.dart': '''
        import 'package:flutter/material.dart';
        class MaterialControl {}
        extension on Object { dynamic materialTheme() => ThemeData(); }
      ''',
    });
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('prefix-qualified renderer references can prove lazy branch membership',
      () {
    final graph = fixture('''
      import 'widgets/platform_control_renderer.dart';
      import 'material.dart' as m;
      import 'cupertino.dart' as c;
      dynamic build() => PlatformControlRenderer(
        material: (_) => m.MaterialControl(),
        cupertino: (_) => c.CupertinoControl());
    ''');
    for (final design in Design.values) {
      expect(graph.violations([entry], design), isEmpty);
    }
  });

  test('non-lazy arguments are never a dispatcher boundary', () {
    final graph = fixture('''
      $dispatchImports
      dynamic build() => PlatformControlRenderer(
        material: MaterialControl(), cupertino: CupertinoControl());
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('same-name user function does not impersonate the trusted dispatcher',
      () {
    final graph = fixture('''
      $dispatchImports
      dynamic PlatformControlRenderer({material, cupertino}) => material(null);
      $dispatch
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test(
      'comments and string contents cannot fake dispatch boundaries or imports',
      () {
    final graph = fixture('''
      import 'material.dart';
      // PlatformControlRenderer(cupertino: (_) => anything);
      const documentation = "import 'package:flutter/cupertino.dart';";
      dynamic build() => MaterialControl();
    ''');
    expect(graph.mixedDesignLibraries, isEmpty);
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('exhaustive PageDesign switch on a typed input is a lazy boundary', () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build(PageDesign design) => switch (design) {
        PageDesign.material => MaterialControl(),
        PageDesign.cupertino => CupertinoControl(),
      };
    ''');
    for (final design in Design.values) {
      expect(graph.violations([entry], design), isEmpty);
    }
  });

  test('PageDesign switch using the canonical context selector is lazy', () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'widgets/platform_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build(dynamic context) => switch (effectivePageDesign(context)) {
        PageDesign.material => MaterialControl(),
        PageDesign.cupertino => CupertinoControl(),
      };
    ''');
    expect(graph.violations([entry], Design.cupertino), isEmpty);
  });

  test('a constant design switch does not establish native selection', () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build() => switch (PageDesign.material) {
        PageDesign.material => MaterialControl(),
        PageDesign.cupertino => CupertinoControl(),
      };
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('guarded or incomplete design switches are not proven boundaries', () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build(PageDesign design) => switch (design) {
        PageDesign.material when true => MaterialControl(),
        _ => CupertinoControl(),
      };
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('exhaustive returning switch statements are proven design boundaries',
      () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build(PageDesign design) {
        switch (design) {
          case PageDesign.material: return MaterialControl();
          case PageDesign.cupertino: return CupertinoControl();
        }
      }
    ''');
    for (final design in Design.values) {
      expect(graph.violations([entry], design), isEmpty);
    }
  });

  test('fall-through or labeled switch statements are not pruned', () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build(PageDesign design) {
        switch (design) {
          case PageDesign.cupertino:
          case PageDesign.material: return MaterialControl();
        }
      }
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('assigning a fixed design to the selector cannot hide the other branch',
      () {
    final graph = fixture('''
      import 'models/page_design.dart';
      import 'material.dart';
      import 'cupertino.dart';
      dynamic build(PageDesign design) {
        design = PageDesign.material;
        return switch (design) {
          PageDesign.material => MaterialControl(),
          PageDesign.cupertino => CupertinoControl(),
        };
      }
    ''');
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('generic helper imports and transitive exports are not exempted', () {
    final graph = fixture("import 'shared.dart';", {
      'lib/src/shared.dart': "export 'bridge.dart';",
      'lib/src/bridge.dart': "import 'material.dart';",
    });
    expect(
        graph.violations([entry], Design.cupertino).single,
        contains(
            'shared.dart -> lib/src/bridge.dart -> lib/src/material.dart'));
  });

  test('conditional export alternatives are all traversed', () {
    final graph =
        fixture("export 'neutral.dart' if (dart.library.io) 'material.dart';", {
      'lib/src/neutral.dart': 'class Neutral {}',
    });
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('local package imports follow the same graph as relative imports', () {
    final graph = fixture("import 'package:ruflet/src/material.dart';");
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('a neutral registry cycle is traversed, not blanket-whitelisted', () {
    final graph = fixture('$dispatchImports$dispatch', {
      'lib/src/cupertino.dart': '''
        import 'package:flutter/cupertino.dart';
        import 'backend.dart';
        class CupertinoControl {}
      ''',
      'lib/src/backend.dart': "import 'entry.dart'; import 'hidden.dart';",
      'lib/src/hidden.dart': "import 'material.dart';",
    });
    expect(
        graph.violations([entry], Design.cupertino).single,
        contains(
            'backend.dart -> lib/src/hidden.dart -> lib/src/material.dart'));
  });

  test('exports used exclusively by the opposite renderer may be pruned', () {
    final graph = fixture('''
      import 'widgets/platform_control_renderer.dart';
      import 'barrel.dart' show MaterialControl;
      import 'cupertino.dart';
      $dispatch
    ''', {
      'lib/src/barrel.dart': "export 'material.dart';",
    });
    expect(graph.violations([entry], Design.cupertino), isEmpty);
  });

  test('only structurally validated icon data libraries cross design graphs',
      () {
    final graph = fixture("import 'arbitrary_name.dart';", {
      'lib/src/arbitrary_name.dart': '''
        import 'package:flutter/material.dart';
        List<IconData> iconValues = [Icons.add, Icons.close];
      ''',
    });
    expect(graph.violations([entry], Design.cupertino), isEmpty);
    expect(graph.iconDataLibraries, contains('lib/src/arbitrary_name.dart'));
  });

  test('an icon filename cannot hide a constructor or executable helper', () {
    for (final declaration in [
      'List<IconData> icons = [ThemeData()];',
      'List<IconData> icons = [Icons.add]; dynamic theme() => ThemeData();',
    ]) {
      final graph = fixture("import 'material_icons.dart';", {
        'lib/src/material_icons.dart':
            "import 'package:flutter/material.dart'; $declaration",
      });
      expect(graph.violations([entry], Design.cupertino), isNotEmpty);
    }
  });

  test('mixed imports include show-only and unused design dependencies', () {
    final graph = fixture('''
      import 'package:flutter/material.dart' show ThemeData;
      import 'package:flutter/cupertino.dart' show CupertinoThemeData;
    ''');
    expect(graph.mixedDesignLibraries, contains(entry));
  });

  test('direct SDK implementation imports cannot evade design classification',
      () {
    final graph = fixture('''
      import 'package:flutter/src/material/theme.dart';
      import 'package:flutter/cupertino.dart';
    ''');
    expect(graph.mixedDesignLibraries, contains(entry));
    expect(graph.violations([entry], Design.cupertino), isNotEmpty);
  });

  test('unresolved owned dependencies fail closed instead of disappearing', () {
    final graph = fixture("import 'missing.dart';");
    expect(graph.violations([entry], Design.cupertino).single,
        contains('missing owned source'));
  });

  test('third-party scope is explicitly reported without claiming it proved',
      () {
    final graph = fixture("import 'package:third_party/renderer.dart';");
    graph.violations([entry], Design.cupertino);
    expect(graph.externalDependencies, {'package:third_party/renderer.dart'});
  });
}
