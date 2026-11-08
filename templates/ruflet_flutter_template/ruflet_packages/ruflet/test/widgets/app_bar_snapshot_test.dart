// Behaviour snapshots of AppBar (the `app_bar` and `cupertino_app_bar` DSL
// names) on iOS and Android, rendered the way View renders a page's app bar:
// `AdaptiveAppBarControl.resolve` handed to a Scaffold / CupertinoPageScaffold.
// Each records geometry, semantics, what the bar and its slots send to Ruby
// during scripted taps, invoke outcomes, and the sizing contract the scaffold
// reads before building the bar (its preferred height and, on iOS, whether it
// fully obstructs the content). One fixture also goes through the registry
// (a bar inside a Column).
// Rewrite with `flutter test --update-goldens` only for a change listed in
// the PR's "Parity changes" table.
import 'package:flutter/cupertino.dart'
    show CupertinoApp, CupertinoPageScaffold, ObstructingPreferredSizeWidget;
import 'package:flutter/material.dart' as material
    show Icons, MaterialApp, Scaffold, Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/adaptive_app_bar.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/utils/material_icons.dart';
import 'package:ruflet/src/utils/material_style_theme.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _target = 2301;

// Material icon set indexes: 0x10000 | index.
const _icon = 0x10000;
const _otherIcon = 0x10001;

Map<String, dynamic> _bar(Map<String, dynamic> props) =>
    {'_c': 'AppBar', '_i': _target, ...props};

/// A step of a scaffold fixture: [root] is the bar the scaffold was handed.
class _Step {
  const _Step(this.name, this.run);
  final String name;
  final Future<InvokeOutcome?> Function(
      WidgetTester tester, Control control, Finder root) run;

  /// Taps the bar at [fraction] of its size.
  factory _Step.tapAt(Offset fraction) =>
      _Step('tap at ${fraction.dx},${fraction.dy}', (tester, _, root) async {
        final box = tester.renderObject<RenderBox>(root);
        await tester.tapAt(box.localToGlobal(Offset(
            box.size.width * fraction.dx, box.size.height * fraction.dy)));
        await tester.pumpAndSettle();
        return null;
      });

  factory _Step.invoke(String method) =>
      _Step('invoke $method', (tester, control, _) async {
        final outcome = await invokeOutcome(tester, control, method);
        await tester.pumpAndSettle();
        return outcome;
      });

  factory _Step.unfocus() => _Step('unfocus', (tester, _, __) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        return null;
      });
}

class _Fixture {
  const _Fixture(this.name, this.wire, {this.steps = const []});
  final String name;
  final Map<String, dynamic> wire;
  final List<_Step> steps;
}

Map<String, dynamic> _iconButton(int id, int icon) =>
    {'_c': 'IconButton', '_i': id, 'icon': icon, 'on_click': true};

final _fixtures = [
  _Fixture(
    'defaults',
    _bar({'title': 'Title'}),
    steps: [
      _Step.tapAt(const Offset(0.5, 0.5)),
      _Step.invoke('focus'),
      _Step.unfocus(),
    ],
  ),
  _Fixture(
    'child_title',
    _bar({
      'title': {'_c': 'Text', '_i': 2302, 'value': 'Child title'},
    }),
  ),
  _Fixture(
    'actions',
    _bar({
      'title': 'Title',
      'leading': _iconButton(2303, _icon),
      'actions': [_iconButton(2304, _icon), _iconButton(2305, _otherIcon)],
    }),
    steps: [
      _Step.tapAt(const Offset(0.97, 0.5)),
      _Step.tapAt(const Offset(0.03, 0.5)),
    ],
  ),
  _Fixture(
    'trailing',
    _bar({'title': 'Title', 'trailing': _iconButton(2306, _icon)}),
    steps: [_Step.tapAt(const Offset(0.97, 0.5))],
  ),
  _Fixture(
    'trailing_and_actions',
    _bar({
      'title': 'Title',
      'trailing': _iconButton(2307, _icon),
      'actions': [_iconButton(2308, _otherIcon)],
    }),
    steps: [_Step.tapAt(const Offset(0.97, 0.5))],
  ),
  _Fixture(
    'leading_back',
    _bar({
      'title': 'Title',
      'leading': _iconButton(
          2309, (1 << 16) | materialIcons.indexOf(material.Icons.arrow_back)),
    }),
    steps: [_Step.tapAt(const Offset(0.03, 0.5))],
  ),
  _Fixture(
    'large',
    _bar({'title': 'Large title', 'large': true}),
  ),
  _Fixture(
    'large_toolbar_height',
    _bar({'title': 'Large title', 'large': true, 'toolbar_height': 80.0}),
  ),
  _Fixture(
    'material_keys',
    _bar({
      'title': 'Material',
      'leading': _iconButton(2310, _icon),
      'actions': [_iconButton(2311, _otherIcon)],
      'center_title': true,
      'color': '#112233',
      'bgcolor': '#eeeeee',
      'elevation': 4.0,
      'shadow_color': '#000000',
      'elevation_on_scroll': 2.0,
      'force_material_transparency': false,
      'secondary': true,
      'title_spacing': 8.0,
      'exclude_header_semantics': true,
      'clip_behavior': 'hardEdge',
      'title_text_style': {'size': 18.0},
      'shape': {'_type': 'roundedrectangle', 'radius': 8.0},
      'toolbar_opacity': 0.8,
      'toolbar_text_style': {'size': 12.0},
      'actions_padding': 4.0,
      'leading_width': 72.0,
      'toolbar_height': 70.0,
      'automatically_imply_leading': false,
    }),
  ),
  _Fixture(
    'cupertino_keys',
    _bar({
      'title': 'Cupertino',
      'bgcolor': '#ffffff',
      'padding': 8.0,
      'border': {
        'bottom': {'color': '#ff0000', 'width': 2.0}
      },
      'brightness': 'dark',
      'previous_page_title': 'Back',
      'automatically_imply_title': false,
      'transition_between_routes': false,
      'automatic_background_visibility': false,
      'enable_background_filter_blur': false,
    }),
  ),
  _Fixture(
    'translucent',
    _bar({'title': 'Translucent', 'bgcolor': '#80ffffff'}),
  ),
  _Fixture(
    'layout',
    _bar({
      'title': 'Layout',
      'opacity': 0.5,
      'tooltip': 'Bar',
      'badge': 'New',
    }),
  ),
];

