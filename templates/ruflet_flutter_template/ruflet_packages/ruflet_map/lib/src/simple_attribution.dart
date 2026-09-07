import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_attribution.dart';
import 'material_simple_attribution.dart';

class SimpleAttributionControl extends StatelessWidget {
  const SimpleAttributionControl({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialSimpleAttribution(control: control),
        cupertino: (_) => CupertinoSimpleAttribution(control: control),
      );
}
