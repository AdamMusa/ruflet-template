// Test harness for this extension: a backend that records what the renderer
// sends to Ruby (events only when Ruby subscribed, every write-back), and
// apps for each design that install the same style scopes as the real app
// renderers. Mirrors packages/ruflet/test/support/control_harness.dart.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/utils/material_style_theme.dart';

/// One event the renderer sent to Ruby.
typedef SentEvent = ({int id, String name, Object? data});

/// Records events exactly as the real backend sends them (only when Ruby
/// subscribed with `on_<name>: true`) and every write-back.
class RecordingBackend extends RufletBackend {
  RecordingBackend(TargetPlatform design, {required super.extensions})
      : super(
            pageUri: Uri.parse('ruflet://test'),
            assetsDir: '',
            multiView: false) {
    platform = design;
  }

  final events = <SentEvent>[];
  final updates = <(int, Map<String, dynamic>)>[];

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    if (control.get("on_$eventName") == true) {
      events.add((id: control.id, name: eventName, data: eventData));
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    updates.add((id, Map.of(props)));
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

/// A design app around [child] with the style scope the real renderer
/// installs, aligned top-left so geometry is the control's own.
Widget designApp(
    RecordingBackend backend, TargetPlatform design, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: design == TargetPlatform.iOS
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

/// A mounted wire tree.
class Mounted {
  Mounted(this.backend, this.root);
  final RecordingBackend backend;
  final Control root;

  Control control(int id) => backend.controlsIndex.get(id)!;
}

/// Mounts [wire] (a root control map, as Ruby sends it) in the app of the
/// design [design] selects (iOS: Cupertino, otherwise Material).
Future<Mounted> mountWire(
    WidgetTester tester, TargetPlatform design, Map<String, dynamic> wire,
    {required List<RufletExtension> extensions,
    Size surface = const Size(800, 600),
    bool settle = true}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final backend = RecordingBackend(design, extensions: extensions);
  final root = Control.fromMap(wire, backend);
  await tester.pumpWidget(const SizedBox());
  await tester
      .pumpWidget(designApp(backend, design, ControlWidget(control: root)));
  if (settle) await tester.pumpAndSettle();
  return Mounted(backend, root);
}
