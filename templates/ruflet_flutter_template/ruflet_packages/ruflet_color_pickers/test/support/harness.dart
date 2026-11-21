// Test harness for the color pickers: a backend that records what the
// renderer sends to Ruby (events only when Ruby subscribed, every
// write-back), and apps for each design that install the same style scopes
// as the real app renderers. Mirrors packages/ruflet/test/support/
// control_harness.dart, which extension tests cannot import.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/utils/material_style_theme.dart';
import 'package:ruflet_color_pickers/ruflet_color_pickers.dart';

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

  /// The names of the events sent so far.
  List<String> get eventNames => [for (final e in events) e.name];

  /// The payloads of the [name] events sent so far.
  List<Object?> eventData(String name) => [
        for (final e in events)
          if (e.name == name) e.data
      ];

  /// The last value written back for [prop], or null.
  Object? lastWriteBack(String prop) {
    for (final (_, props) in updates.reversed) {
      if (props.containsKey(prop)) return props[prop];
    }
    return null;
  }

  /// Every property name written back so far.
  Set<String> get writtenBack => {for (final (_, p) in updates) ...p.keys};
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
}

/// Mounts [wire] (a root control map, as Ruby sends it) in the app of the
/// design [design] selects (iOS: Cupertino, otherwise Material), on a
/// portrait phone-sized view so the pickers use their portrait layouts.
Future<Mounted> mountWire(
    WidgetTester tester, TargetPlatform design, Map<String, dynamic> wire,
    {List<RufletExtension>? extensions,
    Size surface = const Size(420, 1100)}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend =
      RecordingBackend(design, extensions: extensions ?? [Extension()]);
  final root = Control.fromMap(wire, backend);
  await tester.pumpWidget(const SizedBox());
  await tester
      .pumpWidget(designApp(backend, design, ControlWidget(control: root)));
  await tester.pumpAndSettle();
  return Mounted(backend, root);
}

/// Applies a property patch the way a Ruby `update` reaches the control.
Future<void> rubyPatch(
    WidgetTester tester, Control control, Map<String, dynamic> props) async {
  control.update(props, shouldNotify: true);
  await tester.pumpAndSettle();
}

/// Widgets whose class is named [name]: the Cupertino fork and the upstream
/// Material picker define same-named classes in different libraries.
Finder byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);
