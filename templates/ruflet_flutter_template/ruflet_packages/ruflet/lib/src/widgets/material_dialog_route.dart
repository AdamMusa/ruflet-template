import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import '../models/control.dart';
import 'control_barrier.dart';

class ControlMaterialDialogRoute<T> extends material.DialogRoute<T>
    with ControlBarrier<T> {
  @override
  final Control control;

  ControlMaterialDialogRoute({
    required this.control,
    required super.context,
    required super.builder,
    required super.barrierDismissible,
  }) : super(useSafeArea: false);

  @override
  Color defaultBarrierColor(BuildContext context) =>
      material.DialogTheme.of(context).barrierColor ?? material.Colors.black54;
}
