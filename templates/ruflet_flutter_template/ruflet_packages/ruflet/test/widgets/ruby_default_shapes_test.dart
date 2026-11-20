// The alignment, padding and border-radius shapes Ruby's ruflet_core sends as
// defaults (AdamMusa/ruflet-engine#118): a named alignment string such as
// "center", and `{"all" => n}` padding and radius maps. Published gems send
// them, so the renderer has to read them, and every shape it read before has
// to keep its meaning.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';

// ruflet-coverage: FilledIconButton FilledTonalIconButton OutlinedIconButton TimerPicker

/// What `to_patch` gives for each control built with default arguments, on
/// ruflet main dd924eb3 (0.0.15 and 0.0.23 send the same values).
const _rubyDefaults = <String, Map<String, dynamic>>{
  'filled_icon_button': {
    '_c': 'FilledIconButton',
    '_i': 2,
    'alignment': 'center',
    'autofocus': false,
    'icon': 65604,
    'icon_size': 24,
    'padding': {'all': 8},
  },
  'filled_tonal_icon_button': {
    '_c': 'FilledTonalIconButton',
    '_i': 2,
    'alignment': 'center',
    'autofocus': false,
    'icon': 65604,
    'icon_size': 24,
    'padding': {'all': 8},
  },
  'outlined_icon_button': {
    '_c': 'OutlinedIconButton',
    '_i': 2,
    'alignment': 'center',
    'autofocus': false,
    'icon': 65604,
    'icon_size': 24,
    'padding': {'all': 8},
  },
  'cupertino_button': {
    '_c': 'Button',
    '_i': 2,
    'alignment': 'center',
    'autofocus': false,
    'border_radius': {'all': 8.0},
    'content': {'_c': 'Text', '_i': 3, 'value': 'Tap'},
    'opacity_on_click': 0.4,
    'size': 'large',
  },
  'cupertino_filled_button': {
    '_c': 'FilledButton',
    '_i': 2,
    'alignment': 'center',
    'autofocus': false,
    'border_radius': {'all': 8.0},
    'content': {'_c': 'Text', '_i': 3, 'value': 'Tap'},
    'opacity_on_click': 0.4,
    'size': 'large',
  },
  'cupertino_tinted_button': {
    '_c': 'FilledTonalButton',
    '_i': 2,
    'alignment': 'center',
    'autofocus': false,
    'border_radius': {'all': 8.0},
    'content': {'_c': 'Text', '_i': 3, 'value': 'Tap'},
    'opacity_on_click': 0.4,
    'size': 'large',
  },
  'cupertino_timer_picker': {
    '_c': 'TimerPicker',
    '_i': 2,
    'alignment': 'center',
    'item_extent': 32.0,
    'minute_interval': 1,
    'mode': 'hour_minute_seconds',
    'second_interval': 1,
    'value': 0,
  },
  'cupertino_text_field': {
    '_c': 'TextField',
    '_i': 2,
    'clear_button_semantics_label': 'Clear',
    'clear_button_visibility_mode': 'never',
    'padding': {'all': 7},
    'placeholder_text': '',
    'prefix_visibility_mode': 'always',
    'suffix_visibility_mode': 'always',
  },
};

Map<String, dynamic> _inColumn(Map<String, dynamic> child) => {
      '_c': 'Column',
      '_i': 1,
      'controls': [child],
    };

const _iconButtons = {
  'filled_icon_button',
  'filled_tonal_icon_button',
  'outlined_icon_button',
};
const _cupertinoButtons = {
  'cupertino_button',
  'cupertino_filled_button',
  'cupertino_tinted_button',
};

