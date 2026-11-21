// The control-core contract: one design-neutral core per migrated control
// (lib/src/core), thin Material/Cupertino skins, and tests that make "both
// designs read the same keys and fire the same events" structural. Every
// migrated control is one entry in core_manifest.dart.
//
// C1 skin isolation: a skin imports no Control-facing library (the Control
//    model and extensions, ControlWidget, base_controls.dart, the public
//    barrel), imports extension-on-Control libraries only with a `show` list
//    of other declarations, and never names Control, dynamic, triggerEvent,
//    updateProperties, invoke listeners, LayoutControl or BaseControl.
//    `flutter analyze` (fatal warnings) covers the @protected core members.
//    Helper skin libraries are held to the same rule.
// C1e entry shape: the registry entry (adaptive_*.dart), the only place
//    outside the kernel that holds the Control, builds a CoreHost whose
//    `create:` is a plain constructor tear-off, whose PlatformControlRenderer
//    closures build skins with only `core:` and `key:` (choosing between
//    skins only on the core), and it uses `control` only as
//    CoreHost(control:), inside the host key (a ValueKey built only from
//    control.id and control.canonicalType) and inside debugPrint. A sized
//    entry (the AppBar: a scaffold reads its PreferredSizeWidget before
//    building it) instead creates its core in a static `resolve` that
//    switches on PageDesign to a skin built with only `core:`, and that skin
//    hosts the core with CoreHost.adopt.
// C2 core purity: lib/src/core/** and every manifest core import no design
//    and reach neither design through the platform dependency graph.
// C2b core isolation: every manifest core and non-kernel lib/src/core library
//    follows C1, and core constructors only forward `super.` parameters, so
//    no core can keep the Control and hand it to a skin. Only the kernel
//    library (control_core.dart and its parts) holds a Control, and no
//    member of a kernel class hands one out (a skin can find its ancestor
//    CoreHost or build one with CoreHost.adopt). Cores have no public
//    mutable fields or setters, so nothing can write into them.
// C3 spec == Ruby: each ControlSpec declares exactly the keywords Ruby can
//    send for its wire type (test/contract/ruflet_control_surface.json, from
//    the ruflet repo's tools/control_surface.rb; refresh with
//    `ruby tool/sync_ruby_surface.rb --ruby <ruflet checkout>`), minus
//    framework keys and the keys its layout wrapper applies; single-skin
//    entries carry a reason.
// C4 skin consumption: a skin-consumed field is referenced by every skin it
//    lists and by no other; a field the spec declares core-consumed
//    (PropConsumer.core) is referenced by the core and by no skin.
// C5 lifecycle: exactly one invoke listener on the Control (every listener
//    counted through CoreHost's debug census), declared methods answer,
//    undeclared ones fail fast, an in-place replacement moves the listener,
//    unmount removes it.
// C6 completeness: rendering every declared key parses every declared key.
// C7 parity: a script that taps the native widget (the skins' own gesture
//    wiring) and makes the core fire every core-sourced event records the
//    same messages to Ruby and the same semantics on iOS and Android.
// C8 legacy ratchet: legacy_renderers.txt lists design files still on the old
//    Control pattern and only shrinks. Report-only until the open PR queue
//    drains (enforceLegacyRatchet).
//
// The static rules are pure functions in test/support/core_contract.dart and
// the runtime rules return their problems, so the "QA mutations" group proves
// each rule rejects the deliberately bad skins and cores QA wrote against
// #81; the runtime rules also run against a test-only probe core.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart' show RufletExtension;
import 'package:ruflet/src/core/control_spec.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';
import '../support/core_contract.dart';
import '../support/core_probe.dart';
import 'core_manifest.dart';
import 'platform_dependency_graph.dart';

/// DC-6: C8 reports until the open PR queue drains, then enforces.
const enforceLegacyRatchet = false;

