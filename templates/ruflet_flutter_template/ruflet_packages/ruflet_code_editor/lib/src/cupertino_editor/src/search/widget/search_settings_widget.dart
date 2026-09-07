// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/cupertino.dart';

import 'package:flutter_code_editor/src/search/settings_controller.dart';

const _hintText = 'Search…';

class SearchSettingsWidget extends StatelessWidget {
  final FocusNode patternFocusNode;
  final SearchSettingsController settingsController;

  const SearchSettingsWidget({
    super.key,
    required this.patternFocusNode,
    required this.settingsController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, child) {
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 100,
                  child: CupertinoTextField(
                    // We need to set this in order to catch
                    // LogicalKeyBoardKey.enter pressed event.
                    // Otherwise we would need to catch it in `onSubmitted`.
                    // The problem with onSubmitted is that
                    // when we receive the event and immediately focus on the
                    // codefield, the flutter also fires the KeyEvent
                    // with EnterKey on the codefield.
                    maxLines: null,
                    placeholder: _hintText,
                    focusNode: patternFocusNode,
                    controller: settingsController.patternController,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: settingsController.value.isCaseSensitive
                  ? CupertinoColors.activeBlue.withValues(alpha: .18)
                  : null,
              onPressed: () {
                patternFocusNode.requestFocus();
                settingsController.toggleCaseSensitivity();
              },
              child: const Text('Aa'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: settingsController.value.isRegExp
                  ? CupertinoColors.activeBlue.withValues(alpha: .18)
                  : null,
              onPressed: () {
                patternFocusNode.requestFocus();
                settingsController.toggleIsRegExp();
              },
              child: const Text('.*'),
            ),
          ],
        );
      },
    );
  }
}
