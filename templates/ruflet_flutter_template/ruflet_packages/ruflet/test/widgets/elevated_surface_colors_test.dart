// Colour roles a Ruby control reads on a raised iOS surface resolve to the
// shade UIKit uses there. In dark mode "surface" is black on the page but the
// elevated system background inside an AlertDialog (CupertinoAlertDialog) or
// a BottomSheet (a Cupertino modal popup), for state maps as the Cupertino
// renderers resolved them before the shared control core and for plain
// colours alike. Material dialogs keep the theme's surface.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_button.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:ruflet/src/widgets/ruflet_cupertino_list_tile.dart';

import '../support/control_harness.dart';

const _base = Color(0xFF000000);
final _elevated = CupertinoColors.systemBackground.darkElevatedColor;

/// One control of every migrated core, each painting "surface".
List<Map<String, dynamic>> _controls() => [
      {
        '_c': 'Switch',
        '_i': 10,
        'value': true,
        'thumb_color': {'selected': 'surface'},
        'track_outline_color': {'selected': 'surface'},
        'active_track_color': 'surface',
      },
      {
        '_c': 'Checkbox',
        '_i': 11,
        'value': true,
        'label': 'Check',
        'fill_color': {'selected': 'surface'},
        'border_side': {'color': 'surface', 'width': 2},
        'label_style': {'color': 'surface'},
        'active_color': 'surface',
      },
      {
        '_c': 'RadioGroup',
        '_i': 12,
        'value': 'a',
        'content': {
          '_c': 'Radio',
          '_i': 13,
          'value': 'a',
          'fill_color': {'selected': 'surface'},
        },
      },
      {'_c': 'Button', '_i': 14, 'content': 'Go', 'bgcolor': 'surface'},
      {'_c': 'IconButton', '_i': 15, 'icon': 0xe047, 'icon_color': 'surface'},
      {'_c': 'ListTile', '_i': 16, 'title': 'Tile', 'bgcolor': 'surface'},
      {'_c': 'ProgressRing', '_i': 17, 'value': 0.5, 'color': 'surface'},
      {'_c': 'AppBar', '_i': 18, 'title': 'Bar', 'bgcolor': 'surface'},
    ];

Map<String, dynamic> _column() =>
    {'_c': 'Column', '_i': 2, 'controls': _controls()};

Future<void> _mount(
    WidgetTester tester, PageDesign design, Map<String, dynamic> wire) async {
  final backend = HarnessBackend(design == PageDesign.cupertino
      ? HarnessDesign.ios
      : HarnessDesign.android);
  final root = Control.fromMap(copyWire(wire), backend);
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: PlatformApp(
      design: design,
      config: PlatformAppConfig(
        title: 'test',
        showSemanticsDebugger: false,
        home: design == PageDesign.cupertino
            ? CupertinoPageScaffold(child: ControlWidget(control: root))
            : material.Scaffold(body: ControlWidget(control: root)),
        routerDelegate: null,
        routeInformationParser: null,
        routeInformationProvider: null,
        themeMode: RufletThemeMode.dark,
        platformBrightness: Brightness.dark,
        localizationsDelegates: const [],
        supportedLocales: const [Locale('en')],
        locale: const Locale('en'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// What every migrated core painted for "surface" on iOS.
Map<String, Color?> _cupertinoColors(WidgetTester tester) {
  const selected = {WidgetState.selected};
  final toggle = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
  final checkbox =
      tester.widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox));
  final radio = tester
      .widget<CupertinoRadio<String>>(find.byType(CupertinoRadio<String>));
  final button = tester.widget<CupertinoButton>(find.ancestor(
      of: find.text('Go'), matching: find.byType(CupertinoButton)));
  final icon = tester.widget<Icon>(find.descendant(
      of: find.byType(CupertinoIconButtonSkin), matching: find.byType(Icon)));
  return {
    'Switch.thumb_color': toggle.thumbColor,
    'Switch.track_outline_color': toggle.trackOutlineColor?.resolve(selected),
    'Switch.active_track_color': toggle.activeTrackColor,
    'Checkbox.fill_color': checkbox.fillColor?.resolve(selected),
    'Checkbox.border_side':
        WidgetStateProperty.resolveAs<BorderSide?>(checkbox.side, selected)
            ?.color,
    'Checkbox.label_style':
        tester.widget<Text>(find.text('Check')).style?.color,
    'Checkbox.active_color': checkbox.activeColor,
    'Radio.fill_color': radio.fillColor,
    'Button.bgcolor': button.color,
    'IconButton.icon_color': icon.color,
    'ListTile.bgcolor': tester
        .widget<RufletCupertinoListTile>(find.byType(RufletCupertinoListTile))
        .backgroundColor,
    'ProgressRing.color': tester
        .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator))
        .color,
    'AppBar.bgcolor': tester
        .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar))
        .backgroundColor,
  };
}

Matcher _all(Color color) => isA<Map<String, Color?>>()
    .having((m) => m.values.toSet(), 'colours', {color});

void main() {
  group('iOS dark mode', () {
    testWidgets('"surface" on the page is the base shade', (tester) async {
      await _mount(tester, PageDesign.cupertino, _column());
      expect(_cupertinoColors(tester), _all(_base));
    });

    testWidgets('"surface" in an AlertDialog is the elevated shade',
        (tester) async {
      await _mount(tester, PageDesign.cupertino, {
        '_c': 'AlertDialog',
        '_i': 1,
        'open': true,
        'title': 'Dialog',
        'content': _column(),
      });
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(_cupertinoColors(tester), _all(_elevated));
    });

    testWidgets('"surface" in a BottomSheet is the elevated shade',
        (tester) async {
      await _mount(tester, PageDesign.cupertino, {
        '_c': 'BottomSheet',
        '_i': 1,
        'open': true,
        'scrollable': true,
        'content': _column(),
      });
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(_cupertinoColors(tester), _all(_elevated));
    });

    testWidgets('a control theme inside a dialog keeps the elevated shade',
        (tester) async {
      await _mount(tester, PageDesign.cupertino, {
        '_c': 'AlertDialog',
        '_i': 1,
        'open': true,
        'title': 'Dialog',
        'content': {
          '_c': 'Container',
          '_i': 3,
          'theme': {'font_family': 'Courier'},
          'content': _column(),
        },
      });
      expect(_cupertinoColors(tester), _all(_elevated));
    });
  });

  testWidgets('Material dialog resolves "surface" to the theme surface',
      (tester) async {
    await _mount(tester, PageDesign.material, {
      '_c': 'AlertDialog',
      '_i': 1,
      'open': true,
      'title': 'Dialog',
      'content': _column(),
    });
    final surface =
        material.Theme.of(tester.element(find.byType(material.AlertDialog)))
            .colorScheme
            .surface;
    final toggle = tester.widget<material.Switch>(find.byType(material.Switch));
    final checkbox =
        tester.widget<material.Checkbox>(find.byType(material.Checkbox));
    expect(toggle.thumbColor?.resolve({WidgetState.selected}), surface);
    expect(toggle.activeTrackColor, surface);
    expect(checkbox.fillColor?.resolve({WidgetState.selected}), surface);
  });
}
