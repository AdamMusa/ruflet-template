import 'package:ruflet/ruflet.dart';

import 'flashlight.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "Flashlight":
        return FlashlightControl(control: control);
      default:
        return null;
    }
  }
}
