import 'package:flutter/foundation.dart';

/// Platform-neutral commands supported by all page scaffold renderers.
class PlatformPageScaffoldController {
  Object? _owner;
  VoidCallback? _showDrawer;
  VoidCallback? _closeDrawer;
  VoidCallback? _showEndDrawer;
  VoidCallback? _closeEndDrawer;

  void attach({
    required Object owner,
    required VoidCallback showDrawer,
    required VoidCallback closeDrawer,
    required VoidCallback showEndDrawer,
    required VoidCallback closeEndDrawer,
  }) {
    _owner = owner;
    _showDrawer = showDrawer;
    _closeDrawer = closeDrawer;
    _showEndDrawer = showEndDrawer;
    _closeEndDrawer = closeEndDrawer;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) {
      return;
    }
    _owner = null;
    _showDrawer = null;
    _closeDrawer = null;
    _showEndDrawer = null;
    _closeEndDrawer = null;
  }

  void showDrawer() => _showDrawer?.call();
  void closeDrawer() => _closeDrawer?.call();
  void showEndDrawer() => _showEndDrawer?.call();
  void closeEndDrawer() => _closeEndDrawer?.call();
}
