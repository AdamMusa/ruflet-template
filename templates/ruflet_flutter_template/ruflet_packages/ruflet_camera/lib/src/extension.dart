import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'camera.dart';

class Extension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "Camera":
        return CameraControl(key: key, control: control);
      default:
        return null;
    }
  }
}
