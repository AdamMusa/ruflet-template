import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_list_tile.dart';
import 'package:ruflet/src/controls/list_tile.dart';
import 'package:ruflet/src/widgets/ruflet_cupertino_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;
import 'ruby_layout_attributes_test.dart' show backendFor, host;

Map<String, dynamic> _tile({bool? chevron, bool trailing = false}) => {
      '_c': 'ListTile',
      '_i': 1,
      'title': {'_c': 'Text', '_i': 2, 'value': 'Privacy'},
      if (trailing) 'trailing': {'_c': 'Text', '_i': 3, 'value': 'On'},
      if (chevron != null) 'chevron': chevron,
    };

Future<void> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> map) async {
  final backend = backendFor(platform);
  final control = Control.fromMap(map, backend);
  final tile = ControlWidget(control: control);
  await tester.pumpWidget(host(
      backend,
      SizedBox(
        width: 400,
        // Material list tiles need an ink surface, as in a page Scaffold.
        child: platform == TargetPlatform.iOS
            ? tile
            : material.Material(child: tile),
      )));
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final ios = platform == TargetPlatform.iOS;
    final tileType = ios ? CupertinoListTileSkin : MaterialListTileSkin;
    final chevron = ios
        ? find.byType(RufletCupertinoListTileChevron)
        : find.byIcon(material.Icons.chevron_right);

    testWidgets('$platform: chevron is absent unless Ruby asks for it',
        (tester) async {
      await _pump(tester, platform, _tile());
      expect(chevron, findsNothing);
      await _pump(tester, platform, _tile(chevron: false));
      expect(chevron, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform: chevron takes the trailing slot, height unchanged',
        (tester) async {
      await _pump(tester, platform, _tile());
      final plain = tester.getRect(find.byType(tileType));

      await _pump(tester, platform, _tile(chevron: true));
      expect(chevron, findsOneWidget);
      final tile = tester.getRect(find.byType(tileType));
      final mark = tester.getRect(chevron);
      expect(tile.height, plain.height);
      expect(
          mark.left, greaterThan(tester.getRect(find.text('Privacy')).right));
      // End-aligned in the trailing slot: iOS tile end padding is 14, the
      // Material 3 ListTile end padding is 24.
      expect(mark.right, tile.right - (ios ? 14 : 24));
      expect(mark.center.dy, closeTo(tile.center.dy, 0.5));
      if (ios) {
        expect(find.byWidgetPredicate(materialOnly), findsNothing);
      } else {
        // The chevron inherits the tile's icon color, so icon_color,
        // selected and disabled states apply to it like any trailing icon.
        final icon = tester.widget<RichText>(
            find.descendant(of: chevron, matching: find.byType(RichText)));
        expect(
            icon.text.style?.color,
            material.Theme.of(tester.element(chevron))
                .colorScheme
                .onSurfaceVariant);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform: chevron follows an existing trailing widget',
        (tester) async {
      await _pump(tester, platform, _tile(trailing: true));
      final plain = tester.getRect(find.byType(tileType));
      final trailingAlone = tester.getRect(find.text('On'));

      await _pump(tester, platform, _tile(trailing: true, chevron: true));
      final tile = tester.getRect(find.byType(tileType));
      final trailing = tester.getRect(find.text('On'));
      final mark = tester.getRect(chevron);
      expect(tile.height, plain.height);
      expect(find.text('On'), findsOneWidget);
      expect(mark.left - trailing.right, 6);
      expect(mark.right, trailingAlone.right);
      expect(trailing.center.dy, closeTo(mark.center.dy, 0.5));
      expect(tester.takeException(), isNull);
    });
  }
}