/// Renders [fixture] the way View renders a page's app bar and records it.
Future<Map<String, Object?>> _captureInScaffold(
    WidgetTester tester, HarnessDesign design, _Fixture fixture) async {
  final semantics = tester.ensureSemantics();
  try {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = HarnessBackend(design);
    final control = Control.fromMap(copyWire(fixture.wire), backend);
    final ios = design == HarnessDesign.ios;
    final bar = AdaptiveAppBarControl.resolve(
        control: control,
        design: ios ? PageDesign.cupertino : PageDesign.material);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: ios
          ? CupertinoApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => RufletStyleThemeScope(
                  data: cupertinoStyleTheme(context), child: child!),
              home: CupertinoPageScaffold(
                  navigationBar: bar as ObstructingPreferredSizeWidget,
                  child: const SizedBox.expand()),
            )
          : material.MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => RufletStyleThemeScope(
                  data: materialStyleTheme(material.Theme.of(context)),
                  child: child!),
              home:
                  material.Scaffold(appBar: bar, body: const SizedBox.expand()),
            ),
    ));
    await tester.pumpAndSettle();
    final root = find.byWidget(bar);
    expect(root, findsOneWidget);
    final snapshot = <String, Object?>{
      'fixture': fixture.name,
      'design': design.name,
      'sizing': {
        'preferred_height': bar.preferredSize.height,
        if (bar is ObstructingPreferredSizeWidget)
          'fully_obstructs': bar.shouldFullyObstruct(tester.element(root)),
      },
      'geometry': _geometry(tester, root),
      'semantics': semanticsWithin(tester, root),
    };
    final steps = <Map<String, Object?>>[];
    backend.sent.clear();
    for (final step in fixture.steps) {
      final outcome = await step.run(tester, control, root);
      steps.add({
        'step': step.name,
        'sent': [for (final m in backend.sent) m.toJson()],
        if (outcome != null) 'outcome': outcome.toJson(),
        'semantics': semanticsWithin(tester, root),
      });
      backend.sent.clear();
    }
    snapshot['steps'] = steps;
    expect(tester.takeException(), isNull);
    return snapshot;
  } finally {
    semantics.dispose();
  }
}

/// The bar's size and the rects of its Text and Icon descendants.
Map<String, Object?> _geometry(WidgetTester tester, Finder root) {
  final box = tester.renderObject<RenderBox>(root);
  final origin = box.localToGlobal(Offset.zero);
  final elements = <Map<String, Object?>>[];
  for (final element in find
      .descendant(of: root, matching: find.byWidgetPredicate((w) => true))
      .evaluate()) {
    final widget = element.widget;
    final render = element.renderObject;
    if (render is! RenderBox || !render.hasSize) continue;
    final rect =
        rectJson((render.localToGlobal(Offset.zero) - origin) & render.size);
    if (widget is Text) {
      elements.add({
        'text': widget.data ?? widget.textSpan?.toPlainText(),
        'rect': rect
      });
    } else if (widget is Icon) {
      elements.add({'icon': widget.icon?.codePoint, 'rect': rect});
    }
  }
  final size = rectJson(Offset.zero & box.size);
  return {
    'size': {'w': size['w'], 'h': size['h']},
    'elements': elements,
  };
}

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await _captureInScaffold(tester, design, fixture),
            snapshotPath('AppBar', fixture.name, design));
      });
    }
  }

  // The registry path: an AppBar control inside a Column.
  final registry = SnapshotFixture(
    'registry_column',
    {
      '_c': 'Column',
      '_i': 2390,
      'controls': [
        _bar({
          'title': 'Title',
          'actions': [_iconButton(2391, _icon)]
        }),
      ],
    },
    target: _target,
    steps: [SnapshotStep.tapAt(const Offset(0.97, 0.5))],
  );
  for (final design in HarnessDesign.values) {
    testWidgets('registry_column on ${design.name}', (tester) async {
      expectSnapshot(await captureSnapshot(tester, design, registry),
          snapshotPath('AppBar', registry.name, design));
    });
  }
}
