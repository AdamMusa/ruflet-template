import 'package:ruflet/ruflet.dart';

import 'permission_handler.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "PermissionHandler":
        return PermissionHandlerService(control: control);
      default:
        return null;
    }
  }
}
