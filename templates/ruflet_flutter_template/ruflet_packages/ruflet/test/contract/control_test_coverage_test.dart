// Coverage check: every control and service type the engine registers has a
// test, and the engine's registry agrees with what Ruby can send.
//
// Registered types are the `case "X":` labels of every `createWidget` and
// `createService` in packages/ruflet/lib and packages/ruflet_*/lib. Ruby's
// side is test/contract/ruflet_control_surface.json (every wire type the Ruby
// control factory and service registry can emit; refresh it with
// tool/sync_ruby_surface.rb) plus the Ruflet::Extensions registrations listed
// in [rubyExtensionTypes], which that export does not include.
//
// A test file claims a type with a line of exactly this form, anywhere in it:
//
//     // ruflet-coverage: TypeA TypeB
//
// A claim is accepted only when the file builds that wire type (the quoted
// literal 'TypeA' or "TypeA" appears), defines test()/testWidgets(), and, for
// a type that renders, exercises both designs (an iOS/macOS marker and an
// Android/Windows/Linux marker; see [_cupertinoMarkers], [_materialMarkers]).
// It must also live in the package that owns the type. What the test asserts
// (attributes, geometry, events) is for review; this check proves a test was
// written, declared and runs both renderers.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Types Ruby's Ruflet::Extensions registry adds to the DSL. They are not in
/// ruflet_control_surface.json (tools/control_surface.rb exports the control
/// factory and service registry only). Source: ruflet
/// packages/ruflet_core/lib/ruflet_ui/ruflet/extensions/*.rb (`WIRE`).
const rubyExtensionTypes = {'qrcode_scanner': 'ruflet_qrcode_scanner'};

/// Types Ruby sends that no createWidget/createService registers: the parent
/// reads them as data (`control.children("rows")`, `control.get("badge")`),
/// so their wire type is never looked up. Each maps to its owning package and
/// the parents that read it. They need a test like any registered type,
/// declared in that package.
const childTypes = <String, (String, List<String>)>{
  // packages/ruflet
  'AutoCompleteSuggestion': ('ruflet', ['AutoComplete']),
  'Badge': ('ruflet', ['* (any control `badge`)']),
  'DataCell': ('ruflet', ['DataTable', 'DataTable2']),
  'DataColumn': ('ruflet', ['DataTable']),
  'DataRow': ('ruflet', ['DataTable']),
  'DropdownOption': ('ruflet', ['Dropdown']),
  'Option': ('ruflet', ['Dropdown']),
  'ExpansionPanel': ('ruflet', ['ExpansionPanelList']),
  'NavigationDrawerDestination': ('ruflet', ['NavigationDrawer']),
  'NavigationRailDestination': ('ruflet', ['NavigationRail']),
  'Segment': ('ruflet', ['SegmentedButton']),
  'SnackBarAction': ('ruflet', ['SnackBar']),
  'Step': ('ruflet', ['Stepper']),
  'TableRow': ('ruflet', ['Table']),
  'TextSpan': ('ruflet', ['Text', 'Canvas']),
  'SliverAppBar': ('ruflet', ['CustomScrollView', 'NestedScrollView']),
  'SliverFillRemaining': ('ruflet', ['CustomScrollView']),
  'SliverGrid': ('ruflet', ['CustomScrollView']),
  'SliverList': ('ruflet', ['CustomScrollView']),
  'SliverPadding': ('ruflet', ['CustomScrollView']),
  'SliverToBoxAdapter': ('ruflet', ['CustomScrollView', 'NestedScrollView']),
  'Arc': ('ruflet', ['Canvas']),
  'Circle': ('ruflet', ['Canvas']),
  'Color': ('ruflet', ['Canvas']),
  'Fill': ('ruflet', ['Canvas']),
  'Line': ('ruflet', ['Canvas']),
  'Oval': ('ruflet', ['Canvas']),
  'Path': ('ruflet', ['Canvas']),
  'Points': ('ruflet', ['Canvas']),
  'Rect': ('ruflet', ['Canvas']),
  'Shadow': ('ruflet', ['Canvas']),
  'Dialogs': ('ruflet', ['View']),
  'Overlay': ('ruflet', ['View']),
  'ServiceRegistry': ('ruflet', ['Page']),
  // packages/ruflet_datatable2
  'DataColumn2': ('ruflet_datatable2', ['DataTable2']),
  'DataRow2': ('ruflet_datatable2', ['DataTable2']),
  // packages/ruflet_charts
  'BarChartGroup': ('ruflet_charts', ['BarChart']),
  'BarChartRod': ('ruflet_charts', ['BarChart']),
  'BarChartRodStackItem': ('ruflet_charts', ['BarChart']),
  'CandlestickChartSpot': ('ruflet_charts', ['CandlestickChart']),
  'ChartAxis': ('ruflet_charts', ['every chart']),
  'ChartAxisLabel': ('ruflet_charts', ['every chart']),
  'LineChartData': ('ruflet_charts', ['LineChart']),
  'LineChartDataPoint': ('ruflet_charts', ['LineChart']),
  'PieChartSection': ('ruflet_charts', ['PieChart']),
  'RadarChartTitle': ('ruflet_charts', ['RadarChart']),
  'RadarDataSet': ('ruflet_charts', ['RadarChart']),
  'RadarDataSetEntry': ('ruflet_charts', ['RadarChart']),
  'ScatterChartSpot': ('ruflet_charts', ['ScatterChart']),
  // packages/ruflet_map
  'CircleMarker': ('ruflet_map', ['CircleLayer']),
  'Marker': ('ruflet_map', ['MarkerLayer']),
  'PolygonMarker': ('ruflet_map', ['PolygonLayer']),
  'PolylineMarker': ('ruflet_map', ['PolylineLayer']),
  'ImageSourceAttribution': ('ruflet_map', ['RichAttribution']),
  'TextSourceAttribution': ('ruflet_map', ['RichAttribution']),
};

