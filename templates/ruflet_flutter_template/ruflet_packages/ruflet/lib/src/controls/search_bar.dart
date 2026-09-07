import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_input_controls.dart';
import 'material_search_bar.dart';

class SearchBarControl extends StatelessWidget {
  final Control control;

  const SearchBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialSearchBarControl(control: control),
        cupertino: (_) => CupertinoSearchBarControl(control: control),
      );
}
