import 'package:ruflet/ruflet.dart';

import 'secure_storage.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "SecureStorage":
        return SecureStorageService(control: control);
      default:
        return null;
    }
  }
}