/// Ruby wire types the engine does not render. The check fails on any other
/// Ruby type the engine neither registers nor reads as a child, so a new one
/// is either implemented or explained here.
const rubyOnlyTypes = {
  'BasePage': 'Ruby base class of Page/View, constructible as `base_page`; '
      'no engine renderer (Flet has none either).',
  'MapLayer': 'Ruby base class of the map layers, constructible as '
      '`map_layer`; ruflet_map registers only the concrete layers.',
};

/// Registered types Ruby never sends. The check fails on any other, so a new
/// one is either given a Ruby counterpart or explained here.
const engineOnlyTypes = {
  'Tester': "Flet's integration-test service; Ruby has no tester DSL.",
  'QrcodeScanner': 'Flet-style spelling; Ruby sends `qrcode_scanner`.',
  'SpinKitChasingDots': _spinKitLegacy,
  'SpinKitCircle': _spinKitLegacy,
  'SpinKitCubeGrid': _spinKitLegacy,
  'SpinKitDancingSquare': _spinKitLegacy,
  'SpinKitDoubleBounce': _spinKitLegacy,
  'SpinKitDualRing': _spinKitLegacy,
  'SpinKitFadingCircle': _spinKitLegacy,
  'SpinKitFadingCube': _spinKitLegacy,
  'SpinKitFadingFour': _spinKitLegacy,
  'SpinKitFadingGrid': _spinKitLegacy,
  'SpinKitFoldingCube': _spinKitLegacy,
  'SpinKitHourGlass': _spinKitLegacy,
  'SpinKitPianoWave': _spinKitLegacy,
  'SpinKitPouringHourGlass': _spinKitLegacy,
  'SpinKitPouringHourGlassRefined': _spinKitLegacy,
  'SpinKitPulse': _spinKitLegacy,
  'SpinKitPulsingGrid': _spinKitLegacy,
  'SpinKitPumpingHeart': _spinKitLegacy,
  'SpinKitRing': _spinKitLegacy,
  'SpinKitRipple': _spinKitLegacy,
  'SpinKitRotatingCircle': _spinKitLegacy,
  'SpinKitRotatingPlain': _spinKitLegacy,
  'SpinKitSpinningCircle': _spinKitLegacy,
  'SpinKitSpinningLines': _spinKitLegacy,
  'SpinKitSquareCircle': _spinKitLegacy,
  'SpinKitThreeBounce': _spinKitLegacy,
  'SpinKitThreeInOut': _spinKitLegacy,
  'SpinKitWanderingCubes': _spinKitLegacy,
  'SpinKitWave': _spinKitLegacy,
  'SpinKitWaveSpinner': _spinKitLegacy,
};
const _spinKitLegacy = 'legacy per-style wire name; Ruby sends RufletSpinKit '
    'with a `type`.';