void main() {
  final graph = PlatformDependencyGraph.read(Directory('lib'));
  final surface =
      RubySurface.read(File('test/contract/ruflet_control_surface.json'));
  final kernel = [
    for (final path in graph.units.keys)
      if (path.startsWith('lib/src/core/')) path
  ]..sort();
  final runtimeEntries = [...migratedControls, probeEntry()];

  group('manifest', () {
    test('the Ruby surface copy is the v2 export', () {
      expect(surface.contractVersion, 2);
      expect(surface.keywords('Switch'), contains('value'));
    });

    test('the common layout keys are the ones the layout wrappers read', () {
      final source = [
        'lib/src/controls/base_controls.dart',
        'lib/src/widgets/platform_badge.dart',
        'lib/src/widgets/platform_tooltip.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      for (final key in layoutControlKeys) {
        expect(source, contains('"$key"'), reason: key);
      }
      expect(layoutControlKeys.containsAll(baseControlKeys), isTrue);
    });

    for (final entry in migratedControls) {
      test('${entry.wireType} entry points at real libraries', () {
        expect(entry.spec.wireType, entry.wireType);
        for (final path in [entry.entry, entry.core, ...entry.skins.values]) {
          expect(graph.units.containsKey(path), isTrue, reason: path);
        }
        expect(entry.skins.keys.toSet(), Skin.values.toSet());
        expect(graph.directDesigns(entry.skins[Skin.material]!),
            {Design.material});
        expect(graph.directDesigns(entry.skins[Skin.cupertino]!),
            {Design.cupertino});
        expect(graph.directDesigns(entry.entry), isEmpty);
      });
    }

    for (final entry in migratedControls) {
      test('${entry.wireType} parity script taps the native widget', () {
        expect(entry.parityScript.map((s) => s.name), contains('tap native'));
        expect(entry.nativeWidgets.keys.toSet(), Skin.values.toSet());
      });
    }

    test('wire types are migrated once', () {
      final types = migratedControls.map((e) => e.wireType).toList();
      expect(types.toSet().length, types.length);
    });
  });

  group('C1 skin isolation', () {
    for (final entry in migratedControls) {
      for (final skin in entry.skins.entries) {
        test('${entry.wireType} ${skin.key.name} skin never touches Control',
            () => expect(skinIsolationProblems(graph, skin.value), isEmpty));
        for (final helper in entry.helpers[skin.key] ?? const <String>[]) {
          test(
              '${entry.wireType} ${skin.key.name} helper $helper never '
              'touches Control',
              () => expect(skinIsolationProblems(graph, helper), isEmpty));
        }
      }
    }

    test('catches Control imports, unshown extensions and banned tokens', () {
      final fixture = PlatformDependencyGraph({
        'lib/src/models/control.dart': 'class Control {}',
        'lib/src/utils/parsers.dart': '''
import '../models/control.dart';
Color? parseThing(String v) => null;
extension ThingParsers on Control { int get thing => 1; }
''',
        'lib/src/utils/barrel.dart': "export 'parsers.dart';",
        'lib/src/controls/bad_skin.dart': '''
import 'package:flutter/material.dart';
import '../models/control.dart';
import '../utils/barrel.dart';
import '../utils/parsers.dart' show ThingParsers;
class BadSkin { void f(c) { c.triggerEvent("x"); LayoutControl(); } }
''',
        'lib/src/controls/good_skin.dart': '''
import 'package:flutter/material.dart';
import '../utils/parsers.dart' show parseThing;
// triggerEvent in a comment is fine
class GoodSkin { final s = "updateProperties in a string is fine"; }
''',
      });
      final problems =
          skinIsolationProblems(fixture, 'lib/src/controls/bad_skin.dart');
      expect(
          problems.join('\n'),
          allOf(
            contains('imports lib/src/models/control.dart'),
            contains(
                'lib/src/utils/barrel.dart, which declares extensions on Control'),
            contains('shows Control extensions [ThingParsers]'),
            contains('uses triggerEvent'),
            contains('uses LayoutControl'),
          ));
      expect(skinIsolationProblems(fixture, 'lib/src/controls/good_skin.dart'),
          isEmpty);
    });
  });

  group('C1e entry shape', () {
    for (final entry in {for (final e in migratedControls) e.entry}) {
      test('$entry has the canonical registry-entry shape',
          () => expect(entryShapeProblems(graph, entry), isEmpty));
    }

    PlatformDependencyGraph entryFixture(String source) =>
        PlatformDependencyGraph({'lib/src/controls/adaptive_x.dart': source});
    List<String> shape(String source) => entryShapeProblems(
        entryFixture(source), 'lib/src/controls/adaptive_x.dart');

    // The three approved entries (#84, #86, #87), verbatim.
    const approved = {
      'Switch': r'''
import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_switch.dart';
import 'switch.dart';
import 'switch_core.dart';

class AdaptiveSwitchControl extends StatelessWidget {
  final Control control;

  const AdaptiveSwitchControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveSwitch build: ${control.id}");

    return CoreHost<SwitchCore>(
      // The key the legacy skins used, so state survives parent rebuilds.
      key: ValueKey("control_${control.id}"),
      control: control,
      create: SwitchCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialSwitchSkin(core: core),
        cupertino: (_) => CupertinoSwitchSkin(core: core),
      ),
    );
  }
}
''',
      'Checkbox': r'''
import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'checkbox.dart';
import 'checkbox_core.dart';
import 'cupertino_checkbox.dart';

class AdaptiveCheckboxControl extends StatelessWidget {
  final Control control;

  const AdaptiveCheckboxControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveCheckboxControl build: ${control.id}");

    return CoreHost<CheckboxCore>(
      // The key the legacy skins used, so state survives parent rebuilds.
      key: ValueKey("control_${control.id}"),
      control: control,
      create: CheckboxCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialCheckboxSkin(core: core),
        cupertino: (_) => CupertinoCheckboxSkin(core: core),
      ),
    );
  }
}
''',
      'Radio': r'''
import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_radio.dart';
import 'radio.dart';
import 'radio_core.dart';

class AdaptiveRadioControl extends StatelessWidget {
  final Control control;

  const AdaptiveRadioControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveRadioControl build: ${control.id}");

    return CoreHost<RadioCore>(
      // The key the legacy skins used, so state survives parent rebuilds.
      key: ValueKey("control_${control.id}"),
      control: control,
      create: RadioCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialRadioSkin(core: core),
        cupertino: (_) => CupertinoRadioSkin(core: core),
      ),
    );
  }
}
''',
    };
    for (final MapEntry(key: name, value: source) in approved.entries) {
      test('the approved $name entry passes',
          () => expect(shape(source), isEmpty));
    }

    final canonical = approved['Switch']!;

    test('a skin chosen on the core passes', () {
      expect(
          shape(canonical.replaceFirst(
              'cupertino: (_) => CupertinoSwitchSkin(core: core),',
              'cupertino: (_) => core.inAlertDialog '
                  '? CupertinoDialogSkin(core: core) '
                  ': CupertinoSwitchSkin(core: core, key: const ValueKey(1)),')),
          isEmpty);
    });

    test('N1: an entry injects wire data into the core (C1e)', () {
      final problems = shape(canonical.replaceFirst('create: SwitchCore.new,',
          'create: (c) => SwitchCore(c)..qaLeak = c.properties,'));
      expect(
          problems,
          contains(
              contains('CoreHost(create:) must be a constructor tear-off')));
    });

    test('N4: an entry passes a raw wire value to a skin (C1e)', () {
      final problems = shape(canonical.replaceFirst(
          'material: (_) => MaterialSwitchSkin(core: core),',
          'material: (_) => MaterialSwitchSkin(core: core, '
              "qaExtra: control.properties['tooltip']),"));
      expect(
          problems.join('\n'),
          allOf(
            contains(
                'the material closure must build its skin with only core:'),
            contains('uses control outside CoreHost(control:)'),
          ));
    });

    test('N7: an entry puts wire data in the host key (C1e)', () {
      final problems = shape(canonical.replaceFirst(
          r'key: ValueKey("control_${control.id}"),',
          "key: ValueKey(control.properties['label']),"));
      expect(
          problems.join('\n'),
          allOf(
            contains('CoreHost(key:) may only be a ValueKey of a string'),
            contains('uses control outside CoreHost(control:)'),
          ));
      expect(
          shape(canonical.replaceFirst(
              r'key: ValueKey("control_${control.id}"),',
              r'key: ValueKey("control_${control.canonicalType}_${control.id}"),')),
          isEmpty);
    });

    test('an entry may not choose skins or cores on the Control (C1e)', () {
      expect(
          shape(canonical.replaceFirst(
              'cupertino: (_) => CupertinoSwitchSkin(core: core),',
              'cupertino: (_) => control.parent == null '
                  '? CupertinoSwitchSkin(core: core) '
                  ': CupertinoOtherSkin(core: core),')),
          contains(contains('uses control outside CoreHost(control:)')));
      expect(
          shape(canonical.replaceFirst('    return CoreHost<SwitchCore>(',
              '    final type = control.type;\n    return CoreHost<SwitchCore>(')),
          contains(contains('uses control outside CoreHost(control:)')));
    });

    // A sized entry: a scaffold sizes the AppBar before building it, so the
    // skin is the outermost widget and hosts the core (CoreHost.adopt).
    const sized = r'''
import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/page_design.dart';
import '../widgets/platform_design.dart';
import 'app_bar.dart';
import 'app_bar_core.dart';
import 'cupertino_app_bar.dart';

class AdaptiveAppBarControl extends StatelessWidget {
  final Control control;

  const AdaptiveAppBarControl({super.key, required this.control});

  static PreferredSizeWidget resolve({
    required Control control,
    required PageDesign design,
  }) {
    final core = AppBarCore(control);
    return switch (design) {
      PageDesign.cupertino => CupertinoAppBarSkin(core: core),
      PageDesign.material => MaterialAppBarSkin(core: core),
    };
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveAppBarControl build: ${control.id}");

    return resolve(control: control, design: effectivePageDesign(context));
  }
}
''';

    test('a sized entry (the AppBar shape) passes',
        () => expect(shape(sized), isEmpty));

    test('N1 on a sized entry: wire data injected into the core (C1e)', () {
      final problems = shape(sized.replaceFirst(
          'final core = AppBarCore(control);',
          'final core = AppBarCore(control)..qaLeak = control.properties;'));
      expect(
          problems.join('\n'),
          allOf(
            contains('resolve must be `final core = XCore(control);`'),
            contains('uses control outside CoreHost(control:)'),
          ));
    });

    test('N4 on a sized entry: a raw wire value passed to a skin (C1e)', () {
      final problems = shape(sized.replaceFirst(
          'PageDesign.material => MaterialAppBarSkin(core: core),',
          'PageDesign.material => MaterialAppBarSkin(core: core, '
              "qaExtra: control.properties['tooltip']),"));
      expect(
          problems.join('\n'),
          allOf(
            contains('the PageDesign.material arm must build its skin'),
            contains('uses control outside CoreHost(control:)'),
          ));
    });

    test('a sized entry switches exhaustively on PageDesign (C1e)', () {
      expect(
          shape(sized.replaceFirst(
              RegExp(r'return switch \(design\) \{[^}]*\};', dotAll: true),
              'return design == PageDesign.cupertino '
              '? CupertinoAppBarSkin(core: core) '
              ': MaterialAppBarSkin(core: core);')),
          contains(contains('resolve must return an exhaustive switch')));
      expect(
          shape(sized.replaceFirst('final core = AppBarCore(control);',
              'final core = AppBarCore(control);\n    final type = control.type;')),
          contains(contains('resolve must be `final core = XCore(control);`')));
    });

    test('an entry with neither a CoreHost nor a sized resolve fails (C1e)',
        () {
      expect(shape(sized.replaceAll('resolve', 'pick')),
          contains(contains('builds no CoreHost')));
    });

    test('a skin must get the builder\'s core, nothing else (C1e)', () {
      expect(
          shape(canonical.replaceFirst(
              'material: (_) => MaterialSwitchSkin(core: core),',
              'material: (_) => MaterialSwitchSkin(core: other),')),
          contains(contains('the material closure must build its skin')));
      expect(
          shape(canonical.replaceFirst(
              'material: (_) => MaterialSwitchSkin(core: core),',
              'material: (_) => MaterialSwitchSkin(core: core, extra: 1),')),
          contains(contains('the material closure must build its skin')));
    });
  });

  group('C2 core purity', () {
    final cores = {...kernel, for (final e in migratedControls) e.core};

    test('the kernel exists', () {
      expect(
          kernel,
          containsAll([
            'lib/src/core/control_core.dart',
            'lib/src/core/control_spec.dart',
            'lib/src/core/toggle_label.dart',
          ]));
    });

    for (final core in cores) {
      test('$core imports no design and reaches neither design', () {
        expect(graph.directDesigns(core), isEmpty);
        for (final design in Design.values) {
          expect(graph.violations([core], design), isEmpty,
              reason: '${design.name} traversal from $core');
        }
      });
    }
  });

  group('C2b core isolation', () {
    final cores = {
      for (final path in kernel)
        if (!isKernelLibrary(graph, path)) path,
      for (final e in migratedControls) e.core,
    };

    test('only the kernel library may hold a Control', () {
      expect(
          kernel.where((path) => isKernelLibrary(graph, path)),
          unorderedEquals([
            'lib/src/core/control_core.dart',
            'lib/src/core/control_events.dart',
            'lib/src/core/core_host.dart',
            'lib/src/core/prop_reader.dart',
          ]));
    });

    test('N5/N6: no kernel member hands out the Control',
        () => expect(kernelExposureProblems(graph), isEmpty));

    test('N5/N6: a public Control field or getter on a kernel class fails', () {
      final leaky = PlatformDependencyGraph({
        'lib/src/core/control_core.dart': '''
class Control {}
class CoreHost {
  CoreHost({required Control control}) : _control = control, owner = control;
  final Control _control;
  final Control owner;
  final Object? Function(Control control) create = _make;
  Control get control => _control;
  int get debugControlId => 1;
  static int count(Control control) => 0;
}
Object? _make(Control c) => null;
''',
      });
      expect(
          kernelExposureProblems(leaky),
          unorderedEquals([
            contains('CoreHost.owner exposes a Control'),
            contains('CoreHost.create exposes a Control'),
            contains('CoreHost.control exposes a Control'),
          ]));
    });

    for (final core in cores) {
      test('$core cannot keep or hand out the Control',
          () => expect(coreIsolationProblems(graph, core), isEmpty));
    }
  });

  group('C3 spec == Ruby', () {
    for (final entry in migratedControls) {
      test('${entry.wireType} declares exactly the Ruby keywords',
          () => expect(specRubyProblems(entry.spec, surface), isEmpty));
    }

    test('catches missing, extra, layout and unexplained single-skin keys', () {
      final fixture = RubySurface({
        'contract_version': 2,
        'common_attributes': ['flip', 'transform'],
        'wire_types': {
          'Toggle': {
            'keywords': [
              'value',
              'label',
              'width',
              'height',
              'margin',
              'key',
              'data',
              'disabled',
              'on_change',
              'hover_color'
            ],
          },
          'Bare': {
            'keywords': ['value', 'margin']
          },
        },
      });
      const good = ControlSpec(wireType: 'Toggle', props: [
        PropSpec('value', PropType.boolean, 'value'),
        PropSpec('label', PropType.textOrWidget, 'label'),
        PropSpec('hover_color', PropType.color, 'hoverColor',
            skins: {Skin.material}, reason: 'no hover ink on iOS'),
      ], events: [
        EventSpec('change', source: EventSource.core),
      ]);
      expect(specRubyProblems(good, fixture), isEmpty);

      const bad = ControlSpec(wireType: 'Toggle', props: [
        PropSpec('value', PropType.boolean, 'value'),
        PropSpec('lable', PropType.textOrWidget, 'label'),
        PropSpec('hover_color', PropType.color, 'hoverColor',
            skins: {Skin.material}),
      ], events: [
        EventSpec('click'),
      ], ownedLayoutKeys: {
        'width'
      });
      expect(
          specRubyProblems(bad, fixture).join('\n'),
          allOf(
            contains(
                'Ruby sends [label, on_change, width] but the spec does not '
                'declare'),
            contains('declares [lable, on_click]'),
            contains('owned layout keys [width] are not declared'),
            contains('hover_color: single-skin prop without a reason'),
            contains('on_click: a skin-sourced event needs a core callback'),
          ));

      const shared = ControlSpec(wireType: 'Toggle', props: [
        PropSpec('value', PropType.boolean, 'value'),
        PropSpec('label', PropType.textOrWidget, 'label'),
        PropSpec('width', PropType.number, 'width'),
        PropSpec('height', PropType.number, 'height'),
        PropSpec('hover_color', PropType.color, 'hoverColor',
            skins: {Skin.material}, reason: 'no hover ink on iOS'),
      ], events: [
        EventSpec('change', source: EventSource.core),
      ], sharedLayoutKeys: {
        'width',
        'height'
      });
      expect(specRubyProblems(shared, fixture), isEmpty);
      const sharedBad = ControlSpec(wireType: 'Toggle', props: [
        PropSpec('value', PropType.boolean, 'value'),
        PropSpec('label', PropType.textOrWidget, 'label'),
        PropSpec('hover_color', PropType.color, 'hoverColor',
            skins: {Skin.material}, reason: 'no hover ink on iOS'),
        PropSpec('width', PropType.number, 'width'),
      ], events: [
        EventSpec('change', source: EventSource.core),
      ], ownedLayoutKeys: {
        'width'
      }, sharedLayoutKeys: {
        'width',
        'height',
        'value'
      });
      expect(
          specRubyProblems(sharedBad, fixture).join('\n'),
          allOf(
            contains('shared layout keys [height] are not declared'),
            contains('shared layout keys [value] are not keys its layout'),
            contains('[width] cannot be both owned and shared'),
          ));

      const bare = ControlSpec(
          wireType: 'Bare',
          layout: LayoutWrap.none,
          props: [PropSpec('value', PropType.boolean, 'value')]);
      expect(specRubyProblems(bare, fixture).join('\n'),
          contains('layout is none but Ruby declares layout keys [margin]'));
      expect(
          specRubyProblems(
              const ControlSpec(wireType: 'Nope', props: []), fixture),
          [contains('Ruby has no control')]);
    });
  });

  group('C4 skin consumption', () {
    for (final entry in migratedControls) {
      test('${entry.wireType} skins consume what the spec says', () {
        expect(
            skinConsumptionProblems(
              graph: graph,
              spec: entry.spec,
              core: entry.core,
              propsClass: entry.propsClass,
              skins: entry.skins,
              helpers: entry.helpers,
              portInterface: entry.portInterface,
            ),
            isEmpty);
      });
    }

    test('catches unconsumed, misapplied and unwired spec entries', () {
      const spec = ControlSpec(wireType: 'Toggle', props: [
        PropSpec('value', PropType.boolean, 'value'),
        PropSpec('label', PropType.textOrWidget, 'label',
            consumer: PropConsumer.core),
        PropSpec('splash_radius', PropType.number, 'splashRadius',
            skins: {Skin.material}, reason: 'ink'),
        PropSpec('on_label_color', PropType.color, 'onLabelColor',
            skins: {Skin.cupertino}, reason: 'iOS glyphs'),
      ], events: [
        EventSpec('click', field: 'onClick'),
      ], methods: [
        MethodSpec('animate', port: true),
      ]);
      final fixture = PlatformDependencyGraph({
        'lib/src/controls/toggle_core.dart': '''
class ToggleProps { ToggleProps(r) : value = r.boolean('value'), label = r.x('label'),
  splashRadius = r.n('splash_radius'), onLabelColor = r.c('on_label_color');
  final value; final label; final splashRadius; final onLabelColor; }
class ToggleCore { get props => null; get onClick => null;
  build() => ToggleLabel(label: props.label); }
''',
        'lib/src/controls/toggle.dart': '''
class MaterialToggleSkin implements TogglePort {
  build() => Switch(value: core.props.value, onLabelColor: 1, onTap: core.onClick,
      splashRadius: core.props.onLabelColor); }
''',
        'lib/src/controls/cupertino_toggle.dart': '''
class CupertinoToggleSkin { build() => CupertinoSwitch(splashRadius: 1); }
''',
      });
      final problems = skinConsumptionProblems(
        graph: fixture,
        spec: spec,
        core: 'lib/src/controls/toggle_core.dart',
        propsClass: 'ToggleProps',
        skins: {
          Skin.material: 'lib/src/controls/toggle.dart',
          Skin.cupertino: 'lib/src/controls/cupertino_toggle.dart',
        },
        portInterface: 'TogglePort',
      );
      expect(
          problems.join('\n'),
          allOf(
            contains('value: the cupertino skin never consumes "value"'),
            contains(
                'splash_radius: the material skin never consumes "splashRadius"'),
            contains(
                'on_label_color: the material skin consumes "onLabelColor"'),
            contains('on_label_color: the cupertino skin never consumes'),
            contains('on_click: the cupertino skin never wires "onClick"'),
            contains('the cupertino skin does not implement TogglePort'),
          ));
      expect(problems.join('\n'), isNot(contains('"label"')),
          reason: 'the shared core consumes label for both skins');
      expect(problems.join('\n'), isNot(contains('material skin never wires')),
          reason: 'named-argument labels are not consumption, references are');
    });
  });

  group('C5 lifecycle', () {
    for (final entry in runtimeEntries) {
      for (final design in HarnessDesign.values) {
        testWidgets('${entry.wireType} on ${design.name}', (tester) async {
          expect(await lifecycleProblems(tester, entry, design), isEmpty);
        });
      }
    }
  });

  group('C6 core completeness', () {
    for (final entry in runtimeEntries) {
      for (final design in HarnessDesign.values) {
        testWidgets('${entry.wireType} on ${design.name} parses every key',
            (tester) async {
          expect(await completenessProblems(tester, entry, design), isEmpty);
        });
      }
    }
  });

  group('C7 event and semantics parity', () {
    for (final entry in runtimeEntries) {
      testWidgets('${entry.wireType} behaves the same on iOS and Android',
          (tester) async {
        final android =
            await parityRecord(tester, entry, HarnessDesign.android);
        final ios = await parityRecord(tester, entry, HarnessDesign.ios);
        expect(parityProblems(entry, android, ios), isEmpty);
      });
    }

    testWidgets('records native taps, events, write-backs and invoke results',
        (tester) async {
      final record =
          await parityRecord(tester, probeEntry(), HarnessDesign.ios);
      expect(record['semantics'], [
        {
          'label': 'false:null:Probe',
          'flags': [],
          'actions': ['tap', 'longPress']
        },
        {
          'label': '',
          'flags': [],
          'actions': ['tap']
        },
      ]);
      final steps = (record['steps'] as List).cast<Map>();
      expect(steps.map((s) => s['step']),
          ['tap native', 'tap at 0.9,0.5', 'invoke echo', 'focus', 'unfocus']);
      expect(steps[0]['sent'], [
        {
          'id': 501,
          'update': {'value': true}
        },
        {'id': 501, 'event': 'change', 'data': true},
      ]);
      expect(steps[1]['sent'], [
        {'id': 501, 'event': 'click', 'data': null}
      ]);
      expect(steps[2]['outcome'], {'result': 7});
      expect(steps[3]['sent'], [
        {'id': 501, 'event': 'focus', 'data': null}
      ]);
      expect(steps[4]['sent'], [
        {'id': 501, 'event': 'blur', 'data': null}
      ]);
    });
  });

  group('C8 legacy ratchet', () {
    test('legacy renderers only shrink (report-only until the queue drains)',
        () {
      final listed =
          readLegacyList(File('test/architecture/legacy_renderers.txt'));
      final report = legacyRatchet(graph, listed, {
        for (final entry in migratedControls) ...entry.skins.values,
      });
      if (!report.clean) {
        final message = [
          if (report.unlisted.isNotEmpty)
            'New design files on the old Control pattern (build them on a '
                'core instead):\n  ${report.unlisted.join('\n  ')}',
          if (report.stale.isNotEmpty)
            'Remove from test/architecture/legacy_renderers.txt:\n  '
                '${report.stale.join('\n  ')}',
        ].join('\n');
        if (enforceLegacyRatchet) fail(message);
        // ignore: avoid_print
        print('C8 (report-only): $message');
      }
      expect(listed, isNotEmpty);
    });

    test('flags unlisted legacy files and stale entries', () {
      final fixture = PlatformDependencyGraph({
        'lib/src/models/control.dart': 'class Control {}',
        'lib/src/controls/old.dart': '''
import 'package:flutter/material.dart';
import '../models/control.dart';
class Old {}''',
        'lib/src/controls/new_old.dart': '''
import 'package:flutter/cupertino.dart';
class NewOld { f(c) => c.triggerEvent("x"); }''',
        'lib/src/controls/migrated.dart': '''
import 'package:flutter/cupertino.dart';
class MigratedSkin {}''',
        'lib/src/controls/neutral.dart': '''
import '../models/control.dart';''',
      });
      final report = legacyRatchet(fixture, {
        'lib/src/controls/old.dart',
        'lib/src/controls/migrated.dart',
        'lib/src/controls/gone.dart'
      }, {
        'lib/src/controls/migrated.dart'
      });
      expect(report.unlisted, ['lib/src/controls/new_old.dart']);
      expect(report.stale,
          ['lib/src/controls/gone.dart', 'lib/src/controls/migrated.dart']);
    });
  });

  group('QA mutations (deliberately bad skins and cores must fail)', () {
    // A small toggle: a core and two skins every mutation starts from.
    const spec = ControlSpec(wireType: 'Toggle', props: [
      PropSpec('value', PropType.boolean, 'value'),
      PropSpec('label', PropType.textOrWidget, 'label',
          consumer: PropConsumer.core),
      PropSpec('thumb_color', PropType.stateColor, 'thumbColor'),
      PropSpec('splash_radius', PropType.number, 'splashRadius',
          skins: {Skin.material}, reason: 'ink'),
      PropSpec('on_label_color', PropType.color, 'onLabelColor',
          skins: {Skin.cupertino}, reason: 'iOS glyphs'),
    ], events: [
      EventSpec('change', source: EventSource.core),
      EventSpec('image_error', field: 'onImageError'),
    ]);
    const corePath = 'lib/src/controls/toggle_core.dart';
    const materialPath = 'lib/src/controls/toggle.dart';
    const cupertinoPath = 'lib/src/controls/cupertino_toggle.dart';
    const core = """
import 'package:flutter/widgets.dart';
import '../core/control_core.dart';
class ToggleProps {
  ToggleProps.parse(r) : value = r.boolean('value'), label = r.t('label'),
      thumbColor = r.s('thumb_color'), splashRadius = r.n('splash_radius'),
      onLabelColor = r.c('on_label_color');
  final value; final label; final thumbColor; final splashRadius;
  final onLabelColor;
}
class ToggleCore extends ControlCore<ToggleProps> {
  ToggleCore(super.control);
  get onImageError => null;
  Widget labelled(Widget native) => ToggleLabel(label: props.label, child: native);
  void didParse(ToggleProps? previous) {
    super.didParse(previous);
  }
}
""";
    const material = """
import 'package:flutter/material.dart';
import 'toggle_core.dart';
class MaterialToggleSkin {
  build(core) {
    final p = core.props;
    return core.labelled(Switch(value: core.value, thumbColor: p.thumbColor,
        splashRadius: p.splashRadius, onImageError: core.onImageError));
  }
}
""";
    const cupertino = """
import 'package:flutter/cupertino.dart';
import 'toggle_core.dart';
class CupertinoToggleSkin {
  build(core) {
    final p = core.props;
    return core.labelled(CupertinoSwitch(value: core.value,
        thumbColor: p.thumbColor, onLabelColor: p.onLabelColor,
        onImageError: core.onImageError));
  }
}
""";

    PlatformDependencyGraph toggle(
            {String Function(String)? onCore,
            String Function(String)? onMaterial,
            String Function(String)? onCupertino}) =>
        PlatformDependencyGraph({
          'lib/src/models/control.dart': 'class Control {}',
          'lib/src/core/control_core.dart': 'class ControlCore<P> {}',
          corePath: onCore?.call(core) ?? core,
          materialPath: onMaterial?.call(material) ?? material,
          cupertinoPath: onCupertino?.call(cupertino) ?? cupertino,
        });

    List<String> consumption(PlatformDependencyGraph g) =>
        skinConsumptionProblems(
          graph: g,
          spec: spec,
          core: corePath,
          propsClass: 'ToggleProps',
          skins: {Skin.material: materialPath, Skin.cupertino: cupertinoPath},
        );

    String insertAfterImports(String source, String code) =>
        source.replaceFirst("import 'toggle_core.dart';\n",
            "import 'toggle_core.dart';\n$code\n");

    test('the unmutated toggle passes C1, C2, C2b and C4', () {
      final g = toggle();
      expect(skinIsolationProblems(g, materialPath), isEmpty);
      expect(skinIsolationProblems(g, cupertinoPath), isEmpty);
      expect(coreIsolationProblems(g, corePath), isEmpty);
      expect(g.directDesigns(corePath), isEmpty);
      expect(consumption(g), isEmpty);
    });

    test('M1: a skin imports the Control model (C1)', () {
      final g = toggle(
          onCupertino: (s) =>
              insertAfterImports(s, "import '../models/control.dart';"));
      expect(skinIsolationProblems(g, cupertinoPath),
          contains(contains('imports lib/src/models/control.dart')));
    });

    test('M2: a skin fires an event itself (C1)', () {
      final g = toggle(
          onMaterial: (s) =>
              insertAfterImports(s, "void _leak(c) => c.triggerEvent('x');"));
      expect(skinIsolationProblems(g, materialPath),
          contains(contains('uses triggerEvent')));
    });

    test('M3: a skin drops a prop it must honor (C4)', () {
      final g = toggle(
          onCupertino: (s) => s.replaceFirst('thumbColor: p.thumbColor,', ''));
      expect(consumption(g),
          contains(contains('the cupertino skin never consumes "thumbColor"')));
    });

    test('M4: the core mentioning the field no longer excuses the skin (C4)',
        () {
      final g = toggle(
          onCupertino: (s) => s.replaceFirst('thumbColor: p.thumbColor,', ''),
          onCore: (s) => s.replaceFirst('super.didParse(previous);',
              'previous?.thumbColor;\n    super.didParse(previous);'));
      expect(consumption(g),
          contains(contains('the cupertino skin never consumes "thumbColor"')));
    });

    test('M4: a core-consumed prop must be used by the core and no skin (C4)',
        () {
      final unused = toggle(
          onCore: (s) => s.replaceFirst(
              'ToggleLabel(label: props.label, child: native)', 'native'));
      expect(consumption(unused),
          contains(contains('declared core-consumed but the core never')));
      final alsoSkin = toggle(
          onMaterial: (s) => s.replaceFirst(
              'value: core.value,', 'value: core.value, label: p.label,'));
      expect(consumption(alsoSkin),
          contains(contains('"label" is also read by the material skin')));
    });

    test('M5: a skin reads a prop for the other design only (C4)', () {
      final g = toggle(
          onMaterial: (s) =>
              insertAfterImports(s, 'Object? _qa(p) => p.onLabelColor;'));
      expect(consumption(g),
          contains(contains('the material skin consumes "onLabelColor"')));
    });

    test('M6: the spec declares a key Ruby cannot send (C3)', () {
      final ruby = RubySurface({
        'contract_version': 2,
        'wire_types': {
          'Toggle': {
            'keywords': ['value', 'on_change'],
          },
        },
      });
      const bogus = ControlSpec(wireType: 'Toggle', props: [
        PropSpec('value', PropType.boolean, 'value'),
        PropSpec('qa_bogus', PropType.boolean, 'value'),
      ], events: [
        EventSpec('change', source: EventSource.core),
      ]);
      expect(specRubyProblems(bogus, ruby),
          contains(contains('declares [qa_bogus] but Ruby cannot send')));
    });

    test('M7: a core imports a design (C2)', () {
      final g = toggle(
          onCore: (s) => s.replaceFirst("import '../core/control_core.dart';",
              "import '../core/control_core.dart';\nimport 'package:flutter/material.dart';"));
      expect(g.directDesigns(corePath), {Design.material});
    });

    test('M8: a core keeps the Control and exposes it to a skin (C2b)', () {
      final typed = toggle(
          onCore: (s) => s
              .replaceFirst("import '../core/control_core.dart';",
                  "import '../core/control_core.dart';\nimport '../models/control.dart';")
              .replaceFirst('ToggleCore(super.control);',
                  'ToggleCore(Control c) : qaControl = c, super(c);\n  final Control qaControl;'));
      expect(
          coreIsolationProblems(typed, corePath).join('\n'),
          allOf(
            contains('imports lib/src/models/control.dart'),
            contains('uses Control'),
            contains('takes "c": a core may only forward super parameters'),
            contains('has initializers'),
          ));
      final untyped = toggle(
          onCore: (s) => s.replaceFirst('ToggleCore(super.control);',
              'ToggleCore(dynamic c) : qaControl = c, super(c);\n  final Object qaControl;'));
      expect(coreIsolationProblems(untyped, corePath).join('\n'),
          allOf(contains('uses dynamic'), contains('has initializers')));
      final body = toggle(
          onCore: (s) => s.replaceFirst('ToggleCore(super.control);',
              'ToggleCore(super.control) { qa = control; }\n  Object? qa;'));
      expect(coreIsolationProblems(body, corePath),
          contains(contains('uses [control] in its body')));
    });

    test('N1: a core accepts data written in from outside (C2b)', () {
      final field = toggle(
          onCore: (s) => s.replaceFirst('ToggleCore(super.control);',
              'ToggleCore(super.control);\n  Map<String, Object?>? qaLeak;'));
      expect(coreIsolationProblems(field, corePath),
          contains(contains('public mutable field "qaLeak"')));
      final setter = toggle(
          onCore: (s) => s.replaceFirst('ToggleCore(super.control);',
              'ToggleCore(super.control);\n  set qaLeak(Object? v) {}'));
      expect(coreIsolationProblems(setter, corePath),
          contains(contains('public setter "qaLeak"')));
    });

    test('M9: a skin does not wire a skin-sourced event (C4)', () {
      final g = toggle(
          onMaterial: (s) =>
              s.replaceFirst(', onImageError: core.onImageError', ''));
      expect(consumption(g),
          contains(contains('the material skin never wires "onImageError"')));
    });

    testWidgets('M10 / (E): every listener on the Control is counted (C5)',
        (tester) async {
      // M10 itself (the host keeps the old listener) mutates the kernel; C5
      // above catches it on the real host. Here a stray second listener, as
      // a legacy renderer would add, must be counted.
      final entry = probeEntry();
      final wire = entry.fixture();
      final mount = await mountWire(tester, HarnessDesign.android, wire,
          extensions: entry.extensions());
      final control = mount.control(targetIdOf(entry, wire));
      expect(await invokeListenerCount(tester, control), 1);
      Future<dynamic> stray(String name, dynamic args) async => null;
      control.addInvokeMethodListener(stray);
      expect(await invokeListenerCount(tester, control), 2);
      control.removeInvokeMethodListener(stray);
      Future<dynamic> rejecting(String name, dynamic args) async =>
          throw UnsupportedError(name);
      control.addInvokeMethodListener(rejecting);
      expect(await invokeListenerCount(tester, control), -1);
      control.removeInvokeMethodListener(rejecting);
    });

    testWidgets('M11: a parse forgets a declared key (C6)', (tester) async {
      final problems = await completenessProblems(
          tester,
          probeEntry(extensions: () => [ProbeExtension(forgetful: true)]),
          HarnessDesign.android);
      expect(problems,
          contains(contains('declared keys the core never parsed: [tint]')));
    });

    testWidgets('M12: a skin inverts the value it reports (C7)',
        (tester) async {
      final bad =
          probeEntry(extensions: () => [ProbeExtension(invertMaterial: true)]);
      final problems = parityProblems(
          bad,
          await parityRecord(tester, bad, HarnessDesign.android),
          await parityRecord(tester, bad, HarnessDesign.ios));
      expect(problems, contains(contains('step 1 differs')));
    });

    testWidgets(
        '(D)/(F): a script must tap the native widget and fire every '
        'core event (C7)', (tester) async {
      final lazy =
          probeEntry(script: [SnapshotStep.tapAt(const Offset(0.9, 0.5))]);
      final problems = parityProblems(
          lazy,
          await parityRecord(tester, lazy, HarnessDesign.android),
          await parityRecord(tester, lazy, HarnessDesign.ios));
      expect(
          problems.join('\n'),
          allOf(
            contains('the parity script never taps the native widget'),
            contains('the script never made the core fire "change"'),
            contains('the script never made the core fire "focus"'),
            contains('the script never made the core fire "blur"'),
          ));
    });
  });
}

