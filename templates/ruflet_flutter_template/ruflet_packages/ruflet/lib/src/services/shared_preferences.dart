import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ruflet_service.dart';
import '../utils/invoke.dart';

class SharedPreferencesService extends RufletService {
  SharedPreferencesService({required super.control});

  @override
  void init() {
    super.init();
    debugPrint(
        "SharedPreferencesService(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void update() {
    debugPrint(
        "SharedPreferencesService(${control.id}).update: ${control.properties}");
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    final key = const {"set", "get", "contains_key", "remove"}.contains(name)
        ? requireInvokeArg(args, "key", "SharedPreferences.$name").toString()
        : null;
    if (name == "set") requireInvokeArg(args, "value", "SharedPreferences.set");
    var prefs = await SharedPreferences.getInstance();
    switch (name) {
      case "set":
        return prefs.setString(key!, args["value"].toString());
      case "get":
        return prefs.getString(key!);
      case "contains_key":
        return prefs.containsKey(key!);
      case "get_keys":
        final prefix = args["key_prefix"]?.toString() ?? "";
        return prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
      case "remove":
        return prefs.remove(key!);
      case "clear":
        return prefs.clear();
      default:
        throw Exception("Unknown SharedPreferences method: $name");
    }
  }

  @override
  void dispose() {
    debugPrint("SharedPreferencesService(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }
}
