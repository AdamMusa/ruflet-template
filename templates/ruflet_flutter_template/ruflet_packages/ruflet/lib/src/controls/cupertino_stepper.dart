import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/style_theme.dart';
import 'stepper_steps.dart';

const double _kCircleSize = 24;
const double _kHeaderGap = 12;
const double _kLineSegment = 8;
const Duration _kDuration = Duration(milliseconds: 200);

/// Cupertino renderer for Ruby `stepper`.
///
/// Flutter ships no Cupertino stepper, so this is built from Cupertino and
/// widgets-layer pieces only (no Material): numbered 24 px circles joined by
/// hairline connectors, the current step's content under its header, and
/// `CupertinoButton`s for continue/cancel. Every step's content stays mounted
/// (offstage when not current) so form state survives moving between steps.
class CupertinoStepperControl extends StatelessWidget {
  final Control control;
  final StepperModel model;

  const CupertinoStepperControl(
      {super.key, required this.control, required this.model});

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoStepper build: ${control.id}");

    final style = _CupertinoStepperStyle(
      context,
      model,
      control.getWidgetStateColor(
          "connector_color", RufletStyleTheme.of(context)),
    );
    return model.horizontal
        ? _buildHorizontal(context, style)
        : _buildVertical(context, style);
  }

  Widget _buildVertical(BuildContext context, _CupertinoStepperStyle style) {
    final current = model.currentStep;
    final last = model.steps.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in model.steps)
          KeyedSubtree(
            key: ValueKey(step.stepControl.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tappable(
                  step,
                  Row(
                    children: [
                      SizedBox(
                        width: _kCircleSize,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            style.line(
                                visible: step.index > 0,
                                active: step.index > 0 &&
                                    model.steps[step.index - 1].isActive,
                                height: _kLineSegment),
                            style.circle(step),
                            style.line(
                                visible: step.index < last,
                                active: step.isActive,
                                height: _kLineSegment),
                          ],
                        ),
                      ),
                      const SizedBox(width: _kHeaderGap),
                      Expanded(
                          child: style.headerText(step, step.index == current)),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    if (step.index < last)
                      PositionedDirectional(
                        start: (_kCircleSize - style.thickness) / 2,
                        top: 0,
                        bottom: 0,
                        width: style.thickness,
                        child:
                            ColoredBox(color: style.lineColor(step.isActive)),
                      ),
                    AnimatedSize(
                      duration: _kDuration,
                      curve: Curves.easeInOut,
                      alignment: AlignmentDirectional.topStart,
                      child: Visibility(
                        visible: step.index == current,
                        maintainState: true,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                              start: _kCircleSize + _kHeaderGap,
                              top: 4,
                              bottom: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRect(
                                  clipBehavior: model.clipBehavior,
                                  child: step.content),
                              if (model.showControls) _controls(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontal(BuildContext context, _CupertinoStepperStyle style) {
    final current = model.currentStep;
    final last = model.steps.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Equal-width columns: each step's circle is joined to its neighbours
        // by Expanded hairlines, with the title centred underneath, so the
        // header never overflows however many steps there are.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final step in model.steps)
                Expanded(
                  child: _tappable(
                    step,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: style.hline(
                                    visible: step.index > 0,
                                    active: step.index > 0 &&
                                        model.steps[step.index - 1].isActive)),
                            style.circle(step),
                            Expanded(
                                child: style.hline(
                                    visible: step.index < last,
                                    active: step.isActive)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: style.headerText(step, step.index == current,
                              compact: true),
                        ),
                        if (step.label != null) ...[
                          const SizedBox(height: 2),
                          style.label(step),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 0.5, color: style.separator),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedSize(
                duration: _kDuration,
                curve: Curves.easeInOut,
                alignment: AlignmentDirectional.topStart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in model.steps)
                      Visibility(
                        key: ValueKey(step.stepControl.id),
                        visible: step.index == current,
                        maintainState: true,
                        child: ClipRect(
                            clipBehavior: model.clipBehavior,
                            child: step.content),
                      ),
                  ],
                ),
              ),
              if (model.showControls) _controls(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tappable(StepperStep step, Widget child) => model.canTap(step)
      ? GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => model.onStepTapped!(step.index),
          child: child,
        )
      : child;

  Widget _controls(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CupertinoButton.filled(
              sizeStyle: CupertinoButtonSize.medium,
              onPressed: model.onStepContinue,
              child: Text(model.continueText ?? "Continue"),
            ),
            CupertinoButton(
              sizeStyle: CupertinoButtonSize.medium,
              onPressed: model.onStepCancel,
              child: Text(model.cancelText ??
                  CupertinoLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        ),
      );
}

/// Colors, glyphs and text styles resolved once per build.
class _CupertinoStepperStyle {
  final BuildContext context;
  final StepperModel model;
  final WidgetStateProperty<Color?>? connectorColor;
  final double thickness;

  _CupertinoStepperStyle(this.context, this.model, this.connectorColor)
      : thickness = model.connectorThickness;

  Color _resolve(Color color) => CupertinoDynamicColor.resolve(color, context);

  Color get separator => _resolve(CupertinoColors.separator);

  Color? _custom(bool active) => connectorColor
      ?.resolve({active ? WidgetState.selected : WidgetState.disabled});

  Color lineColor(bool active) => _custom(active) ?? separator;

  Widget line(
          {required bool visible,
          required bool active,
          required double height}) =>
      SizedBox(
        width: visible ? thickness : 0,
        height: height,
        child: visible ? ColoredBox(color: lineColor(active)) : null,
      );

  Widget hline({required bool visible, required bool active}) => SizedBox(
        height: thickness,
        child: visible ? ColoredBox(color: lineColor(active)) : null,
      );

  Widget circle(StepperStep step) {
    final state = step.state;
    final active = step.isActive || state == StepperStepState.complete;
    final color = state == StepperStepState.error
        ? _resolve(CupertinoColors.systemRed)
        : _custom(active) ??
            (active
                ? _resolve(CupertinoTheme.of(context).primaryColor)
                : _resolve(CupertinoColors.systemGrey3));
    const glyphColor = CupertinoColors.white;
    final glyph = switch (state) {
      StepperStepState.complete =>
        const Icon(CupertinoIcons.checkmark, size: 14, color: glyphColor),
      StepperStepState.editing =>
        const Icon(CupertinoIcons.pencil, size: 14, color: glyphColor),
      StepperStepState.error =>
        const Icon(CupertinoIcons.exclamationmark, size: 14, color: glyphColor),
      _ => Text("${step.index + 1}",
          style: const TextStyle(
              color: glyphColor, fontSize: 13, fontWeight: FontWeight.w600)),
    };
    return AnimatedContainer(
      duration: _kDuration,
      width: _kCircleSize,
      height: _kCircleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: glyph,
    );
  }

  Widget headerText(StepperStep step, bool current, {bool compact = false}) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final titleColor = switch (step.state) {
      StepperStepState.disabled => _resolve(CupertinoColors.tertiaryLabel),
      StepperStepState.error => _resolve(CupertinoColors.systemRed),
      _ => base.color,
    };
    final subtitle = step.subtitle;
    // The compact (horizontal) header centres one ellipsised line per text.
    final textAlign = compact ? TextAlign.center : TextAlign.start;
    final overflow = compact ? TextOverflow.ellipsis : TextOverflow.clip;
    final maxLines = compact ? 1 : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: base.copyWith(
              color: titleColor,
              fontSize: compact ? 13 : null,
              fontWeight: current ? FontWeight.w600 : FontWeight.w400),
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
          child: step.title,
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DefaultTextStyle(
              style: base.copyWith(
                  fontSize: compact ? 11 : 13,
                  color: _resolve(CupertinoColors.secondaryLabel)),
              textAlign: textAlign,
              overflow: overflow,
              maxLines: maxLines,
              child: subtitle,
            ),
          ),
      ],
    );
  }

  Widget label(StepperStep step) => DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 11, color: _resolve(CupertinoColors.secondaryLabel)),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        child: step.label!,
      );
}
