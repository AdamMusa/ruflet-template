import 'package:ruflet/ruflet.dart';

import 'audio.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "Audio":
        return AudioService(control: control);
      default:
        return null;
    }
  }
}
