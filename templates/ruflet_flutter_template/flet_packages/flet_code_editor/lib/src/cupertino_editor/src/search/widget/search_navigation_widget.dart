// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/cupertino.dart';

import 'package:flutter_code_editor/src/search/search_navigation_controller.dart';

const _iconSize = 20.0;

class SearchNavigationWidget extends StatelessWidget {
  final SearchNavigationController searchNavigationController;

  const SearchNavigationWidget({
    super.key,
    required this.searchNavigationController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: searchNavigationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (searchNavigationController.value.totalMatchCount > 0) ...[
              CupertinoButton(
                onPressed: searchNavigationController.movePrevious,
                child: const Icon(
                  CupertinoIcons.arrow_up,
                  size: _iconSize,
                ),
              ),
              CupertinoButton(
                onPressed: searchNavigationController.moveNext,
                child: const Icon(
                  CupertinoIcons.arrow_down,
                  size: _iconSize,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
              child: Text(_getText()),
            ),
          ],
        );
      },
    );
  }

  String _getText() {
    final currentMatchIndex =
        (searchNavigationController.value.currentMatchIndex ?? -1) + 1;
    final totalMatchCount = searchNavigationController.value.totalMatchCount;

    return '$currentMatchIndex / $totalMatchCount';
  }
}
