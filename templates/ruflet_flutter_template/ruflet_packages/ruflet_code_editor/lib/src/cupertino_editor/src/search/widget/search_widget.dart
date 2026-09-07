// ignore_for_file: invalid_use_of_internal_member
// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/cupertino.dart';

import 'package:flutter_code_editor/src/search/controller.dart';
import 'focus_rediretor.dart';
import 'search_navigation_widget.dart';
import 'search_settings_widget.dart';

const _iconSize = 24.0;

class SearchWidget extends StatelessWidget {
  final CodeSearchController searchController;

  const SearchWidget({
    super.key,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: searchController,
      builder: (context, child) => FocusRedirector(
        redirectTo: searchController.patternFocusNode,
        child: SizedBox(
          height: 50,
          child: IntrinsicWidth(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 6,
                  child: SearchSettingsWidget(
                    patternFocusNode: searchController.patternFocusNode,
                    settingsController: searchController.settingsController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SearchNavigationWidget(
                    searchNavigationController:
                        searchController.navigationController,
                  ),
                ),
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => searchController.hideSearch(
                      returnFocusToCodeField: true,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: _iconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