/// Types whose Ruby family (visual layout control vs page service) differs
/// from how the engine registers them. Ruby routes each by the engine's
/// registration (Ruflet::UI::ServiceTypes, generated from createService, and
/// Page::VISUAL_SERVICE_TYPES), so the names still meet.
const familyDifferences = {
  'Camera': 'Ruby keeps it in RufletServices; the engine renders it '
      '(createWidget) and Ruby lays it out (VISUAL_SERVICE_TYPES).',
  'Audio': 'Ruby control class; engine service (ServiceTypes).',
  'BrowserContextMenu': 'Ruby control class; engine service (ServiceTypes).',
  'InterstitialAd': 'Ruby control class; engine service (ServiceTypes).',
  'Window': 'Ruby page.window control; engine service (ServiceTypes).',
};

/// Types without a declared test yet (the state when this check landed).
/// The check fails for any uncovered type not listed here and reports the
/// entries a test now covers; drop those so the list only shrinks.
const knownGaps = <String>{
  'Accelerometer',
  'ActionSheet',
  'ActionSheetAction',
  'AnimatedSwitcher',
  'Arc',
  'Audio',
  'AudioRecorder',
  'AutoComplete',
  'AutoCompleteSuggestion',
  'Badge',
  'BannerAd',
  'Barometer',
  'Battery',
  'BottomAppBar',
  'BrowserContextMenu',
  'Camera',
  'Canvas',
  'Card',
  'Circle',
  'CircleAvatar',
  'CircleLayer',
  'CircleMarker',
  'Color',
  'Connectivity',
  'DataColumn2',
  'DataRow2',
  'DataTable2',
  'Divider',
  'ExpansionTile',
  'Fill',
  'Flashlight',
  'Geolocator',
  'GestureDetector',
  'Gyroscope',
  'HapticFeedback',
  'Hero',
  'Icon',
  'ImageSourceAttribution',
  'InteractiveViewer',
  'InterstitialAd',
  'Line',
  'LocalAuthentication',
  'Magnetometer',
  'Map',
  'Markdown',
  'Marker',
  'MarkerLayer',
  'MenuBar',
  'MergeSemantics',
  'NativeAd',
  'NavigationDrawer',
  'NavigationDrawerDestination',
  'NavigationRail',
  'NavigationRailDestination',
  'Option',
  'Oval',
  'Page',
  'Pagelet',
  'Path',
  'PermissionHandler',
  'Picker',
  'Placeholder',
  'Points',
  'PolygonLayer',
  'PolygonMarker',
  'PolylineLayer',
  'PolylineMarker',
  'ProgressBar',
  'QrcodeScanner',
  'RangeSlider',
  'Rect',
  'RichAttribution',
  'Rive',
  'RotatedBox',
  'RufletApp',
  'RufletSpinKit',
  'SafeArea',
  'ScreenBrightness',
  'SecureStorage',
  'SemanticsService',
  'ShaderMask',
  'Shadow',
  'ShakeDetector',
  'SharedPreferences',
  'Shimmer',
  'SimpleAttribution',
  'SnackBar',
  'SnackBarAction',
  'SpinKitChasingDots',
  'SpinKitCircle',
  'SpinKitCubeGrid',
  'SpinKitDancingSquare',
  'SpinKitDoubleBounce',
  'SpinKitDualRing',
  'SpinKitFadingCircle',
  'SpinKitFadingCube',
  'SpinKitFadingFour',
  'SpinKitFadingGrid',
  'SpinKitFoldingCube',
  'SpinKitHourGlass',
  'SpinKitPianoWave',
  'SpinKitPouringHourGlass',
  'SpinKitPouringHourGlassRefined',
  'SpinKitPulse',
  'SpinKitPulsingGrid',
  'SpinKitPumpingHeart',
  'SpinKitRing',
  'SpinKitRipple',
  'SpinKitRotatingCircle',
  'SpinKitRotatingPlain',
  'SpinKitSpinningCircle',
  'SpinKitSpinningLines',
  'SpinKitSquareCircle',
  'SpinKitThreeBounce',
  'SpinKitThreeInOut',
  'SpinKitWanderingCubes',
  'SpinKitWave',
  'SpinKitWaveSpinner',
  'StoragePaths',
  'Tester',
  'TextSourceAttribution',
  'TileLayer',
  'TimePicker',
  'TransparentPointer',
  'UserAccelerometer',
  'VerticalDivider',
  'Video',
  'Wakelock',
  'Window',
  'WindowDragArea',
  'qrcode_scanner',
};

