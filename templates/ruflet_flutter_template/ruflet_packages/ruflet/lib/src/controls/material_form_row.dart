import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

const EdgeInsets _kPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const double _kPrefixToContent = 16.0;

/// Material form row: a leading label, an end-aligned field, and optional
/// helper and error lines styled like Material input helper/error text.
class MaterialFormRowControl extends StatelessWidget {
  final Control control;

  const MaterialFormRowControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialFormRow build: ${control.id}");

    final content = control.buildWidget("content");
    if (content == null) {
      return const ErrorControl("FormRow.content must be provided and visible");
    }

    final theme = Theme.of(context);
    final prefix = control.buildTextOrWidget("prefix");
    final helper = control.buildTextOrWidget("helper");
    final error = control.buildTextOrWidget("error");

    return LayoutControl(
      control: control,
      child: Padding(
        padding: control.getPadding("padding", _kPadding)!,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (prefix != null) ...[
                  DefaultTextStyle.merge(
                      style: theme.textTheme.bodyLarge, child: prefix),
                  const SizedBox(width: _kPrefixToContent),
                ],
                Expanded(
                  child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: content),
                ),
              ],
            ),
            if (helper != null)
              DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                child: helper,
              ),
            if (error != null)
              DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
                child: error,
              ),
          ],
        ),
      ),
    );
  }
}
