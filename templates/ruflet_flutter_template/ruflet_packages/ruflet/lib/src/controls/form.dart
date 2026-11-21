import 'package:flutter/widgets.dart';

import '../models/control.dart';
import 'column.dart';

/// Ruby's `form`: a group of fields that validate, reset and save together.
///
/// Validation runs in Ruby, where the validators live: Ruby sets each
/// field's error prop and asks the fields for the change/blur/submit events
/// it needs, so Flutter's Form/FormField state is not involved. Here the
/// form lays out its `controls` like a Column (spacing, alignment, scroll,
/// the common layout keywords) inside a [FocusTraversalGroup], so Tab moves
/// through the form's fields in order before leaving the form.
class FormControl extends StatelessWidget {
  final Control control;

  const FormControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("Form build: ${control.id}");

    return ColumnControl(
      control: control,
      contentWrapper: (child) => FocusTraversalGroup(child: child),
    );
  }
}