const _cupertinoMarkers = [
  'TargetPlatform.iOS',
  'TargetPlatform.macOS',
  'TargetPlatform.values',
  'HarnessDesign.ios',
  'HarnessDesign.values',
  'PageDesign.cupertino',
  'PageDesign.values',
];
const _materialMarkers = [
  'TargetPlatform.android',
  'TargetPlatform.windows',
  'TargetPlatform.linux',
  'TargetPlatform.fuchsia',
  'TargetPlatform.values',
  'HarnessDesign.android',
  'HarnessDesign.values',
  'PageDesign.material',
  'PageDesign.values',
];

/// One `case "X":` registration.
class Registration {
  Registration(this.package, this.type, {required this.renders});
  final String package;
  final String type;

  /// From createWidget (renders), not createService.
  final bool renders;
}

/// One `// ruflet-coverage:` claim.
class Claim {
  Claim(this.package, this.file, this.type);
  final String package;
  final File file;
  final String type;
  String get path => file.path;
}

/// The engine packages beside this one (packages/ruflet, packages/ruflet_*).
List<Directory> enginePackages() {
  final root = Directory.current.parent;
  return root.listSync().whereType<Directory>().where((d) {
    final name = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
    return (name == 'ruflet' || name.startsWith('ruflet_')) &&
        Directory('${d.path}/lib').existsSync();
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String packageName(Directory dir) =>
    dir.uri.pathSegments.where((s) => s.isNotEmpty).last;

Iterable<File> dartFiles(Directory dir) => dir.existsSync()
    ? dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
    : const [];

/// The body of every `<method>(...) { ... }` in [source].
List<String> methodBodies(String source, String method) {
  final bodies = <String>[];
  for (final match in RegExp('\\b$method\\s*\\(').allMatches(source)) {
    final close = source.indexOf(')', match.start);
    final open = source.indexOf('{', close);
    if (close < 0 || open < 0) continue;
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}' && --depth == 0) {
        bodies.add(source.substring(open, i + 1));
        break;
      }
    }
  }
  return bodies;
}

final _caseLabel = RegExp(r'case\s+"([A-Za-z0-9_]+)"\s*:');

List<Registration> engineRegistrations() {
  final found = <String, Registration>{};
  for (final dir in enginePackages()) {
    final package = packageName(dir);
    for (final file in dartFiles(Directory('${dir.path}/lib'))) {
      final source = file.readAsStringSync();
      for (final (method, renders) in [
        ('createWidget', true),
        ('createService', false)
      ]) {
        for (final body in methodBodies(source, method)) {
          for (final m in _caseLabel.allMatches(body)) {
            found.putIfAbsent(
                m[1]!, () => Registration(package, m[1]!, renders: renders));
          }
        }
      }
    }
  }
  return found.values.toList();
}

/// Legacy wire names the core normalizes to a canonical type.
Map<String, String> controlTypeAliases() {
  final source = File('lib/src/models/control_type.dart')
      .readAsStringSync()
      .split('const Map<String, Map<String, Object?>>')[0];
  return {
    for (final m in RegExp(r'"(\w+)":\s*"(\w+)"').allMatches(source))
      m[1]!: m[2]!
  };
}

