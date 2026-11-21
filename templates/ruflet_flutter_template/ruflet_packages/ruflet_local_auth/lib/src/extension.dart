import 'package:ruflet/ruflet.dart';

import 'local_auth.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "LocalAuthentication":
        return LocalAuthenticationService(control: control);
      default:
        return null;
    }
  }
}
