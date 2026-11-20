// Test harness for extension controls: a backend that records what a
// renderer sends to Ruby, and the app each design renders in, with the same
// style scopes the real app renderers install (see packages/ruflet's
// test/support/control_harness.dart, which extension tests cannot import).
// ignore_for_file: implementation_imports
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/utils/material_style_theme.dart';

/// Records events exactly as the real backend sends them (only when Ruby
/// subscribed with `on_<name>: true`) and every write-back, without a
/// connection.
class HarnessBackend extends RufletBackend {
  HarnessBackend(TargetPlatform target, {required super.extensions})
      : super(
            pageUri: Uri.parse('ruflet://harness'),
            assetsDir: '',
            multiView: false) {
    platform = target;
  }

  /// Every event sent to Ruby, as `[control id, event name, data]`.
  final List<List<Object?>> events = [];
  final List<Map<String, dynamic>> updates = [];

  /// The data of every [name] event sent to Ruby, in order.
  List<Object?> eventData(String name) => [
        for (final e in events)
          if (e[1] == name) e[2]
      ];

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    if (control.get("on_$eventName") == true) {
      events.add([control.id, eventName, eventData]);
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    updates.add({'id': id, ...props});
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

/// The app [backend]'s design renders in (Cupertino for iOS, Material
/// otherwise), with [child] aligned top-left so geometry is the control's own.
Widget harnessApp(HarnessBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) =>
                cupertinoStyleThemeScope(context, child!),
            home: CupertinoPageScaffold(child: body),
          )
        : material.MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => RufletStyleThemeScope(
                data: materialStyleTheme(material.Theme.of(context)),
                child: child!),
            home: material.Scaffold(body: body),
          ),
  );
}

/// A mounted control and the backend recording what it sends.
typedef Mounted = ({HarnessBackend backend, Control control});

/// Mounts the wire map [wire] for the current [defaultTargetPlatform] (set by
/// a [TargetPlatformVariant]) through [ControlWidget], so the control is
/// created by [extension] exactly as the app creates it.
Future<Mounted> mountWire(
    WidgetTester tester, Map<String, dynamic> wire, RufletExtension extension,
    {bool settle = true}) async {
  final backend =
      HarnessBackend(defaultTargetPlatform, extensions: [extension]);
  final control = Control.fromMap(wire, backend);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(harnessApp(backend, ControlWidget(control: control)));
  if (settle) await tester.pumpAndSettle();
  return (backend: backend, control: control);
}

/// Unmounts everything, so dispose runs inside the test.
Future<void> unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

/// Both designs: Cupertino (iOS host) and Material (Android host).
const bothDesigns =
    TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});
