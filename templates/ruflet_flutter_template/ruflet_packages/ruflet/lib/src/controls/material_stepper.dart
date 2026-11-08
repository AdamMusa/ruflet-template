import 'package:flutter/material.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import '../utils/style_theme.dart';
import 'stepper_steps.dart';

/// Material renderer for Ruby `stepper`: Flutter's [Stepper].
class MaterialStepperControl extends StatelessWidget {
  final Control control;
  final StepperModel model;

  const MaterialStepperControl(
      {super.key, required this.control, required this.model});

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialStepper build: ${control.id}");

    final colorScheme = Theme.of(context).colorScheme;
    final connectorColor = control.getWidgetStateColor(
        "connector_color", RufletStyleTheme.of(context));
    final localizations = MaterialLocalizations.of(context);

    return Stepper(
      // Flutter asserts that the step count never changes for one State, so a
      // different Ruby step list gets a fresh Stepper.
      key: ValueKey(model.steps.map((step) => step.stepControl.id).join(",")),
      type: model.horizontal ? StepperType.horizontal : StepperType.vertical,
      currentStep: model.currentStep,
      physics: const ClampingScrollPhysics(),
      onStepTapped: model.onStepTapped,
      onStepContinue: model.onStepContinue,
      onStepCancel: model.onStepCancel,
      elevation: control.getDouble("elevation"),
      connectorThickness: control.getDouble("connector_thickness"),
      connectorColor: connectorColor == null
          ? null
          : WidgetStateProperty.resolveWith((states) =>
              connectorColor.resolve(states) ??
              (states.contains(WidgetState.selected)
                  ? colorScheme.primary
                  : Colors.grey.shade400)),
      clipBehavior: model.clipBehavior,
      controlsBuilder: (context, details) => !model.showControls
          ? const SizedBox.shrink()
          : Container(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(model.continueText ??
                        localizations.continueButtonLabel),
                  ),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(
                        model.cancelText ?? localizations.cancelButtonLabel),
                  ),
                ],
              ),
            ),
      steps: [
        for (final step in model.steps)
          Step(
            title: step.title,
            subtitle: step.subtitle,
            content: step.content,
            state: StepState.values.byName(step.state.name),
            isActive: step.isActive,
            label: step.label,
          ),
      ],
    );
  }
}