void main() {
  group('parseAlignment', () {
    test('reads every named alignment, folded like enum names', () {
      const named = {
        'top_left': Alignment.topLeft,
        'top_center': Alignment.topCenter,
        'top_right': Alignment.topRight,
        'center_left': Alignment.centerLeft,
        'center': Alignment.center,
        'center_right': Alignment.centerRight,
        'bottom_left': Alignment.bottomLeft,
        'bottom_center': Alignment.bottomCenter,
        'bottom_right': Alignment.bottomRight,
      };
      for (final MapEntry(key: name, value: expected) in named.entries) {
        expect(parseAlignment(name), expected, reason: name);
        expect(parseAlignment(name.toUpperCase()), expected, reason: name);
      }
      expect(parseAlignment('topLeft'), Alignment.topLeft);
      expect(parseAlignment('bottomRight'), Alignment.bottomRight);
    });

    test('gives the default for an unknown name', () {
      expect(parseAlignment('middle'), isNull);
      expect(parseAlignment('middle', Alignment.topRight), Alignment.topRight);
      expect(parseAlignment('', Alignment.center), Alignment.center);
    });

    test('keeps the {x, y} map and null meanings', () {
      expect(parseAlignment({'x': 0, 'y': 0}), Alignment.center);
      expect(parseAlignment({'x': -1, 'y': 1.0}), Alignment.bottomLeft);
      expect(parseAlignment({'x': 0.5}), const Alignment(0.5, 0));
      expect(parseAlignment(<String, dynamic>{}), Alignment.center);
      expect(parseAlignment(null), isNull);
      expect(parseAlignment(null, Alignment.topLeft), Alignment.topLeft);
    });
  });

  group('parseEdgeInsets', () {
    test('reads an {all: n} map', () {
      expect(parseEdgeInsets({'all': 8}), const EdgeInsets.all(8));
      expect(parseEdgeInsets({'all': 7.5}), const EdgeInsets.all(7.5));
      expect(parsePadding({'all': 8}), const EdgeInsets.all(8));
      expect(parseMargin({'all': 8}), const EdgeInsets.all(8));
      expect(parseEdgeInsetsDirectional({'all': 8}),
          const EdgeInsetsDirectional.all(8));
    });

    test('all fills only the sides the map does not name', () {
      expect(parseEdgeInsets({'all': 8, 'left': 2, 'bottom': 0}),
          const EdgeInsets.fromLTRB(2, 8, 8, 0));
      expect(parseEdgeInsetsDirectional({'all': 8, 'right': 1}),
          const EdgeInsetsDirectional.fromSTEB(8, 8, 1, 8));
    });

    test('keeps the number, side-map and null meanings', () {
      expect(parseEdgeInsets(8), const EdgeInsets.all(8));
      expect(parseEdgeInsets(2.5), const EdgeInsets.all(2.5));
      expect(parseEdgeInsets({'left': 1, 'top': 2, 'right': 3, 'bottom': 4}),
          const EdgeInsets.fromLTRB(1, 2, 3, 4));
      expect(parseEdgeInsets({'top': 5}), const EdgeInsets.only(top: 5));
      expect(parseEdgeInsets(<String, dynamic>{}), EdgeInsets.zero);
      expect(parseEdgeInsets(null), isNull);
      expect(parseEdgeInsets(null, const EdgeInsets.all(3)),
          const EdgeInsets.all(3));
      expect(parseEdgeInsetsDirectional({'left': 1, 'right': 3}),
          const EdgeInsetsDirectional.fromSTEB(1, 0, 3, 0));
    });

    test('a style padding state map reads {all: n} too', () {
      expect(parseWidgetStatePadding({'all': 8})?.resolve({}),
          const EdgeInsets.all(8));
      expect(
          parseWidgetStatePadding({
            'hovered': {'all': 4},
            'default': {'all': 8},
          })?.resolve({WidgetState.hovered}),
          const EdgeInsets.all(4));
    });
  });

  group('parseBorderRadius', () {
    test('reads an {all: n} map', () {
      expect(parseBorderRadius({'all': 8.0}), BorderRadius.circular(8));
      expect(parseBorderRadius({'all': 8}), BorderRadius.circular(8));
    });

    test('all fills only the corners the map does not name', () {
      expect(
          parseBorderRadius({'all': 8, 'top_left': 0}),
          const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8)));
    });

    test('keeps the number, corner-map and null meanings', () {
      expect(parseBorderRadius(6), BorderRadius.circular(6));
      expect(
          parseBorderRadius({'top_left': 1, 'bottom_right': 2}),
          const BorderRadius.only(
              topLeft: Radius.circular(1), bottomRight: Radius.circular(2)));
      expect(parseBorderRadius(<String, dynamic>{}), BorderRadius.zero);
      expect(parseBorderRadius(null), isNull);
    });
  });

  // The exact wire Ruby sends for each control built with default arguments
  // renders on both designs, with Flet's defaults: Alignment.CENTER,
  // IconButton padding 8, CupertinoButton radius 8, CupertinoTextField
  // padding 7.
  for (final design in HarnessDesign.values) {
    for (final MapEntry(key: name, value: wire) in _rubyDefaults.entries) {
      testWidgets('${design.name}: $name with default arguments renders',
          (tester) async {
        await mountWire(tester, design, _inColumn(wire), settle: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);

        if (_iconButtons.contains(name)) {
          if (design == HarnessDesign.android) {
            final button = tester
                .widget<material.IconButton>(find.byType(material.IconButton));
            expect(button.padding, const EdgeInsets.all(8));
            expect(button.alignment, Alignment.center);
          } else {
            final button =
                tester.widget<CupertinoButton>(find.byType(CupertinoButton));
            expect(button.padding, const EdgeInsets.all(8));
            expect(button.alignment, Alignment.center);
          }
        }
        if (_cupertinoButtons.contains(name) && design == HarnessDesign.ios) {
          final button =
              tester.widget<CupertinoButton>(find.byType(CupertinoButton));
          expect(button.borderRadius, BorderRadius.circular(8));
          expect(button.alignment, Alignment.center);
        }
        if (name == 'cupertino_timer_picker' && design == HarnessDesign.ios) {
          final picker = tester
              .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker));
          expect(picker.alignment, Alignment.center);
        }
        if (name == 'cupertino_text_field' && design == HarnessDesign.ios) {
          final field = tester
              .widget<CupertinoTextField>(find.byType(CupertinoTextField));
          expect(field.padding, const EdgeInsets.all(7));
        }
      });
    }
  }

  // A named alignment reaches the native widget, not just the parser.
  for (final design in HarnessDesign.values) {
    testWidgets('${design.name}: a named alignment places the icon',
        (tester) async {
      await mountWire(
          tester,
          design,
          _inColumn({
            '_c': 'FilledIconButton',
            '_i': 2,
            'icon': 65604,
            'alignment': 'bottom_right',
            'width': 120,
            'height': 120,
          }));
      expect(tester.takeException(), isNull);
      final alignment = design == HarnessDesign.android
          ? tester
              .widget<material.IconButton>(find.byType(material.IconButton))
              .alignment
          : tester
              .widget<CupertinoButton>(find.byType(CupertinoButton))
              .alignment;
      expect(alignment, Alignment.bottomRight);
    });
  }
}
