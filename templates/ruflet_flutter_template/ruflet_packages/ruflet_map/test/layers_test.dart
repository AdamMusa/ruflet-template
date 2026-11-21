// Map layers: the flutter_map layer each wire layer renders, with the child
// markers Ruby nests in it, on both designs.
//
// ruflet-coverage: TileLayer MarkerLayer CircleLayer PolygonLayer PolylineLayer
// ruflet-coverage: Marker CircleMarker PolygonMarker PolylineMarker
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruflet_map/ruflet_map.dart';

import 'support/harness.dart';

const designs = [TargetPlatform.iOS, TargetPlatform.android];

Map<String, dynamic> latLng(double latitude, double longitude) =>
    {'latitude': latitude, 'longitude': longitude};

/// A 400x300 Map centered on (0, 0) holding [layers].
Future<Mounted> mountLayers(
        WidgetTester tester, TargetPlatform design, List<Object> layers) =>
    mountWire(tester, design, {
      '_c': 'Map',
      '_i': 1,
      'width': 400,
      'height': 300,
      'initial_center': latLng(0, 0),
      'initial_zoom': 5,
      'layers': layers,
    }, extensions: [
      Extension()
    ]);

/// A 1x1 transparent PNG.
const pixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

/// Tiles far outside the camera, so the layer requests none in tests.
final offscreenTiles = {
  'corner_1': latLng(80, 170),
  'corner_2': latLng(81, 171),
};

