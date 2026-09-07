import 'package:flutter/cupertino.dart';
import '../widgets/platform_design.dart';
import 'package:flutter/rendering.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class CupertinoSelectionAreaControl extends StatefulWidget {
  final Control control;

  const CupertinoSelectionAreaControl({super.key, required this.control});

  @override
  State<CupertinoSelectionAreaControl> createState() =>
      _CupertinoSelectionAreaControlState();
}

class _CupertinoSelectionAreaControlState
    extends State<CupertinoSelectionAreaControl> {
  @override
  Widget build(BuildContext context) {
    final content = widget.control.buildWidget("content");
    if (content == null) {
      return const ErrorControl(
          "SelectionArea.content must be provided and visible");
    }
    return BaseControl(
      control: widget.control,
      child: CupertinoSelectableRegion(
        onSelectionChanged: (SelectedContent? selection) {
          widget.control.triggerEvent("change", selection?.plainText);
        },
        child: content,
      ),
    );
  }
}

/// A design-pure selectable region shared by Cupertino controls that need
/// selectable content without importing Material's SelectionArea.
class CupertinoSelectableRegion extends StatefulWidget {
  final Widget child;
  final ValueChanged<SelectedContent?>? onSelectionChanged;

  const CupertinoSelectableRegion({
    super.key,
    required this.child,
    this.onSelectionChanged,
  });

  @override
  State<CupertinoSelectableRegion> createState() =>
      _CupertinoSelectableRegionState();
}

class _CupertinoSelectableRegionState extends State<CupertinoSelectableRegion> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controls = effectiveTargetPlatform(context) == TargetPlatform.macOS
        ? cupertinoDesktopTextSelectionHandleControls
        : cupertinoTextSelectionHandleControls;
    return SelectableRegion(
      focusNode: _focusNode,
      selectionControls: controls,
      contextMenuBuilder: (context, state) =>
          CupertinoAdaptiveTextSelectionToolbar.buttonItems(
        anchors: state.contextMenuAnchors,
        buttonItems: state.contextMenuButtonItems,
      ),
      onSelectionChanged: widget.onSelectionChanged,
      child: widget.child,
    );
  }
}
