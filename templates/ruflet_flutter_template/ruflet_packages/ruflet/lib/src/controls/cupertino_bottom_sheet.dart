import 'package:flutter/cupertino.dart';

import '../controls/control_widget.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../utils/box.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../widgets/control_barrier.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/error.dart';

/// The route currently presenting each sheet control, so `open: false` pops
/// exactly that route (never whatever happens to be on top of the navigator).
final _presentedSheets = Expando<Route<void>>('BottomSheet route');

const _sheetRadius = BorderRadius.vertical(top: Radius.circular(12));

/// iOS renderer of the canonical `BottomSheet` contract.
///
/// - Picker, TimerPicker and DatePicker content keeps its fixed-height panel.
/// - Any other content is presented as an iOS popup sheet: a rounded surface
///   (`bgcolor`), optional grabber (`show_drag_handle`), safe area
///   (`use_safe_area`), keyboard inset (`maintain_bottom_view_insets_padding`),
///   `scrollable`/`size_constraints`/`height`/`padding` sizing and
///   drag-to-dismiss (`draggable`, off by default for popups).
/// - `fullscreen: true` presents the native stacked iOS page sheet
///   ([CupertinoSheetRoute]); it drags to dismiss unless `draggable: false`.
///
/// `elevation`, `shape`, `clip_behavior` and `animation_style` are Material
/// properties and are ignored on iOS. Page sheets have no barrier, so
/// `barrier_color`, `dismissible` and `modal` only apply to popups.
class CupertinoBottomSheetControl extends StatelessWidget {
  final Control control;

  const CupertinoBottomSheetControl({
    super.key,
    required this.control,
  });

  static bool _isPicker(Control content) =>
      ["Picker", "TimerPicker", "DatePicker"].contains(content.canonicalType);

  Widget _createPickerPanel(BuildContext context, Control content) {
    return Container(
      height: control.getDouble("height", 220.0)!,
      padding: control.getPadding("padding"),
      // bottom margin is provided to align the popup above the system navigation bar
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // popup background color
      color: control.getColor("bgcolor", context,
          CupertinoColors.systemBackground.resolveFrom(context))!,
      // Use SafeArea to avoid system overlaps
      child: SafeArea(
        top: false,
        child: ControlWidget(control: content),
      ),
    );
  }

  /// Rebuilds [builder] whenever the sheet control changes while presented.
  Widget _live(WidgetBuilder builder) {
    return ControlInheritedNotifier(
      notifier: control,
      child: Builder(builder: (context) {
        ControlInheritedNotifier.of(context);
        return builder(context);
      }),
    );
  }

  Widget _popupSheet(BuildContext context, Control content) {
    final media = MediaQuery.of(context);
    final scrollable = control.getBool("scrollable", false)!;
    final padding = control.getPadding("padding");
    final height = control.getDouble("height");
    final sizeConstraints = control.getBoxConstraints("size_constraints");

    Widget body = ControlWidget(control: content);
    if (padding != null) body = Padding(padding: padding, child: body);

    Widget sheet = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (control.getBool("show_drag_handle", false)!)
          const _CupertinoSheetGrabber(),
        Flexible(child: body),
      ],
    );
    if (control.getBool("use_safe_area", true)!) {
      sheet = SafeArea(top: false, child: sheet);
    }
    sheet = ClipRRect(
      borderRadius: _sheetRadius,
      child: ColoredBox(
        color: control.getColor("bgcolor", context,
            CupertinoColors.systemBackground.resolveFrom(context))!,
        child: sheet,
      ),
    );
    if (height != null) sheet = SizedBox(height: height, child: sheet);
    if (sizeConstraints != null) {
      sheet = ConstrainedBox(constraints: sizeConstraints, child: sheet);
    }
    // Material parity: 9/16 of the screen unless the sheet is scrollable,
    // which may grow up to the status bar.
    sheet = ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: scrollable
              ? media.size.height - media.padding.top
              : media.size.height * 9 / 16),
      child: sheet,
    );
    if (control.getBool("draggable") ?? false) {
      sheet = _CupertinoSheetDragDismiss(
        handleOnly: scrollable,
        onDismiss: () => _closeRoute(ModalRoute.of(context)),
        child: sheet,
      );
    }
    if (control.getBool("maintain_bottom_view_insets_padding", true)!) {
      sheet = Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: sheet,
      );
    }
    return sheet;
  }

  Widget _pageSheet(BuildContext context, Control content) {
    final padding = control.getPadding("padding");

    Widget body = SizedBox.expand(child: ControlWidget(control: content));
    if (padding != null) body = Padding(padding: padding, child: body);
    if (control.getBool("maintain_bottom_view_insets_padding", true)!) {
      body = Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: body,
      );
    }
    if (control.getBool("use_safe_area", true)!) {
      body = SafeArea(child: body);
    }
    return ColoredBox(
      color: control.getColor("bgcolor", context,
          CupertinoColors.systemBackground.resolveFrom(context))!,
      child: body,
    );
  }

  Route<void> _createRoute(BuildContext context, Control content) {
    if (_isPicker(content)) {
      final panel = _createPickerPanel(context, content);
      return _CupertinoSheetPopupRoute(
        control: control,
        barrierDismissible: _barrierDismissible,
        builder: (_) => panel,
      );
    }
    if (control.getBool("fullscreen", false)!) {
      // showCupertinoSheet always uses the root navigator; push the same route
      // onto the owning navigator instead, like every other Ruflet dialog.
      return CupertinoSheetRoute<void>(
        enableDrag: control.getBool("draggable") ?? true,
        showDragHandle: control.getBool("show_drag_handle", false)!,
        builder: (_) => _live((context) => _pageSheet(context, content)),
      );
    }
    return _CupertinoSheetPopupRoute(
      control: control,
      barrierDismissible: _barrierDismissible,
      builder: (_) => _live((context) => _popupSheet(context, content)),
    );
  }

  bool get _barrierDismissible =>
      control.getBool("dismissible") ?? !control.getBool("modal", false)!;

  void _present(BuildContext context) {
    final content = control.child("content");
    if (!context.mounted ||
        content == null ||
        !control.getBool("open", false)!) {
      // Closed (or unmounted) before it could be presented.
      _didDismiss();
      return;
    }
    final route = _createRoute(context, content);
    _presentedSheets[control] = route;
    Navigator.of(context).push(route).then((_) {
      if (identical(_presentedSheets[control], route)) {
        _presentedSheets[control] = null;
      }
      _didDismiss();
    });
  }

  void _didDismiss() {
    control.updateProperties({"_open": false}, python: false);
    control.updateProperties({"open": false});
    control.triggerEvent("dismiss");
  }

  static void _closeRoute(Route<dynamic>? route) {
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoBottomSheet build: ${control.id}");

    bool lastOpen = control.getBool("_open", false)!;

    var open = control.getBool("open", false)!;

    if (open && (open != lastOpen)) {
      if (control.child("content") == null) {
        return const ErrorControl("CupertinoBottomSheet.content is empty.");
      }

      control.updateProperties({"_open": open}, python: false);

      WidgetsBinding.instance.addPostFrameCallback((_) => _present(context));
    } else if (open != lastOpen && lastOpen) {
      // A sheet closed before its post-frame presentation has no route yet;
      // _present sees open == false and completes the dismiss lifecycle.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _closeRoute(_presentedSheets[control]));
    }

    return const SizedBox.shrink();
  }
}

