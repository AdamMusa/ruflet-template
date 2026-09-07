import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';

import 'lottie.dart';

class Extension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "Lottie":
        return LottieControl(control: control);
      default:
        return null;
    }
  }
}