/// Ruby wire types: the exported surface plus [rubyExtensionTypes].
Map<String, String> rubyWireTypes() {
  final surface = jsonDecode(
          File('test/contract/ruflet_control_surface.json').readAsStringSync())
      as Map<String, dynamic>;
  final wire = (surface['wire_types'] as Map<String, dynamic>)
      .map((type, value) => MapEntry(type, (value as Map)['family'] as String));
  return {...wire, for (final t in rubyExtensionTypes.keys) t: 'visual'};
}

final _claimLine =
    RegExp(r'^\s*//\s*ruflet-coverage:\s*(.+)$', multiLine: true);

List<Claim> coverageClaims() => [
      for (final dir in enginePackages())
        for (final file in dartFiles(Directory('${dir.path}/test')))
          for (final m in _claimLine.allMatches(file.readAsStringSync()))
            for (final type in m[1]!.split(RegExp(r'[\s,]+')))
              if (type.isNotEmpty) Claim(packageName(dir), file, type)
    ];

/// Why [claim] is not accepted, or null when it is.
String? rejectClaim(Claim claim, {required bool renders}) {
  final source = claim.file.readAsStringSync();
  final type = claim.type;
  if (!source.contains("'$type'") && !source.contains('"$type"')) {
    return 'never builds the quoted wire type "$type"';
  }
  if (!RegExp(r'\b(test|testWidgets)\s*\(').hasMatch(source)) {
    return 'defines no test() or testWidgets()';
  }
  if (renders) {
    if (!_cupertinoMarkers.any(source.contains)) {
      return 'never renders the Cupertino design (no iOS/macOS marker)';
    }
    if (!_materialMarkers.any(source.contains)) {
      return 'never renders the Material design (no Android/desktop marker)';
    }
  }
  return null;
}

