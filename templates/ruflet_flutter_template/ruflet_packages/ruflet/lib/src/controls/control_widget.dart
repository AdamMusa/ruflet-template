import 'package:flutter/widgets.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import '../utils/keys.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/error.dart';

/// Builds the Flutter [Widget] for a [Control].
///
/// Responsibilities:
/// - Resolves a stable Flutter [Key] from the control's `key` property (including
///   registering a scroll [GlobalKey] with the backend).
/// - Delegates widget creation to registered extensions.
/// - Builds the result in this control's standard "control context":
///   [ControlInheritedNotifier] (reactivity) and per-control theme overrides.
class ControlWidget extends StatelessWidget {
  final Control control;

  const ControlWidget({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    ControlKey? controlKey = control.getKey("key");
    Key? key;
    if (controlKey is ControlScrollKey) {
      // A scroll key needs to be a GlobalKey so the backend can access state.
      key = GlobalKey();
      RufletBackend.of(context).globalKeys[controlKey.toString()] =
          key as GlobalKey;
    } else if (controlKey != null) {
      key = ValueKey(controlKey.value);
    }

    return control.buildInControlContext((context) {
      for (var extension in RufletBackend.of(context).extensions) {
        final widget = extension.createWidget(key, control);
        if (widget != null) return widget;
      }
      return ErrorControl("Unknown control: ${control.type}");
    });
  }

  @override
  StatelessElement createElement() => _ControlWidgetElement(this);
}

/// Keeps [Control.isAttached] true while this widget is mounted, so invokes
/// of methods no renderer handles fail fast (see [Control.invokeMethod]).
class _ControlWidgetElement extends StatelessElement {
  _ControlWidgetElement(ControlWidget super.widget);

  Control get _control => (widget as ControlWidget).control;

  @override
  void mount(Element? parent, Object? newSlot) {
    _control.attach();
    super.mount(parent, newSlot);
  }

  @override
  void update(StatelessWidget newWidget) {
    final previous = _control;
    final next = (newWidget as ControlWidget).control;
    if (!identical(previous, next)) {
      next.attach();
      previous.detach();
    }
    super.update(newWidget);
  }

  @override
  void unmount() {
    _control.detach();
    super.unmount();
  }
}
