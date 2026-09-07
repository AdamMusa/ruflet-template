import 'package:flutter/widgets.dart';

import 'ruflet_service.dart';
import 'models/control.dart';

abstract class RufletExtension {
  void ensureInitialized() {}

  Widget? createWidget(Key? key, Control control) {
    return null;
  }

  RufletService? createService(Control control) {
    return null;
  }

  IconData? createIconData(int iconCode) {
    return null;
  }
}