void main() {
  final registrations = engineRegistrations();
  final registered = {for (final r in registrations) r.type: r};
  final aliases = controlTypeAliases();
  final ruby = rubyWireTypes();
  final claims = coverageClaims();

  // Every type that needs a test: what the engine registers plus what Ruby
  // sends inside a parent. owner: package that must hold its test.
  final owners = <String, String>{
    for (final r in registrations) r.type: r.package,
    for (final e in childTypes.entries) e.key: e.value.$1,
  };
  bool renders(String type) => registered[type]?.renders ?? true;

  test('engine registrations and the Ruby surface parse', () {
    expect(registrations.where((r) => r.package == 'ruflet'), isNotEmpty);
    expect(registrations.where((r) => r.package != 'ruflet'), isNotEmpty,
        reason: 'no extension registrations found beside packages/ruflet');
    expect(ruby.length, greaterThan(200));
    expect(aliases['CupertinoButton'], 'Button');
  });

  test(
      'every Ruby wire type is registered, aliased, read by a parent, '
      'or explained', () {
    final unexplained = [
      for (final type in ruby.keys)
        if (!registered.containsKey(type) &&
            !registered.containsKey(aliases[type]) &&
            !childTypes.containsKey(type) &&
            !rubyOnlyTypes.containsKey(type))
          type
    ]..sort();
    expect(unexplained, isEmpty,
        reason: 'Ruby can send these but the engine has no renderer, alias '
            'or parent for them. Implement them, or add them to '
            'childTypes/rubyOnlyTypes with the evidence.');
    final staleRubyOnly = [
      for (final type in rubyOnlyTypes.keys)
        if (!ruby.containsKey(type) || registered.containsKey(type)) type
    ];
    expect(staleRubyOnly, isEmpty,
        reason: 'rubyOnlyTypes entries Ruby no longer sends or the engine '
            'now registers');
  });

  test('every registered type is one Ruby sends, or explained', () {
    final rubyCanonical = {
      for (final type in ruby.keys) aliases[type] ?? type,
      ...ruby.keys,
    };
    final unexplained = [
      for (final type in registered.keys)
        if (!rubyCanonical.contains(type) && !engineOnlyTypes.containsKey(type))
          type
    ]..sort();
    expect(unexplained, isEmpty,
        reason: 'The engine registers these but Ruby never sends them. '
            'Give them a Ruby counterpart or add them to engineOnlyTypes.');
    final staleEngineOnly = [
      for (final type in engineOnlyTypes.keys)
        if (!registered.containsKey(type) || ruby.containsKey(type)) type
    ];
    expect(staleEngineOnly, isEmpty,
        reason: 'engineOnlyTypes entries no longer registered or now sent '
            'by Ruby');
  });

  test('Ruby families match the engine registration, or are explained', () {
    final differing = [
      for (final r in registrations)
        if (ruby[r.type] case final family?)
          if ((family == 'service') == r.renders &&
              !familyDifferences.containsKey(r.type))
            '${r.type} (Ruby $family, engine '
                '${r.renders ? 'createWidget' : 'createService'})'
    ]..sort();
    expect(differing, isEmpty,
        reason: 'Ruby must route these the way the engine registers them; '
            'explain each in familyDifferences.');
  });

  test('every child type is still read as a child', () {
    expect([
      for (final t in childTypes.keys)
        if (registered.containsKey(t)) t
    ], isEmpty, reason: 'now registered directly: drop them from childTypes');
    expect([
      for (final e in childTypes.entries)
        if (!enginePackages().any((d) => packageName(d) == e.value.$1))
          '${e.key} -> ${e.value.$1}'
    ], isEmpty, reason: 'childTypes owner package missing');
  });

  test('every coverage claim is valid', () {
    final invalid = <String>[];
    for (final claim in claims) {
      final owner = owners[claim.type];
      if (owner == null) {
        invalid.add('${claim.path}: claims "${claim.type}", which is '
            'neither registered nor a child type');
        continue;
      }
      if (owner != claim.package) {
        invalid.add('${claim.path}: claims "${claim.type}", owned by '
            'packages/$owner; test it there');
        continue;
      }
      final why = rejectClaim(claim, renders: renders(claim.type));
      if (why != null) invalid.add('${claim.path}: ${claim.type} $why');
    }
    expect(invalid, isEmpty);
  });

  test('every registered and child type has a declared test', () {
    final covered = {
      for (final claim in claims)
        if (owners[claim.type] == claim.package &&
            rejectClaim(claim, renders: renders(claim.type)) == null)
          claim.type
    };
    final missing = [
      for (final type in owners.keys)
        if (!covered.contains(type) && !knownGaps.contains(type)) type
    ]..sort();
    final nowCovered = [
      for (final type in knownGaps)
        if (covered.contains(type)) type
    ]..sort();
    final unknownGaps = [
      for (final type in knownGaps)
        if (!owners.containsKey(type)) type
    ]..sort();

    final byPackage = <String, (int, int)>{};
    for (final entry in owners.entries) {
      final (all, done) = byPackage[entry.value] ?? (0, 0);
      byPackage[entry.value] =
          (all + 1, done + (covered.contains(entry.key) ? 1 : 0));
    }
    final report = StringBuffer('Control test coverage '
        '(${covered.length}/${owners.length} types)\n');
    for (final package in byPackage.keys.toList()..sort()) {
      final (all, done) = byPackage[package]!;
      report.writeln('  $package: $done/$all');
    }
    if (knownGaps.isNotEmpty) {
      report.writeln('  known gaps: ${knownGaps.length - nowCovered.length}');
    }
    if (nowCovered.isNotEmpty) {
      report.writeln('  covered now, drop from knownGaps: '
          '${nowCovered.join(' ')}');
    }
    // ignore: avoid_print
    print(report);

    expect(unknownGaps, isEmpty,
        reason: 'knownGaps entries that are not registered or child types');
    expect(missing, isEmpty,
        reason: 'Add a test that builds each of these from a protocol map, '
            'asserts its attributes and events on both designs, and declares '
            'it with `// ruflet-coverage: <Type>`: ${missing.join(' ')}');
  });
}
