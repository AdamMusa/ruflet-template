import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

/// Runs [body] and returns the `Warning:` lines it printed.
List<String> _warnings(void Function() body) {
  final lines = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.startsWith('Warning:')) lines.add(message);
  };
  try {
    body();
  } finally {
    debugPrint = original;
  }
  return lines;
}

/// Every public [Curves] constant by its Dart name.
const _allCurves = <String, Curve>{
  'bounceIn': Curves.bounceIn,
  'bounceInOut': Curves.bounceInOut,
  'bounceOut': Curves.bounceOut,
  'decelerate': Curves.decelerate,
  'ease': Curves.ease,
  'easeIn': Curves.easeIn,
  'easeInBack': Curves.easeInBack,
  'easeInCirc': Curves.easeInCirc,
  'easeInCubic': Curves.easeInCubic,
  'easeInExpo': Curves.easeInExpo,
  'easeInOut': Curves.easeInOut,
  'easeInOutBack': Curves.easeInOutBack,
  'easeInOutCirc': Curves.easeInOutCirc,
  'easeInOutCubic': Curves.easeInOutCubic,
  'easeInOutCubicEmphasized': Curves.easeInOutCubicEmphasized,
  'easeInOutExpo': Curves.easeInOutExpo,
  'easeInOutQuad': Curves.easeInOutQuad,
  'easeInOutQuart': Curves.easeInOutQuart,
  'easeInOutQuint': Curves.easeInOutQuint,
  'easeInOutSine': Curves.easeInOutSine,
  'easeInQuad': Curves.easeInQuad,
  'easeInQuart': Curves.easeInQuart,
  'easeInQuint': Curves.easeInQuint,
  'easeInSine': Curves.easeInSine,
  'easeInToLinear': Curves.easeInToLinear,
  'easeOut': Curves.easeOut,
  'easeOutBack': Curves.easeOutBack,
  'easeOutCirc': Curves.easeOutCirc,
  'easeOutCubic': Curves.easeOutCubic,
  'easeOutExpo': Curves.easeOutExpo,
  'easeOutQuad': Curves.easeOutQuad,
  'easeOutQuart': Curves.easeOutQuart,
  'easeOutQuint': Curves.easeOutQuint,
  'easeOutSine': Curves.easeOutSine,
  'elasticIn': Curves.elasticIn,
  'elasticInOut': Curves.elasticInOut,
  'elasticOut': Curves.elasticOut,
  'fastEaseInToSlowEaseOut': Curves.fastEaseInToSlowEaseOut,
  'fastLinearToSlowEaseIn': Curves.fastLinearToSlowEaseIn,
  'fastOutSlowIn': Curves.fastOutSlowIn,
  'linear': Curves.linear,
  'linearToEaseOut': Curves.linearToEaseOut,
  'slowMiddle': Curves.slowMiddle,
};

/// The constant names declared by `Curves` in the Flutter SDK this package
/// resolves, read from its source (tests have no mirrors).
Set<String> _sdkCurveNames() {
  final config = File('.dart_tool/package_config.json');
  final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
  final rootUri =
      packages.firstWhere((p) => p['name'] == 'flutter')['rootUri'] as String;
  final root = config.absolute.uri
      .resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
  final source = File.fromUri(root.resolve('lib/src/animation/curves.dart'))
      .readAsStringSync();
  final start = source.indexOf('abstract final class Curves {');
  expect(start, isNonNegative, reason: 'Curves class not found');
  final body = source.substring(start, source.indexOf('\n}\n', start));
  return RegExp(r'^  static const \w+ (\w+) =', multiLine: true)
      .allMatches(body)
      .map((match) => match[1]!)
      .toSet();
}

