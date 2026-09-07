import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'utils/map.dart';

class PolygonLayerControl extends StatelessWidget with RufletStoreMixin {
  final Control control;

  const PolygonLayerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("PolygonLayerControl build: ${control.id}");

    var polygons = control
        .children("polygons")
        .where((c) => c.type == "PolygonMarker")
        .map((polygon) {
      polygon.notifyParent = true;
      return Polygon(
          borderStrokeWidth: polygon.getDouble("border_stroke_width", 0)!,
          borderColor: polygon.getColor(
              "border_color", context, const Color(0xFF4CAF50))!,
          color: polygon.getColor("color", context, const Color(0xFF4CAF50))!,
          disableHolesBorder: polygon.getBool("disable_holes_border", false)!,
          rotateLabel: polygon.getBool("rotate_label", false)!,
          label: polygon.getString("label"),
          labelStyle: polygon.getTextStyle("label_text_style",
              RufletStyleTheme.of(context), const TextStyle())!,
          strokeCap: polygon.getStrokeCap("stroke_cap", StrokeCap.round)!,
          strokeJoin: polygon.getStrokeJoin("stroke_join", StrokeJoin.round)!,
          points: polygon
              .get("coordinates", [])!
              .map((c) => parseLatLng(c))
              .nonNulls
              .toList());
    }).toList();

    return PolygonLayer(
      polygons: polygons,
      polygonCulling: control.getBool("polygon_culling", true)!,
      polygonLabels: control.getBool("polygon_labels", true)!,
      drawLabelsLast: control.getBool("draw_labels_last", false)!,
      simplificationTolerance:
          control.getDouble("simplification_tolerance", 0.3)!,
      useAltRendering: control.getBool("use_alternative_rendering", false)!,
    );
  }
}