void main() {
  for (final design in designs) {
    group('$design', () {
      testWidgets('TileLayer hands flutter_map the wire configuration',
          (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'TileLayer',
            '_i': 2,
            'url_template': 'https://{s}.tiles.test/{z}/{x}/{y}.png',
            'fallback_url': 'https://fallback.tiles.test/{z}/{x}/{y}.png',
            'subdomains': ['one', 'two'],
            'tile_size': 512,
            'user_agent_package_name': 'dev.ruflet.test',
            'min_native_zoom': 2,
            'max_native_zoom': 16,
            'zoom_reverse': true,
            'zoom_offset': 1,
            'keep_buffer': 4,
            'pan_buffer': 2,
            'enable_tms': true,
            'tile_bounds': offscreenTiles,
            'max_zoom': 18,
            'min_zoom': 1,
            'evict_error_tile_strategy': 'not_visible_respect_margin',
            'additional_options': {'token': 'abc', 'size': 2},
            'display_mode': {'_type': 'instantaneous', 'opacity': 0.5},
          },
        ]);

        final layer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(layer.urlTemplate, 'https://{s}.tiles.test/{z}/{x}/{y}.png');
        expect(
            layer.fallbackUrl, 'https://fallback.tiles.test/{z}/{x}/{y}.png');
        expect(layer.subdomains, ['one', 'two']);
        expect(layer.tileDimension, 512);
        expect(layer.tileProvider.headers['User-Agent'],
            'flutter_map (dev.ruflet.test)');
        expect(layer.minNativeZoom, 2);
        expect(layer.maxNativeZoom, 16);
        expect(layer.zoomReverse, isTrue);
        expect(layer.zoomOffset, 1.0);
        expect(layer.keepBuffer, 4);
        expect(layer.panBuffer, 2);
        expect(layer.tms, isTrue);
        expect(layer.tileBounds,
            LatLngBounds(const LatLng(80, 170), const LatLng(81, 171)));
        expect(layer.maxZoom, 18.0);
        expect(layer.minZoom, 1.0);
        expect(layer.evictErrorTileStrategy,
            EvictErrorTileStrategy.notVisibleRespectMargin);
        expect(layer.additionalOptions, {'token': 'abc', 'size': '2'});
        expect(
            layer.tileDisplay, const TileDisplay.instantaneous(opacity: 0.5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('TileLayer retina mode halves the tile grid', (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'TileLayer',
            '_i': 2,
            'url_template': 'https://tiles.test/{z}/{x}/{y}.png',
            'tile_bounds': offscreenTiles,
            'enable_retina_mode': true,
            'max_zoom': 18,
            'error_image_src': pixelPng,
          },
        ]);
        final layer = tester.widget<TileLayer>(find.byType(TileLayer));
        // Without an {r} placeholder flutter_map simulates retina tiles: it
        // fetches the next zoom level at half the tile size.
        expect(layer.tileDimension, 128);
        expect(layer.maxZoom, 17.0);
        expect(layer.zoomOffset, 1.0);
        expect(layer.errorImage, isA<MemoryImage>());
      });

      testWidgets('TileLayer defaults match flutter_map', (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'TileLayer',
            '_i': 2,
            'url_template': 'https://tiles.test/{z}/{x}/{y}.png',
            'tile_bounds': offscreenTiles,
          },
        ]);
        final layer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(layer.subdomains, ['a', 'b', 'c']);
        expect(layer.tileDimension, 256);
        expect(layer.maxNativeZoom, 19);
        expect(layer.tms, isFalse);
        expect(layer.tileDisplay, const TileDisplay.fadeIn());
        expect(layer.evictErrorTileStrategy, EvictErrorTileStrategy.none);
      });

      testWidgets('TileLayer tile errors reach Ruby only when subscribed',
          (tester) async {
        for (final subscribed in [true, false]) {
          final m = await mountLayers(tester, design, [
            {
              '_c': 'TileLayer',
              '_i': 2,
              'url_template': 'https://tiles.test/{z}/{x}/{y}.png',
              'tile_bounds': offscreenTiles,
              if (subscribed) 'on_image_error': true,
            },
          ]);
          final layer = tester.widget<TileLayer>(find.byType(TileLayer));
          final tile = TileImage(
            vsync: const TestVSync(),
            coordinates: const TileCoordinates(1, 2, 3),
            imageProvider: MemoryImage(Uint8List(0)),
            onLoadComplete: (_) {},
            onLoadError: (_, __, ___) {},
            tileDisplay: const TileDisplay.instantaneous(),
            errorImage: null,
            cancelLoading: Completer<void>(),
          );
          layer.errorTileCallback!(tile, 'HTTP 404', null);
          expect(
              m.backend.events,
              subscribed
                  ? [(id: 2, name: 'image_error', data: 'HTTP 404')]
                  : isEmpty);
          tile.dispose();
        }
      });

      testWidgets('MarkerLayer places each Marker with its size and content',
          (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'MarkerLayer',
            '_i': 2,
            'rotate': true,
            'alignment': {'x': 0, 'y': -1},
            'markers': [
              {
                '_c': 'Marker',
                '_i': 3,
                'coordinates': latLng(0, 0),
                'width': 40,
                'height': 20,
                'content': {'_c': 'Text', '_i': 4, 'value': 'Pin'},
              },
              {
                '_c': 'Marker',
                '_i': 5,
                'coordinates': latLng(1, 2),
                'rotate': false,
                'alignment': {'x': 1, 'y': 1},
                'content': {'_c': 'Text', '_i': 6, 'value': 'Other'},
              },
              // Not a Marker: the layer skips it.
              {'_c': 'Text', '_i': 7, 'value': 'Stray'},
            ],
          },
        ]);

        final layer = tester
            .widget<AnimatedMarkerLayer>(find.byType(AnimatedMarkerLayer));
        expect(layer.rotate, isTrue);
        expect(layer.alignment, Alignment.topCenter);
        expect(layer.markers, hasLength(2));
        final pin = layer.markers[0];
        expect(pin.point, const LatLng(0, 0));
        expect(pin.width, 40.0);
        expect(pin.height, 20.0);
        expect(pin.rotate, isNull);
        expect(pin.alignment, isNull);
        final other = layer.markers[1];
        expect(other.point, const LatLng(1, 2));
        expect((other.width, other.height), (30.0, 30.0));
        expect(other.rotate, isFalse);
        expect(other.alignment, Alignment.bottomRight);

        expect(find.text('Pin'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
        expect(find.text('Stray'), findsNothing);
        // The layer's top-center alignment puts the 40x20 marker box above
        // its point (the map center at 200,150), centered horizontally.
        final box = tester.getRect(find.ancestor(
            of: find.text('Pin'), matching: find.byType(Positioned)));
        expect(box.size, const Size(40, 20));
        expect(box.center.dx, closeTo(200, 0.5));
        expect(box.bottom, closeTo(150, 0.5));
      });

      testWidgets('a Ruby update to a Marker moves it', (tester) async {
        final m = await mountLayers(tester, design, [
          {
            '_c': 'MarkerLayer',
            '_i': 2,
            'markers': [
              {
                '_c': 'Marker',
                '_i': 3,
                'coordinates': latLng(0, 0),
                'content': {'_c': 'Text', '_i': 4, 'value': 'Pin'},
              },
            ],
          },
        ]);
        m.control(3).update({'coordinates': latLng(3, 4)}, shouldNotify: true);
        await tester.pumpAndSettle();
        final layer = tester
            .widget<AnimatedMarkerLayer>(find.byType(AnimatedMarkerLayer));
        expect(layer.markers.single.point, const LatLng(3, 4));
      });

      testWidgets('CircleLayer draws each CircleMarker', (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'CircleLayer',
            '_i': 2,
            'circles': [
              {
                '_c': 'CircleMarker',
                '_i': 3,
                'coordinates': latLng(0, 0),
                'radius': 12,
                'color': '#ff0000',
                'border_color': '#0000ff',
                'border_stroke_width': 3,
                'use_radius_in_meter': true,
              },
              {'_c': 'CircleMarker', '_i': 4, 'coordinates': latLng(1, 1)},
            ],
          },
        ]);
        final circles =
            tester.widget<CircleLayer>(find.byType(CircleLayer)).circles;
        expect(circles, hasLength(2));
        final first = circles[0];
        expect(first.point, const LatLng(0, 0));
        expect(first.radius, 12.0);
        expect(first.color, const Color(0xFFFF0000));
        expect(first.borderColor, const Color(0xFF0000FF));
        expect(first.borderStrokeWidth, 3.0);
        expect(first.useRadiusInMeter, isTrue);
        final second = circles[1];
        expect(second.radius, 10.0);
        expect(second.color, const Color(0xFF00FF00));
        expect(second.borderStrokeWidth, 0.0);
        expect(second.useRadiusInMeter, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('PolygonLayer draws each PolygonMarker', (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'PolygonLayer',
            '_i': 2,
            'polygon_culling': false,
            'polygon_labels': false,
            'draw_labels_last': true,
            'simplification_tolerance': 0.7,
            'use_alternative_rendering': true,
            'polygons': [
              {
                '_c': 'PolygonMarker',
                '_i': 3,
                // As Ruby's polygon_marker(coordinates: [[0, 0], ...]) sends.
                'coordinates': [latLng(0, 0), latLng(0, 2), latLng(2, 2)],
                'color': '#33ff0000',
                'border_color': '#00ff00',
                'border_stroke_width': 2,
                'disable_holes_border': true,
                'rotate_label': true,
                'label': 'Area',
                'label_text_style': {'size': 18, 'color': '#123456'},
                'stroke_cap': 'butt',
                'stroke_join': 'bevel',
              },
            ],
          },
        ]);
        final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
        expect(layer.polygonCulling, isFalse);
        expect(layer.polygonLabels, isFalse);
        expect(layer.drawLabelsLast, isTrue);
        expect(layer.simplificationTolerance, 0.7);
        expect(layer.useAltRendering, isTrue);
        final polygon = layer.polygons.single;
        expect(
            polygon.points, const [LatLng(0, 0), LatLng(0, 2), LatLng(2, 2)]);
        expect(polygon.color, const Color(0x33FF0000));
        expect(polygon.borderColor, const Color(0xFF00FF00));
        expect(polygon.borderStrokeWidth, 2.0);
        expect(polygon.disableHolesBorder, isTrue);
        expect(polygon.rotateLabel, isTrue);
        expect(polygon.label, 'Area');
        expect(polygon.labelStyle.fontSize, 18.0);
        expect(polygon.labelStyle.color, const Color(0xFF123456));
        expect(polygon.strokeCap, StrokeCap.butt);
        expect(polygon.strokeJoin, StrokeJoin.bevel);
        expect(tester.takeException(), isNull);
      });

      testWidgets('PolylineLayer draws each PolylineMarker', (tester) async {
        await mountLayers(tester, design, [
          {
            '_c': 'PolylineLayer',
            '_i': 2,
            'culling_margin': 4,
            'min_hittable_radius': 6,
            'simplification_tolerance': 0.1,
            'polylines': [
              {
                '_c': 'PolylineMarker',
                '_i': 3,
                'coordinates': [latLng(0, 0), latLng(1, 1), latLng(2, 0)],
                'color': '#0000ff',
                'border_color': '#ffffff',
                'border_stroke_width': 1.5,
                'stroke_width': 4,
                'stroke_cap': 'square',
                'stroke_join': 'miter',
                'use_stroke_width_in_meter': true,
                'gradient_colors': ['#ff0000', '#00ff00'],
                'colors_stop': [0, 1],
                'stroke_pattern': {
                  '_type': 'dashed',
                  'segments': [10, 5],
                  'pattern_fit': 'extend_final_dash',
                },
              },
              {
                '_c': 'PolylineMarker',
                '_i': 4,
                'coordinates': [latLng(0, 0), latLng(-1, -1)],
                'stroke_pattern': {'_type': 'dotted', 'spacing_factor': 2},
              },
            ],
          },
        ]);
        final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
        expect(layer.cullingMargin, 4.0);
        expect(layer.minimumHitbox, 6.0);
        expect(layer.simplificationTolerance, 0.1);
        final route = layer.polylines[0];
        expect(route.points, const [LatLng(0, 0), LatLng(1, 1), LatLng(2, 0)]);
        expect(route.color, const Color(0xFF0000FF));
        expect(route.borderColor, const Color(0xFFFFFFFF));
        expect(route.borderStrokeWidth, 1.5);
        expect(route.strokeWidth, 4.0);
        expect(route.strokeCap, StrokeCap.square);
        expect(route.strokeJoin, StrokeJoin.miter);
        expect(route.useStrokeWidthInMeter, isTrue);
        expect(
            route.gradientColors, const [Color(0xFFFF0000), Color(0xFF00FF00)]);
        expect(route.colorsStop, [0.0, 1.0]);
        expect(
            route.pattern,
            StrokePattern.dashed(
                segments: const [10, 5],
                patternFit: PatternFit.extendFinalDash));
        final dotted = layer.polylines[1];
        expect(dotted.strokeWidth, 1.0);
        expect(dotted.color, const Color(0xFFFFEB3B));
        expect(dotted.pattern, const StrokePattern.dotted(spacingFactor: 2));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
