// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/cupertino.dart';

/// This widget wraps the child with [InkWell] and
/// redirects the focus to [redirectTo] when receiving onTap events.
///
/// This is needed in order not to lose focus from [redirectTo],
/// when the user misclicks on other areas of the widget.
class FocusRedirector extends StatelessWidget {
  final Widget child;
  final FocusNode redirectTo;

  const FocusRedirector({
    super.key,
    required this.child,
    required this.redirectTo,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: redirectTo.requestFocus,
      child: child,
    );
  }
}
