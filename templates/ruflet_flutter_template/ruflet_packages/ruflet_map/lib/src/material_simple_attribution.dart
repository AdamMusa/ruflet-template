import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

class MaterialSimpleAttribution extends StatelessWidget {
  final Control control;

  const MaterialSimpleAttribution({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("SimpleAttributionControl build: ${control.id}");
    var text = control.buildTextOrWidget("text");

    return SimpleAttributionWidget(
      source: text is Text ? text : const Text("Placeholder Text"),
      onTap: () => control.triggerEvent("click"),
      backgroundColor: control.getColor(
          "bgcolor", context, RufletStyleTheme.of(context).color("surface"))!,
      alignment: control.getAlignment("alignment", Alignment.bottomRight)!,
    );
  }
}
