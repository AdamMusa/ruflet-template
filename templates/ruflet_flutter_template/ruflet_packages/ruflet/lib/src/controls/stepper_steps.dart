import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/enums.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';

/// Design-neutral twin of Flutter's Material-only `StepState`, so the
/// Cupertino renderer can share the Ruby `state` parsing.
enum StepperStepState { indexed, editing, complete, disabled, error }

/// One Ruby `stepper_step` (wire type `Step`), resolved for either renderer.
class StepperStep {
  /// The `Step` child control (not the Stepper).
  final Control stepControl;
  final int index;

  const StepperStep(this.stepControl, this.index);

  StepperStepState get state => parseEnum(
      StepperStepState.values,
      stepControl.getString("state")?.replaceAll("_", ""),
      StepperStepState.indexed)!;

  bool get isActive => stepControl.getBool("is_active", false)!;

  Widget get title => stepControl.buildTextOrWidget("title", required: true)!;

  Widget? get subtitle => stepControl.buildTextOrWidget("subtitle");

  Widget get content =>
      stepControl.buildWidget("content") ?? const SizedBox.shrink();

  Widget? get label => stepControl.buildTextOrWidget("label");
}

/// The Ruby Stepper state shared by the Material and Cupertino renderers.
///
/// The Stepper is controlled: Dart never changes `current_step`; Ruby handlers
/// do, so every interaction is reported as an event carrying an index.
class StepperModel {
  final Control control;
  final List<StepperStep> steps;

  StepperModel._(this.control, this.steps);

  /// Steps come from `steps` (the keyword) or, failing that, from block
  /// children (`controls`). Hidden steps are skipped.
  factory StepperModel(Control control) {
    var children = control.children("steps");
    if (children.isEmpty) children = control.children("controls");
    return StepperModel._(control, [
      for (var i = 0; i < children.length; i++) StepperStep(children[i], i)
    ]);
  }

  /// An [ErrorControl] when the Ruby data cannot be rendered, else `null`.
  Widget? get error {
    if (steps.isEmpty) {
      return const ErrorControl(
          "Stepper.steps must contain at least one visible step");
    }
    for (final step in steps) {
      if (step.stepControl.type != "Step") {
        return ErrorControl("Stepper.steps must contain only Step controls",
            description: "Build each step with stepper_step(title: ...), "
                "not ${step.stepControl.type}");
      }
    }
    return null;
  }

  bool get horizontal =>
      control.getString("type", "vertical")!.toLowerCase() == "horizontal";

  int get currentStep => math.max(
      0, math.min(control.getInt("current_step", 0)!, steps.length - 1));

  bool get showControls => control.getBool("show_controls", true)!;

  String? get continueText => control.getString("continue_text");

  String? get cancelText => control.getString("cancel_text");

  double get connectorThickness =>
      control.getDouble("connector_thickness", 1.0)!;

  Clip get clipBehavior => parseClip(
      control.getString("clip_behavior")?.replaceAll("_", ""), Clip.none)!;

  bool canTap(StepperStep step) =>
      onStepTapped != null &&
      step.state != StepperStepState.disabled &&
      !step.stepControl.disabled;

  /// Fires `step_tap` with the tapped index; null without a Ruby handler.
  ValueChanged<int>? get onStepTapped =>
      !control.disabled && control.getBool("on_step_tap", false)!
          ? (index) => control.triggerEvent("step_tap", index)
          : null;

  /// Fires `step_continue` with `current_step`; null (button disabled)
  /// without a Ruby handler.
  VoidCallback? get onStepContinue =>
      !control.disabled && control.getBool("on_step_continue", false)!
          ? () => control.triggerEvent("step_continue", currentStep)
          : null;

  /// Fires `step_cancel` with `current_step`; null (button disabled) without
  /// a Ruby handler.
  VoidCallback? get onStepCancel =>
      !control.disabled && control.getBool("on_step_cancel", false)!
          ? () => control.triggerEvent("step_cancel", currentStep)
          : null;
}
