// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:flutter_code_editor/src/sizes.dart';
import 'package:flutter_code_editor/src/wip/autocomplete/popup_controller.dart';

/// Popup window displaying the list of possible completions
class Popup extends StatefulWidget {
  final PopupController controller;
  final Size editingWindowSize;

  /// The window coordinates of the top-left corner of the editor widget.
  final Offset? editorOffset;

  /// The window coordinates of the highest allowed top-left corner
  /// of the popup if shown above the caret.
  ///
  /// Since the popup is pushed to the bottom of the allowed rectangle
  /// the actual position may be lower.
  final Offset flippedOffset;

  /// The window coordinates of the top-left corner of the popup
  /// if shown below the caret.
  final Offset normalOffset;

  final FocusNode parentFocusNode;
  final TextStyle style;
  final Color? backgroundColor;

  const Popup({
    super.key,
    required this.controller,
    required this.editingWindowSize,
    required this.editorOffset,
    required this.flippedOffset,
    required this.normalOffset,
    required this.parentFocusNode,
    required this.style,
    this.backgroundColor,
  });

  @override
  PopupState createState() => PopupState();
}

class PopupState extends State<Popup> {
  final pageStorageBucket = PageStorageBucket();

  @override
  void initState() {
    widget.controller.addListener(rebuild);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verticalFlipRequired = _isVerticalFlipRequired();
    final bool isHorizontalOverflowed = _isHorizontallyOverflowed();
    final double leftOffsetLimit =
        // TODO(nausharipov): find where 100 comes from
        widget.editingWindowSize.width -
            Sizes.autocompletePopupMaxWidth +
            (widget.editorOffset?.dx ?? 0) -
            100;

    // Fixes assertion error when ISC isn't attached but _attach method
    // of ISC instance are being called
    ItemScrollController? isc;
    if (widget.controller.itemScrollController.isAttached) {
      isc = widget.controller.itemScrollController;
    }

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: isHorizontalOverflowed ? leftOffsetLimit : widget.normalOffset.dx,
        top: verticalFlipRequired
            ? widget.flippedOffset.dy
            : widget.normalOffset.dy,
        child: Container(
          alignment: verticalFlipRequired
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          constraints: const BoxConstraints(
            maxHeight: Sizes.autocompletePopupMaxHeight,
            maxWidth: Sizes.autocompletePopupMaxWidth,
          ),
          // Container is used because the vertical borders
          // in DecoratedBox are hidden under scroll.
          // ignore: use_decorated_box
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: Border.all(
                color: widget.style.color!,
                width: 0.5,
              ),
            ),
            child: ScrollablePositionedList.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemScrollController: isc,
              itemPositionsListener: widget.controller.itemPositionsListener,
              itemCount: widget.controller.suggestions.length,
              itemBuilder: (context, index) {
                return _buildListItem(index);
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _isVerticalFlipRequired() {
    final isPopupShorterThanWindow =
        Sizes.autocompletePopupMaxHeight < widget.editingWindowSize.height;
    final isPopupOverflowingHeight = widget.normalOffset.dy +
            Sizes.autocompletePopupMaxHeight -
            (widget.editorOffset?.dy ?? 0) >
        widget.editingWindowSize.height;

    return isPopupOverflowingHeight && isPopupShorterThanWindow;
  }

  bool _isHorizontallyOverflowed() {
    return widget.normalOffset.dx -
            (widget.editorOffset?.dx ?? 0) +
            Sizes.autocompletePopupMaxWidth >
        widget.editingWindowSize.width;
  }

  Widget _buildListItem(int index) {
    return ColoredBox(
      color: CupertinoColors.systemGrey.withValues(alpha: .1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
        },
        onDoubleTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
          widget.controller.onCompletionSelected();
        },
        child: ColoredBox(
          color: widget.controller.selectedIndex == index
              ? CupertinoColors.activeBlue.withOpacity(0.5)
              : const Color(0x00000000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.controller.suggestions[index],
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }

  void rebuild() {
    setState(() {});
  }
}
