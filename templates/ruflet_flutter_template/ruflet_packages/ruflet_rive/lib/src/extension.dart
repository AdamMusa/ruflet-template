import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:rive/rive.dart';

import 'rive.dart';

class Extension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "Rive":
        return RiveControl(control: control);
      default:
        return null;
    }
  }

  @override
  void ensureInitialized() {
    RiveNative.init();
  }
}
