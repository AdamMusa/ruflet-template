import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_attribution.dart';
import 'material_rich_attribution.dart';

class RichAttributionControl extends StatelessWidget {
  const RichAttributionControl({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialRichAttribution(control: control),
        cupertino: (_) => CupertinoRichAttribution(control: control),
      );
}
