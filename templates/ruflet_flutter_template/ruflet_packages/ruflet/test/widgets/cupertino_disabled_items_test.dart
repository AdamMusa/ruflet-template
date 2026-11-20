// Ruby's dropdown_option(disabled:) and navigation_bar_destination(disabled:)
// cannot be chosen on either design. The Material renderers pass the flag to
// DropdownMenuEntry.enabled and NavigationDestination.enabled; the Cupertino
// renderers (used on every iOS and macOS app) must honor it as well.
//
// ruflet-coverage: Dropdown DropdownOption NavigationBar NavigationBarDestination
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

/// A Dropdown as Ruby's DSL sends it: `Ruflet.dropdown_option(key:, text:,
/// disabled: true)` puts `disabled: true` on the option.
Map<String, dynamic> _dropdown({
  String? value,
  bool placeholderDisabled = true,
  bool bananaDisabled = true,
  bool allDisabled = false,
}) =>
    {
      '_c': 'Column',
      '_i': 1,
      'controls': [
        {
          '_c': 'Dropdown',
          '_i': 10,
          'width': 300,
          if (value != null) 'value': value,
          'options': [
            {
              '_c': 'DropdownOption',
              '_i': 11,
              if (placeholderDisabled || allDisabled) 'disabled': true,
              'key': 'none',
              'text': 'Choose a fruit',
              'on_click': true,
            },
            {
              '_c': 'DropdownOption',
              '_i': 12,
              if (allDisabled) 'disabled': true,
              'key': 'apple',
              'text': 'Apple',
              'on_click': true,
            },
            {
              '_c': 'DropdownOption',
              '_i': 13,
              if (bananaDisabled || allDisabled) 'disabled': true,
              'key': 'banana',
              'text': 'Banana',
              'on_click': true,
            },
            {
              '_c': 'DropdownOption',
              '_i': 14,
              if (allDisabled) 'disabled': true,
              'key': 'cherry',
              'text': 'Cherry',
              'on_click': true,
            },
          ],
          'on_select': true,
        }
      ],
    };

/// A NavigationBar as Ruby's DSL sends it, with the middle destination
/// `navigation_bar_destination(disabled: true)`.
Map<String, dynamic> _navBar() => {
      '_c': 'NavigationBar',
      '_i': 20,
      'destinations': [
        {
          '_c': 'NavigationBarDestination',
          '_i': 21,
          'icon': {'_c': 'Text', '_i': 31, 'value': 'H'},
          'label': 'Home',
        },
        {
          '_c': 'NavigationBarDestination',
          '_i': 22,
          'disabled': true,
          'icon': {'_c': 'Text', '_i': 32, 'value': 'A'},
          'label': 'Admin',
        },
        {
          '_c': 'NavigationBarDestination',
          '_i': 23,
          'icon': {'_c': 'Text', '_i': 33, 'value': 'S'},
          'label': 'Settings',
        },
      ],
      'selected_index': 0,
      'on_change': true,
    };

List<Map<String, Object?>> _sent(HarnessMount m) =>
    m.backend.sent.map((s) => s.toJson()).toList();

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(CupertinoTextField));
  await tester.pumpAndSettle();
}

CupertinoPicker _picker(WidgetTester tester) =>
    tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));

CupertinoButton _doneButton(WidgetTester tester) =>
    tester.widget<CupertinoButton>(find.ancestor(
        of: find.text('Done'), matching: find.byType(CupertinoButton)));

/// The opacity the picker row showing [text] is drawn with.
double _rowOpacity(WidgetTester tester, String text) {
  final row = find.descendant(
      of: find.byType(CupertinoPicker), matching: find.text(text));
  final opacity =
      find.ancestor(of: row, matching: find.byType(Opacity)).evaluate();
  return opacity.isEmpty ? 1.0 : (opacity.first.widget as Opacity).opacity;
}