void main() {
  group('parseCurve', () {
    test('every Flutter Curves constant parses by its snake_case name', () {
      for (final MapEntry(key: name, value: curve) in _allCurves.entries) {
        final snake = name.replaceAllMapped(
            RegExp('[A-Z]'), (match) => '_${match[0]!.toLowerCase()}');
        late Curve? parsed;
        expect(_warnings(() => parsed = parseCurve(snake)), isEmpty,
            reason: snake);
        expect(parsed, same(curve), reason: snake);
        expect(parseCurve(name), same(curve), reason: name);
      }
      expect(parseCurve('fast_ease_in_to_slow_ease_out'),
          Curves.fastEaseInToSlowEaseOut);
    });

    test('the curve list is every Curves constant of this Flutter SDK', () {
      // A Flutter upgrade that adds a curve fails here until parseCurve
      // and _allCurves know it.
      expect(_sdkCurveNames(), _allCurves.keys.toSet());
    });

    test('accepts camelCase, snake_case and any letter case', () {
      for (final name in [
        'easeInOut',
        'ease_in_out',
        'EASE_IN_OUT',
        'easeinout'
      ]) {
        expect(parseCurve(name), Curves.easeInOut, reason: name);
      }
      expect(parseCurve('fast_out_slow_in'), Curves.fastOutSlowIn);
      expect(
          parseCurve('fastLinearToSlowEaseIn'), Curves.fastLinearToSlowEaseIn);
      expect(parseCurve('ease_in_out_cubic_emphasized'),
          Curves.easeInOutCubicEmphasized);
      expect(parseCurve('bounce_out'), Curves.bounceOut);
    });

    test('knows linear, the Ruby AnimatedSwitcher default', () {
      expect(parseCurve('linear', Curves.ease), Curves.linear);
    });

    test('null keeps the default without a warning', () {
      late Curve? curve;
      final warnings = _warnings(() => curve = parseCurve(null, Curves.ease));
      expect(curve, Curves.ease);
      expect(warnings, isEmpty);
    });

    test('unknown names fall back to the default and print a warning', () {
      late Curve? curve;
      final warnings =
          _warnings(() => curve = parseCurve('wobbly', Curves.decelerate));
      expect(curve, Curves.decelerate);
      expect(warnings, ['Warning: unknown curve "wobbly"; using the default.']);
      expect(_warnings(() => curve = parseCurve('ease_wobble')), hasLength(1));
      expect(curve, isNull);
    });

    test('animation maps and AnimationStyle read snake_case curves', () {
      expect(parseAnimation({'duration': 200, 'curve': 'ease_out'})!.curve,
          Curves.easeOut);
      final style = parseAnimationStyle(
          {'curve': 'ease_in', 'reverse_curve': 'elastic_out'})!;
      expect(style.curve, Curves.easeIn);
      expect(style.reverseCurve, Curves.elasticOut);
    });
  });

  group('parseEnum', () {
    test('accepts camelCase, snake_case and any letter case', () {
      for (final name in [
        'spaceBetween',
        'space_between',
        'SPACE_BETWEEN',
        'spacebetween'
      ]) {
        expect(parseEnum(MainAxisAlignment.values, name),
            MainAxisAlignment.spaceBetween,
            reason: name);
      }
      expect(parseEnum(Clip.values, 'anti_alias_with_save_layer'),
          Clip.antiAliasWithSaveLayer);
      expect(parseEnum(ScrollViewKeyboardDismissBehavior.values, 'on_drag'),
          ScrollViewKeyboardDismissBehavior.onDrag);
    });

    test('unknown and null names keep the default', () {
      expect(parseEnum(Clip.values, 'anti_alias_x', Clip.none), Clip.none);
      expect(parseEnum(Clip.values, null, Clip.hardEdge), Clip.hardEdge);
      expect(parseEnum(Clip.values, 'nope'), isNull);
    });
  });

  test('name tables built from Dart names accept snake_case', () {
    expect(parseTextInputType('street_address'), TextInputType.streetAddress);
    expect(
        parseTextInputType('visiblePassword'), TextInputType.visiblePassword);
    expect(parseMouseCursor('all_scroll'), SystemMouseCursors.allScroll);
    expect(parseMouseCursor('contextMenu'), SystemMouseCursors.contextMenu);
    expect(parseAutofillHint('telephone_number_national'),
        AutofillHints.telephoneNumberNational);
    expect(parseAutofillContextAction('commit'), AutofillContextAction.commit);
    expect(parseVisualDensity('adaptive_platform_density'),
        VisualDensity.adaptivePlatformDensity);
    expect(parseTransitionsBuilder('fade_upwards'),
        isA<FadeUpwardsPageTransitionsBuilder>());
    expect(parseMarkdownExtensionSet('github_flavored'),
        md.ExtensionSet.gitHubFlavored);
    expect(parseFloatingActionButtonLocation('center_docked'),
        FloatingActionButtonLocation.centerDocked);
    // Unknown names still fall back.
    expect(parseTextInputType('street_adress', TextInputType.text),
        TextInputType.text);
    expect(parseMarkdownExtensionSet('github', md.ExtensionSet.none),
        md.ExtensionSet.none);
  });

  testWidgets('AnimatedSwitcher reads Ruby snake_case curves', (tester) async {
    final backend = RufletBackend(
        pageUri: Uri.parse('inprocess://curve-test'),
        assetsDir: '',
        extensions: [],
        multiView: false);
    final control = Control.fromMap({
      '_c': 'AnimatedSwitcher',
      '_i': 1,
      'switch_in_curve': 'ease_out_back',
      'switch_out_curve': 'fast_out_slow_in',
      'content': {'_c': 'Text', '_i': 2, 'value': 'Hi'},
    }, backend);
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: MaterialApp(home: ControlWidget(control: control))));
    final switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.switchInCurve, Curves.easeOutBack);
    expect(switcher.switchOutCurve, Curves.fastOutSlowIn);
  });
}