/// The test-only CoreProbe, run through the runtime rules to prove the
/// runners themselves work while the manifest is still small.
MigratedControl probeEntry(
        {List<SnapshotStep>? script,
        List<RufletExtension> Function()? extensions}) =>
    MigratedControl(
      spec: probeSpec,
      entry: 'test/support/core_probe.dart',
      core: 'test/support/core_probe.dart',
      propsClass: 'ProbeProps',
      skins: const {},
      nativeWidgets: const {
        Skin.material: ProbeNative,
        Skin.cupertino: ProbeNative,
      },
      fixture: () => {
        '_c': 'Column',
        '_i': 500,
        'controls': [
          {'_c': 'CoreProbe', '_i': 501, 'caption': 'Probe', 'value': false},
        ],
      },
      samples: const {'density': 'compact'},
      parityScript: script ??
          [
            SnapshotStep.tapNative(),
            SnapshotStep.tapAt(const Offset(0.9, 0.5)),
            SnapshotStep.invoke('echo', args: {'value': 7}),
            SnapshotStep('focus', (c) async {
              await invokeOutcome(c.tester, c.target, 'focus');
              await c.tester.pumpAndSettle();
            }),
            SnapshotStep.unfocus(),
          ],
      extensions: extensions ?? () => [ProbeExtension()],
    );
