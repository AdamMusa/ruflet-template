import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

/// Records the events the real backend would deliver to Ruby.
///
/// [RufletBackend.triggerControlEvent] only forwards an event when the control
/// carries `on_<event>: true`, so overriding the by-id send keeps that gate.
class _Backend extends RufletBackend {
  final events = <(String, dynamic)>[];

  /// Every event a renderer fired, before the `on_<event>` gate.
  final fired = <String>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://dropdown-m2-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    fired.add(eventName);
    super.triggerControlEvent(control, eventName, eventData);
  }

  @override
  void triggerControlEventById(int controlId, String eventName,
      [dynamic eventData]) {
    events.add((eventName, eventData));
  }
}

const _constraints = {'min_width': 48, 'min_height': 40};

List<Map<String, dynamic>> _options() => [
      {'_c': 'DropdownOption', '_i': 10, 'key': 'red', 'text': 'Red'},
      {'_c': 'DropdownOption', '_i': 11, 'key': 'blue', 'text': 'Blue'},
    ];

/// A legacy `DropdownM2` node using Ruby's Dropdown2Control keywords.
Map<String, dynamic> _dropdownM2({bool disabled = false}) => {
      '_c': 'DropdownM2',
      '_i': 1,
      'width': 300,
      'hint_text': 'Color',
      'hint_content': {'_c': 'Text', '_i': 2, 'value': 'Pick a color'},
      'disabled_hint_content': {
        '_c': 'Text',
        '_i': 3,
        'value': 'Colors locked'
      },
      'prefix_icon_size_constraints': _constraints,
      'suffix_icon_size_constraints': _constraints,
      if (disabled) 'disabled': true,
      'on_change': true,
      'options': _options(),
    };

Future<(_Backend, Control)> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> wire) async {
  final backend = _Backend(platform);
  final control = Control.fromMap(wire, backend);
  final body = Align(
      alignment: Alignment.topLeft, child: ControlWidget(control: control));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorControl), findsNothing);
  return (backend, control);
}

