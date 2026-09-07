import 'package:flutter/cupertino.dart';
import '../models/control.dart';
import 'control_barrier.dart';

class ControlCupertinoDialogRoute<T> extends CupertinoDialogRoute<T>
    with ControlBarrier<T> {
  @override
  final Control control;

  ControlCupertinoDialogRoute({
    required this.control,
    required super.context,
    required super.builder,
    required super.barrierDismissible,
  });

  @override
  Color defaultBarrierColor(BuildContext context) =>
      CupertinoDynamicColor.resolve(kCupertinoModalBarrierColor, context);
}
