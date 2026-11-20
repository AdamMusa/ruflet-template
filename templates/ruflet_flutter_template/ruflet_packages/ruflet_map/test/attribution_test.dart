// Map attributions as Ruby nests them in a Map: the text, logos, placement
// and colors each design renders, and the clicks it sends back to Ruby.
//
// ruflet-coverage: SimpleAttribution RichAttribution
// ruflet-coverage: TextSourceAttribution ImageSourceAttribution
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_map/ruflet_map.dart';

import 'support/harness.dart';

const designs = [TargetPlatform.iOS, TargetPlatform.android];

/// A 1x1 transparent PNG, so the logo needs no asset or network.
const pixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Future<Mounted> mountAttribution(WidgetTester tester, TargetPlatform design,
        Map<String, dynamic> layer) =>
    mountWire(tester, design, {
      '_c': 'Map',
      '_i': 1,
      'width': 600,
      'height': 300,
      'initial_center': {'latitude': 0, 'longitude': 0},
      'layers': [layer],
    }, extensions: [
      Extension()
    ]);

Finder openButton(TargetPlatform design) => find.byIcon(
    design == TargetPlatform.iOS ? CupertinoIcons.info : Icons.info_outlined);

/// The popup box: the rounded box holding the text attributions.
BoxDecoration popupBox(WidgetTester tester, String text) => tester
    .widgetList<DecoratedBox>(
        find.ancestor(of: find.text(text), matching: find.byType(DecoratedBox)))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.borderRadius != null);