void main() {
  group('Cupertino Dropdown (HarnessDesign.ios)', () {
    testWidgets('opens on the first enabled option, not a disabled placeholder',
        (tester) async {
      final m = await mountWire(tester, HarnessDesign.ios, _dropdown());
      await _openSheet(tester);

      expect(_picker(tester).scrollController!.initialItem, 1);
      expect(_doneButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(_sent(m), [
        {
          'id': 10,
          'update': {'value': 'apple', 'text': 'Apple'}
        },
        {'id': 10, 'event': 'select', 'data': 'apple'},
        {'id': 12, 'event': 'click', 'data': null},
      ]);
      expect(m.control(10).get('value'), 'apple');
    });

    testWidgets('a disabled option scrolled into the middle cannot be picked',
        (tester) async {
      final m =
          await mountWire(tester, HarnessDesign.ios, _dropdown(value: 'apple'));
      await _openSheet(tester);
      expect(_picker(tester).scrollController!.initialItem, 1);

      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -42));
      await tester.pumpAndSettle();
      expect(_picker(tester).scrollController!.selectedItem, 2);

      expect(_doneButton(tester).onPressed, isNull);
      await tester.tap(find.text('Done'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // The sheet stays open and nothing reaches Ruby.
      expect(find.byType(CupertinoPicker), findsOneWidget);
      expect(_sent(m), isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsNothing);
      expect(_sent(m), isEmpty);
      expect(m.control(10).get('value'), 'apple');
    });

    testWidgets('scrolling back to an enabled option turns Done back on',
        (tester) async {
      final m =
          await mountWire(tester, HarnessDesign.ios, _dropdown(value: 'apple'));
      await _openSheet(tester);

      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -84));
      await tester.pumpAndSettle();
      expect(_picker(tester).scrollController!.selectedItem, 3);
      expect(_doneButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(_sent(m), [
        {
          'id': 10,
          'update': {'value': 'cherry', 'text': 'Cherry'}
        },
        {'id': 10, 'event': 'select', 'data': 'cherry'},
        {'id': 14, 'event': 'click', 'data': null},
      ]);
    });

    testWidgets('disabled rows are dimmed, enabled rows are not',
        (tester) async {
      await mountWire(tester, HarnessDesign.ios, _dropdown(value: 'apple'));
      await _openSheet(tester);

      expect(_rowOpacity(tester, 'Choose a fruit'), lessThan(1.0));
      expect(_rowOpacity(tester, 'Banana'), lessThan(1.0));
      expect(_rowOpacity(tester, 'Apple'), 1.0);
      expect(_rowOpacity(tester, 'Cherry'), 1.0);
    });

    testWidgets('a value on a disabled option opens on the first enabled one',
        (tester) async {
      final m = await mountWire(
          tester, HarnessDesign.ios, _dropdown(value: 'banana'));
      await _openSheet(tester);

      expect(_picker(tester).scrollController!.initialItem, 1);
      expect(_doneButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(_sent(m), [
        {
          'id': 10,
          'update': {'value': 'apple', 'text': 'Apple'}
        },
        {'id': 10, 'event': 'select', 'data': 'apple'},
        {'id': 12, 'event': 'click', 'data': null},
      ]);
    });

    testWidgets('Done turns off when Ruby disables the centred option',
        (tester) async {
      final m =
          await mountWire(tester, HarnessDesign.ios, _dropdown(value: 'apple'));
      await _openSheet(tester);
      expect(_doneButton(tester).onPressed, isNotNull);

      m.control(12).update({'disabled': true}, shouldNotify: true);
      await tester.pump();
      expect(_doneButton(tester).onPressed, isNull);
      expect(_rowOpacity(tester, 'Apple'), lessThan(1.0));

      await tester.tap(find.text('Done'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsOneWidget);
      expect(_sent(m), isEmpty);
      expect(m.control(10).get('value'), 'apple');
    });

    testWidgets(
        'an option Ruby disables in the same frame as Done is not chosen',
        (tester) async {
      final m =
          await mountWire(tester, HarnessDesign.ios, _dropdown(value: 'apple'));
      await _openSheet(tester);

      // No frame runs between Ruby's change and the tap, so Done is still on.
      m.control(12).update({'disabled': true}, shouldNotify: true);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoPicker), findsNothing);
      expect(_sent(m), isEmpty);
      expect(m.control(10).get('value'), 'apple');
    });

    testWidgets('Done turns back on when Ruby enables the centred option',
        (tester) async {
      final m =
          await mountWire(tester, HarnessDesign.ios, _dropdown(value: 'apple'));
      await _openSheet(tester);
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -42));
      await tester.pumpAndSettle();
      expect(_doneButton(tester).onPressed, isNull);

      m.control(13).update({'disabled': false}, shouldNotify: true);
      await tester.pump();
      expect(_doneButton(tester).onPressed, isNotNull);
      expect(_rowOpacity(tester, 'Banana'), 1.0);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(_sent(m), [
        {
          'id': 10,
          'update': {'value': 'banana', 'text': 'Banana'}
        },
        {'id': 10, 'event': 'select', 'data': 'banana'},
        {'id': 13, 'event': 'click', 'data': null},
      ]);
    });

    for (final (id, name) in [(10, 'the Dropdown'), (1, 'its Column')]) {
      testWidgets('Done turns off when Ruby disables $name while it is open',
          (tester) async {
        final m = await mountWire(
            tester, HarnessDesign.ios, _dropdown(value: 'apple'));
        await _openSheet(tester);
        expect(_doneButton(tester).onPressed, isNotNull);

        m.control(id).update({'disabled': true}, shouldNotify: true);
        await tester.pump();
        expect(_doneButton(tester).onPressed, isNull);
        expect(_rowOpacity(tester, 'Apple'), lessThan(1.0));

        await tester.tap(find.text('Done'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(_sent(m), isEmpty);
        expect(m.control(10).get('value'), 'apple');
      });
    }

    testWidgets('with every option disabled Done does nothing', (tester) async {
      final m = await mountWire(
          tester, HarnessDesign.ios, _dropdown(allDisabled: true));
      await _openSheet(tester);

      expect(_picker(tester).scrollController!.initialItem, 0);
      expect(_doneButton(tester).onPressed, isNull);
      await tester.tap(find.text('Done'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_sent(m), isEmpty);
    });

    testWidgets('with every option disabled it opens on the value\'s row',
        (tester) async {
      final m = await mountWire(tester, HarnessDesign.ios,
          _dropdown(value: 'banana', allDisabled: true));
      await _openSheet(tester);

      expect(_picker(tester).scrollController!.initialItem, 2);
      expect(_doneButton(tester).onPressed, isNull);
      await tester.tap(find.text('Done'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_sent(m), isEmpty);
    });

    testWidgets('without disabled options the sheet is unchanged',
        (tester) async {
      final m = await mountWire(tester, HarnessDesign.ios,
          _dropdown(placeholderDisabled: false, bananaDisabled: false));
      await _openSheet(tester);

      expect(_picker(tester).scrollController!.initialItem, 0);
      expect(_rowOpacity(tester, 'Choose a fruit'), 1.0);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(_sent(m), [
        {
          'id': 10,
          'update': {'value': 'none', 'text': 'Choose a fruit'}
        },
        {'id': 10, 'event': 'select', 'data': 'none'},
        {'id': 11, 'event': 'click', 'data': null},
      ]);
    });
  });

  testWidgets(
      'Material Dropdown (HarnessDesign.android) keeps disabled entries',
      (tester) async {
    final m = await mountWire(
        tester, HarnessDesign.android, _dropdown(value: 'apple'));
    final menu = tester.widget<material.DropdownMenu<String>>(
        find.byType(material.DropdownMenu<String>));
    expect({
      for (final e in menu.dropdownMenuEntries) e.value: e.enabled
    }, {
      'none': false,
      'apple': true,
      'banana': false,
      'cherry': true,
    });

    await tester.tap(find.byType(material.DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_sent(m).where((s) => s['event'] == 'select'), isEmpty);
    expect(m.control(10).get('value'), 'apple');
  });

  for (final design in HarnessDesign.values) {
    group('NavigationBar (${design.name})', () {
      testWidgets('a disabled destination cannot be selected', (tester) async {
        final m = await mountWire(tester, design, _navBar());

        await tester.tap(find.text('Admin'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(_sent(m), isEmpty);
        expect(m.control(20).get('selected_index'), 0);
        if (design == HarnessDesign.ios) {
          expect(
              tester
                  .widget<CupertinoTabBar>(find.byType(CupertinoTabBar))
                  .currentIndex,
              0);
        }
      });

      testWidgets('an enabled destination is still selected', (tester) async {
        final m = await mountWire(tester, design, _navBar());

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(_sent(m), [
          {
            'id': 20,
            'update': {'selected_index': 2}
          },
          {'id': 20, 'event': 'change', 'data': 2},
        ]);
        expect(m.control(20).get('selected_index'), 2);
      });
    });
  }
}
