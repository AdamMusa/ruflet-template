import 'package:ruflet/ruflet.dart';

import 'geolocator.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "Geolocator":
        return GeolocatorService(control: control);
      default:
        return null;
    }
  }
}
