import 'package:flutter/widgets.dart';

import '../ruflet_service.dart';
import '../testing/test_finder.dart';
import '../utils/icons.dart';
import '../utils/invoke.dart';
import '../utils/keys.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import 'package:ruflet/src/utils/transforms.dart';


class TesterService extends RufletService {
  TesterService({required super.control});
  final Map<int, TestFinder> _finders = {};

  @override
  void init() {
    super.init();
    debugPrint("Tester(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    debugPrint("Tester(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("Tester.$name($args)");
    final tester = control.backend.tester;
    if (tester == null) {
      // A silent no-op would let a broken test script pass.
      throw StateError("Tester.$name requires a running test harness");
    }
    final finderIndex = parseInt(args["finder_index"], 0)!;
    switch (name) {
      case "pump":
        await tester.pump(duration: parseDuration(args["duration"]));

      case "pump_and_settle":
        await tester.pumpAndSettle(duration: parseDuration(args["duration"]));

      case "find_by_text":
        var finder = tester
            .findByText(requireInvokeArg(args, "text", "Tester.$name").toString());
        _finders[finder.id] = finder;
        return finder.toMap();

      case "find_by_text_containing":
        var finder = tester.findByTextContaining(
            requireInvokeArg(args, "pattern", "Tester.$name").toString());
        _finders[finder.id] = finder;
        return finder.toMap();

      case "find_by_key":
        var controlKey =
            parseKey(requireInvokeArg(args, "key", "Tester.$name"));
        if (controlKey == null) {
          throw ArgumentError('Tester.$name requires a valid "key" argument');
        }
        var key = controlKey is ControlScrollKey
            ? control.backend.globalKeys[controlKey.toString()]
            : ValueKey(controlKey.value);
        if (key == null) {
          throw Exception("Key not found: $key");
        }
        var finder = tester.findByKey(key);
        _finders[finder.id] = finder;
        return finder.toMap();

      case "find_by_tooltip":
        var finder = tester.findByTooltip(
            requireInvokeArg(args, "value", "Tester.$name").toString());
        _finders[finder.id] = finder;
        return finder.toMap();

      case "find_by_icon":
        var iconCode = requireInvokeArg(args, "icon", "Tester.$name");
        var icon = parseIconData(iconCode, control.backend);
        if (icon == null) {
          throw Exception("Icon not found: $iconCode");
        }
        var finder = tester.findByIcon(icon);
        _finders[finder.id] = finder;
        return finder.toMap();

      case "take_screenshot":
        return await tester.takeScreenshot(
            requireInvokeArg(args, "name", "Tester.$name").toString());

      case "tap":
        var finder = _finders[requireInvokeArg(args, "finder_id", "Tester.$name")];
        if (finder != null) {
          await tester.tap(finder, finderIndex);
        }

      case "tap_at":
        var offset =
            parseOffset(requireInvokeArg(args, "offset", "Tester.$name"));
        if (offset != null) {
          await tester.tapAt(offset);
        }

      case "long_press":
        var finder = _finders[requireInvokeArg(args, "finder_id", "Tester.$name")];
        if (finder != null) {
          await tester.longPress(finder, finderIndex);
        }

      case "enter_text":
        var finder = _finders[requireInvokeArg(args, "finder_id", "Tester.$name")];
        final text = requireInvokeArg(args, "text", "Tester.$name").toString();
        if (finder != null) {
          await tester.enterText(finder, finderIndex, text);
        }

      case "mouse_hover":
        var finder = _finders[requireInvokeArg(args, "finder_id", "Tester.$name")];
        if (finder != null) {
          await tester.mouseHover(finder, finderIndex);
        }

      case "teardown":
        tester.teardown();

      default:
        throw Exception("Unknown Tester method: $name");
    }
  }
}