/// iOS popup route whose barrier color follows the live `barrier_color`.
class _CupertinoSheetPopupRoute extends CupertinoModalPopupRoute<void>
    with ControlBarrier<void> {
  @override
  final Control control;

  _CupertinoSheetPopupRoute({
    required this.control,
    required super.builder,
    required super.barrierDismissible,
  });

  @override
  Color defaultBarrierColor(BuildContext context) =>
      CupertinoDynamicColor.resolve(kCupertinoModalBarrierColor, context);
}

/// The 36x5 iOS sheet grabber.
class _CupertinoSheetGrabber extends StatelessWidget {
  const _CupertinoSheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey3.resolveFrom(context),
            borderRadius: BorderRadius.circular(2.5),
          ),
          child: const SizedBox(width: 36, height: 5),
        ),
      ),
    );
  }
}

/// Drag-down-to-dismiss for iOS popup sheets (Flutter only provides it for
/// the full-screen [CupertinoSheetRoute]).
///
/// The surface follows the finger; on release it dismisses when dragged more
/// than 25 % of its height or flung down faster than 700 px/s, otherwise it
/// springs back. With [handleOnly] only the top 44 px start a drag so inner
/// scrollables keep their gestures.
class _CupertinoSheetDragDismiss extends StatefulWidget {
  final bool handleOnly;
  final VoidCallback onDismiss;
  final Widget child;

  const _CupertinoSheetDragDismiss({
    required this.handleOnly,
    required this.onDismiss,
    required this.child,
  });

  @override
  State<_CupertinoSheetDragDismiss> createState() =>
      _CupertinoSheetDragDismissState();
}

class _CupertinoSheetDragDismissState extends State<_CupertinoSheetDragDismiss>
    with SingleTickerProviderStateMixin {
  static const _dismissFraction = 0.25;
  static const _dismissVelocity = 700.0;
  static const _handleExtent = 44.0;

  /// Dragged distance as a fraction of the sheet height.
  late final AnimationController _drag = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
  bool _dismissed = false;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final height = context.size?.height ?? 0;
    if (_dismissed || height <= 0) return;
    _drag.value += details.primaryDelta! / height;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissed) return;
    if ((details.primaryVelocity ?? 0) > _dismissVelocity ||
        _drag.value > _dismissFraction) {
      _dismissed = true;
      widget.onDismiss();
    } else {
      _drag.animateBack(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detector = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: widget.handleOnly ? null : widget.child,
    );
    final sheet = widget.handleOnly
        ? Stack(children: [
            widget.child,
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _handleExtent,
                child: detector),
          ])
        : detector;
    return AnimatedBuilder(
      animation: _drag,
      builder: (context, child) => FractionalTranslation(
          translation: Offset(0, _drag.value), child: child),
      child: sheet,
    );
  }
}