/// Picks "Blue" through the native Cupertino picker sheet.
Future<void> _pickBlueOnCupertino(WidgetTester tester) async {
  await tester.tap(find.byType(CupertinoTextField));
  await tester.pumpAndSettle();
  tester
      .widget<CupertinoPicker>(find.byType(CupertinoPicker))
      .onSelectedItemChanged!(1);
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

void main() {
  group('DropdownM2 wire type', () {
    testWidgets('Material renders hint_content and fires change on select',
        (tester) async {
      final (backend, control) =
          await _pump(tester, TargetPlatform.android, _dropdownM2());

      expect(find.byType(material.DropdownButtonFormField<String>),
          findsOneWidget);
      expect(find.text('Pick a color'), findsOneWidget);
      expect(find.text('Colors locked'), findsNothing);

      await tester.tap(find.byType(material.DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // Options show their Ruby `text`, not their `key`.
      expect(find.text('blue'), findsNothing);
      await tester.tap(find.text('Blue').last);
      await tester.pumpAndSettle();

      expect(backend.events, [('change', 'blue')]);
      expect(control.getString('value'), 'blue');
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Pick a color'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Material renders disabled_hint_content when disabled',
        (tester) async {
      await _pump(tester, TargetPlatform.android, _dropdownM2(disabled: true));

      expect(find.text('Colors locked'), findsOneWidget);
      expect(find.text('Pick a color'), findsNothing);
    });

    testWidgets('Material reads prefix_icon_size_constraints', (tester) async {
      await _pump(tester, TargetPlatform.android, _dropdownM2());

      // DropdownButton replaces suffixIconConstraints to align its select
      // icon, so only the prefix constraint reaches the decoration.
      expect(
          tester
              .widget<material.InputDecorator>(
                  find.byType(material.InputDecorator))
              .decoration
              .prefixIconConstraints,
          const BoxConstraints(minWidth: 48, minHeight: 40));
    });

    testWidgets('shared form field decoration reads both constraint keys',
        (tester) async {
      await _pump(tester, TargetPlatform.android, {
        '_c': 'TextField',
        '_i': 1,
        'width': 300,
        'prefix_icon_size_constraints': _constraints,
        'suffix_icon_size_constraints': _constraints,
      });

      final decoration = tester
          .widget<material.InputDecorator>(find.byType(material.InputDecorator))
          .decoration;
      const expected = BoxConstraints(minWidth: 48, minHeight: 40);
      expect(decoration.prefixIconConstraints, expected);
      expect(decoration.suffixIconConstraints, expected);
    });

    testWidgets('Cupertino shows the hint placeholder and fires change',
        (tester) async {
      final (backend, control) =
          await _pump(tester, TargetPlatform.iOS, _dropdownM2());

      expect(find.byType(material.Material), findsNothing);
      expect(
          tester
              .widget<CupertinoTextField>(find.byType(CupertinoTextField))
              .placeholder,
          'Color');

      await _pickBlueOnCupertino(tester);

      expect(backend.events, [('change', 'blue')]);
      expect(control.getString('value'), 'blue');
      expect(tester.takeException(), isNull);
    });

    // Clients from before ruflet b9e52ff7 still send this wire, so the
    // Cupertino renderer keeps delivering `change` without branching on the
    // wire name: it fires the canonical `select`, and the control_type.dart
    // alias table delivers it under the name the old client subscribed to.
    testWidgets('Cupertino fires select, delivered to the legacy on_change',
        (tester) async {
      final (backend, _) =
          await _pump(tester, TargetPlatform.iOS, _dropdownM2());

      await _pickBlueOnCupertino(tester);

      expect(backend.fired, contains('select'));
      expect(backend.fired, isNot(contains('change')));
      expect(backend.events, [('change', 'blue')]);
    });
  });

  // Ruby's dropdown, dropdown_m2 and dropdownm2 all emit the canonical
  // Dropdown wire type, with dropdownm2's on_change sent as on_select and
  // max_menu_height sent as menu_height.
  group('Dropdown as emitted by Ruby dropdown_m2', () {
    Map<String, dynamic> canonical() => {
          '_c': 'Dropdown',
          '_i': 1,
          'width': 300,
          'hint_text': 'Color',
          'menu_height': 200,
          'on_select': true,
          'options': _options(),
        };

    testWidgets('Material fires select with the chosen value', (tester) async {
      final (backend, control) =
          await _pump(tester, TargetPlatform.android, canonical());

      final menu = tester.widget<material.DropdownMenu<String>>(
          find.byType(material.DropdownMenu<String>));
      expect(menu.menuHeight, 200);
      expect(menu.hintText, 'Color');

      await tester.tap(find.byType(material.DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue').last);
      await tester.pumpAndSettle();

      expect(backend.events, [('select', 'blue')]);
      expect(control.getString('value'), 'blue');
      expect(tester.takeException(), isNull);
    });

    // `canonical()` is exactly what ruflet main emits for
    // `dropdown_m2(on_change:, max_menu_height: 200)`; Ruby dispatches the
    // `select` event to that on_change handler
    // (test_dropdown_m2_on_change_fires_on_the_canonical_select_event).
    testWidgets('Cupertino delivers dropdown_m2(on_change:) once, as select',
        (tester) async {
      final (backend, _) =
          await _pump(tester, TargetPlatform.iOS, canonical());

      await _pickBlueOnCupertino(tester);

      expect(backend.fired, isNot(contains('change')));
      expect(backend.events, [('select', 'blue')]);
    });

    testWidgets('Cupertino fires select with the chosen value', (tester) async {
      final (backend, control) =
          await _pump(tester, TargetPlatform.iOS, canonical());

      await _pickBlueOnCupertino(tester);

      expect(backend.events, [('select', 'blue')]);
      expect(control.getString('value'), 'blue');
      expect(tester.takeException(), isNull);
    });
  });

  // Flet 1.0's DropdownM2.menu_border_radius rounds the open menu, while
  // border_radius keeps rounding the field (Ruby's dropdown_m2 sends both on
  // the Dropdown wire).
  group('menu_border_radius', () {
    const menuRadius = BorderRadius.all(Radius.circular(12));

    Map<String, dynamic> rounded({bool menu = true}) => {
          '_c': 'Dropdown',
          '_i': 1,
          'width': 300,
          'border_radius': 4,
          if (menu) 'menu_border_radius': 12,
          'options': _options(),
        };

    testWidgets('Material Dropdown rounds the open menu, not the field',
        (tester) async {
      await _pump(tester, TargetPlatform.android, rounded());

      final menu = tester.widget<material.DropdownMenu<String>>(
          find.byType(material.DropdownMenu<String>));
      expect(menu.menuStyle!.shape!.resolve({}),
          const material.RoundedRectangleBorder(borderRadius: menuRadius));
      final field =
          menu.inputDecorationTheme as material.InputDecorationThemeData;
      expect((field.border! as material.OutlineInputBorder).borderRadius,
          const BorderRadius.all(Radius.circular(4)));

      await tester.tap(find.byType(material.DropdownMenu<String>));
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate((widget) =>
              widget is material.Material &&
              widget.shape ==
                  const material.RoundedRectangleBorder(
                      borderRadius: menuRadius)),
          findsOneWidget,
          reason: 'the open menu surface takes the radius');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Material Dropdown without it keeps the theme menu shape',
        (tester) async {
      await _pump(tester, TargetPlatform.android, rounded(menu: false));

      final menu = tester.widget<material.DropdownMenu<String>>(
          find.byType(material.DropdownMenu<String>));
      expect(menu.menuStyle?.shape, isNull);
    });

    testWidgets(
        'Material DropdownM2 rounds its menu, border_radius as fallback',
        (tester) async {
      final (_, control) = await _pump(tester, TargetPlatform.android,
          {..._dropdownM2(), 'border_radius': 4, 'menu_border_radius': 12});
      material.DropdownButton<String> button() =>
          tester.widget<material.DropdownButton<String>>(
              find.byType(material.DropdownButton<String>));
      expect(button().borderRadius, menuRadius);

      control.update({'menu_border_radius': null}, shouldNotify: true);
      await tester.pumpAndSettle();
      expect(button().borderRadius, const BorderRadius.all(Radius.circular(4)));
    });

    testWidgets('Cupertino rounds the options sheet', (tester) async {
      await _pump(tester, TargetPlatform.iOS, rounded());
      await tester.tap(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();

      final clip = find.ancestor(
          of: find.byType(CupertinoPopupSurface),
          matching: find.byType(ClipRRect));
      expect(clip, findsOneWidget);
      expect(tester.widget<ClipRRect>(clip).borderRadius, menuRadius);
      expect(find.byType(material.Material), findsNothing);
    });

    testWidgets('Cupertino without it keeps the native sheet', (tester) async {
      await _pump(tester, TargetPlatform.iOS, rounded(menu: false));
      await tester.tap(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoPopupSurface), findsOneWidget);
      expect(
          find.ancestor(
              of: find.byType(CupertinoPopupSurface),
              matching: find.byType(ClipRRect)),
          findsNothing);
    });
  });
}
