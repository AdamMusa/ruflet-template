import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_container.dart';
import 'material_container.dart';

/// The canonical Container entry point.
///
/// Its protocol and Ruby DSL name stay `Container`; only the renderer changes
/// with the effective page platform.
class ContainerControl extends StatelessWidget {
  final Control control;

  const ContainerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialContainerControl(control: control),
        cupertino: (_) => CupertinoContainerControl(control: control),
      );
}