void main() {
  for (final design in designs) {
    group('$design', () {
      testWidgets('SimpleAttribution shows its text where Ruby aligned it',
          (tester) async {
        final m = await mountAttribution(tester, design, {
          '_c': 'SimpleAttribution',
          '_i': 2,
          'text': 'Map data',
          'bgcolor': '#ffeeaa',
          'alignment': {'x': -1, 'y': 1},
          'on_click': true,
        });

        expect(find.text('Map data'), findsOneWidget);
        expect(find.text('flutter_map | © '), findsOneWidget);
        final box = find
            .ancestor(
                of: find.text('Map data'), matching: find.byType(ColoredBox))
            .first;
        expect(tester.widget<ColoredBox>(box).color, const Color(0xFFFFEEAA));
        final rect = tester.getRect(box);
        expect(rect.left, 0);
        expect(rect.bottom, 300);

        await tester.tap(find.text('Map data'));
        await tester.pumpAndSettle();
        expect(m.backend.events, [(id: 2, name: 'click', data: null)]);
      });

      testWidgets('SimpleAttribution defaults to the bottom-right corner',
          (tester) async {
        final m = await mountAttribution(tester, design, {
          '_c': 'SimpleAttribution',
          '_i': 2,
          'text': 'Map data',
        });
        final rect = tester.getRect(find
            .ancestor(
                of: find.text('Map data'), matching: find.byType(ColoredBox))
            .first);
        expect(rect.right, 600);
        expect(rect.bottom, 300);
        await tester.tap(find.text('Map data'));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
      });

      testWidgets(
          'RichAttribution keeps logos permanent and opens text sources',
          (tester) async {
        final m = await mountAttribution(tester, design, {
          '_c': 'RichAttribution',
          '_i': 2,
          'alignment': 'bottom_left',
          'permanent_height': 20,
          'popup_bgcolor': '#eeeeee',
          'show_flutter_map_attribution': false,
          'attributions': [
            {
              '_c': 'ImageSourceAttribution',
              '_i': 3,
              'height': 18,
              'tooltip': 'Logo',
              'on_click': true,
              'image': {
                '_c': 'Image',
                '_i': 4,
                'src': pixelPng,
                'width': 18,
                'height': 18,
              },
            },
            {
              '_c': 'TextSourceAttribution',
              '_i': 5,
              'text': 'OpenStreetMap',
              'prepend_copyright': true,
              'on_click': true,
            },
            {
              '_c': 'TextSourceAttribution',
              '_i': 6,
              'text': 'Plain',
              'prepend_copyright': false,
            },
          ],
        });

        // Collapsed: the logo and the open button only.
        final logo = find
            .ancestor(of: find.byType(Image), matching: find.byType(SizedBox))
            .first;
        expect(tester.getSize(logo).height, 18);
        expect(find.text('© OpenStreetMap').hitTestable(), findsNothing);
        expect(find.text("Made with 'flutter_map'"), findsNothing);
        final button = openButton(design);
        expect(tester.getSize(button), const Size(20, 20));
        // Bottom-left: the controls hug the map's left edge.
        expect(tester.getRect(button).left, lessThan(300));
        expect(tester.getRect(logo).bottom, lessThan(300));

        await tester.tap(logo);
        await tester.pumpAndSettle();
        expect(m.backend.events, [(id: 3, name: 'click', data: null)]);

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('© OpenStreetMap').hitTestable(), findsOneWidget);
        expect(find.text('Plain'), findsOneWidget);
        expect(find.text('© Plain'), findsNothing);
        final popup = popupBox(tester, 'Plain');
        expect(popup.color, const Color(0xFFEEEEEE));
        expect(popup.borderRadius, BorderRadius.circular(10));

        m.backend.events.clear();
        await tester.tap(find.text('© OpenStreetMap'));
        // flutter_map's 48px Material close button overlaps the lower half of
        // the last line, so tap the line's top edge.
        await tester
            .tapAt(tester.getTopLeft(find.text('Plain')) + const Offset(2, 2));
        await tester.pumpAndSettle();
        // Only the subscribed source reports its click.
        expect(m.backend.events, [(id: 5, name: 'click', data: null)]);
      });

      testWidgets('RichAttribution credits flutter_map by default',
          (tester) async {
        await mountAttribution(tester, design, {
          '_c': 'RichAttribution',
          '_i': 2,
          'attributions': [
            {'_c': 'TextSourceAttribution', '_i': 3, 'text': 'Source'},
          ],
        });
        expect(
            find.byWidgetPredicate((w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName ==
                    'lib/assets/flutter_map_logo.png'),
            findsOneWidget);
        // Bottom-right by default.
        expect(tester.getRect(openButton(design)).right, greaterThan(550));
        await tester.tap(openButton(design));
        await tester.pumpAndSettle();
        expect(find.text('© Source').hitTestable(), findsOneWidget);
        expect(
            find.text("Made with 'flutter_map'").hitTestable(), findsOneWidget);
      });

      testWidgets('RichAttribution popup shows for its initial duration',
          (tester) async {
        await mountAttribution(tester, design, {
          '_c': 'RichAttribution',
          '_i': 2,
          'popup_initial_display_duration': 1000,
          'show_flutter_map_attribution': false,
          'attributions': [
            {'_c': 'TextSourceAttribution', '_i': 3, 'text': 'Source'},
          ],
        });
        // Open after the map's layout events (which used to dismiss it on
        // iOS at once) until its timer ends.
        expect(find.text('© Source').hitTestable(), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('© Source').hitTestable(), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(find.text('© Source').hitTestable(), findsNothing);
      });

      testWidgets(
          'RichAttribution popup stays open when the map moves during its '
          'initial display', (tester) async {
        final m = await mountAttribution(tester, design, {
          '_c': 'RichAttribution',
          '_i': 2,
          'popup_initial_display_duration': 2000,
          'show_flutter_map_attribution': false,
          'attributions': [
            {'_c': 'TextSourceAttribution', '_i': 3, 'text': 'Source'},
          ],
        });
        // As flutter_map's widget does, only a popup the user opened closes
        // when the map moves.
        unawaited(m.root.invokeMethod(
            'zoom_in', {'duration': 500}, const Duration(seconds: 1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('© Source').hitTestable(), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
        expect(find.text('© Source').hitTestable(), findsNothing);
      });

      testWidgets('RichAttribution popup closes when the map moves',
          (tester) async {
        final m = await mountAttribution(tester, design, {
          '_c': 'RichAttribution',
          '_i': 2,
          'show_flutter_map_attribution': false,
          'attributions': [
            {'_c': 'TextSourceAttribution', '_i': 3, 'text': 'Source'},
          ],
        });
        await tester.tap(openButton(design));
        await tester.pumpAndSettle();
        expect(find.text('© Source').hitTestable(), findsOneWidget);

        unawaited(
            m.root.invokeMethod('zoom_in', null, const Duration(seconds: 1)));
        await tester.pumpAndSettle();
        expect(find.text('© Source').hitTestable(), findsNothing);
        expect(tester.widget<FlutterMap>(find.byType(FlutterMap)), isNotNull);
      });
    });
  }
}
