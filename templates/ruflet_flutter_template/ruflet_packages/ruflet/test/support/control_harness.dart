// Shared harness for control behaviour tests: a backend that records what a
// renderer sends to Ruby, apps for each design that install the same style
// scopes as the real app renderers, invoke outcomes and semantics capture.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/core/control_core.dart' show CoreHost;
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/utils/material_style_theme.dart';

/// The design a control renders with, and the platform that selects it.
enum HarnessDesign {
  android(TargetPlatform.android),
  ios(TargetPlatform.iOS);

  const HarnessDesign(this.platform);
  final TargetPlatform platform;
}

/// One message a renderer sent to Ruby.
class SentMessage {
  SentMessage.event(this.id, this.name, this.data) : props = null;
  SentMessage.update(this.id, Map<String, dynamic> props)
      : name = 'update',
        data = null,
        props = Map.of(props);

  final int id;
  final String name;
  final Object? data;
  final Map<String, dynamic>? props;

  Map<String, Object?> toJson() => props != null
      ? {'id': id, 'update': jsonSafe(props)}
      : {'id': id, 'event': name, 'data': jsonSafe(data)};
}

/// Records events exactly as the real backend would send them (only when
/// Ruby subscribed) and every write-back, without a connection.
class HarnessBackend extends RufletBackend {
  HarnessBackend(HarnessDesign design, {super.extensions = const []})
      : super(
            pageUri: Uri.parse('ruflet://harness'),
            assetsDir: '',
            multiView: false) {
    platform = design.platform;
  }

  final List<SentMessage> sent = [];

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    if (control.get("on_$eventName") == true) {
      sent.add(SentMessage.event(control.id, eventName, eventData));
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    sent.add(SentMessage.update(id, props));
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

/// A design app around [child], with the style scope the real app renderer
/// installs, aligned top-left so geometry is the control's own.
Widget harnessApp(HarnessBackend backend, HarnessDesign design, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: design == HarnessDesign.ios
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

/// Deep-copies a wire map so each mount gets fresh Control instances.
Map<String, dynamic> copyWire(Map<String, dynamic> wire) =>
    _copy(wire) as Map<String, dynamic>;

Object? _copy(Object? value) => switch (value) {
      Map() => <String, dynamic>{
          for (final e in value.entries) e.key as String: _copy(e.value)
        },
      List() => [for (final e in value) _copy(e)],
      _ => value,
    };

/// The first node of [wireType] in a wire tree (depth first).
Map<String, dynamic>? findWireNode(Object? wire, String wireType) {
  if (wire is Map) {
    if (wire['_c'] == wireType) return wire.cast<String, dynamic>();
    for (final value in wire.values) {
      final found = findWireNode(value, wireType);
      if (found != null) return found;
    }
  } else if (wire is List) {
    for (final value in wire) {
      final found = findWireNode(value, wireType);
      if (found != null) return found;
    }
  }
  return null;
}

/// A mounted wire tree.
class HarnessMount {
  HarnessMount(this.backend, this.design, this.root);
  final HarnessBackend backend;
  final HarnessDesign design;
  final Control root;

  Control control(int id) => backend.controlsIndex.get(id)!;
}

/// Mounts [wire] (a root control map) in a [design] app, starting from an
/// empty tree so no element or focus state survives from a previous mount.
/// With [settle] false it returns after the first frame, before animations
/// run (a repeating one never settles).
Future<HarnessMount> mountWire(
    WidgetTester tester, HarnessDesign design, Map<String, dynamic> wire,
    {List<RufletExtension> extensions = const [],
    Size surface = const Size(800, 600),
    bool settle = true}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final backend = HarnessBackend(design, extensions: extensions);
  final root = Control.fromMap(copyWire(wire), backend);
  await tester.pumpWidget(const SizedBox());
  await tester
      .pumpWidget(harnessApp(backend, design, ControlWidget(control: root)));
  if (settle) await tester.pumpAndSettle();
  return HarnessMount(backend, design, root);
}

/// The settled result of one invoke.
class InvokeOutcome {
  InvokeOutcome.value(this.value) : error = null;
  InvokeOutcome.error(Object this.error) : value = null;

  final Object? value;
  final Object? error;

  bool get timedOut => error is TimeoutException;
  bool get unsupported => error is UnsupportedError;

  Map<String, Object?> toJson() => error == null
      ? {'result': jsonSafe(value)}
      : {
          'error': error.runtimeType.toString(),
          'message': switch (error) {
            UnsupportedError e => e.message,
            TimeoutException e => e.message,
            _ => error.toString(),
          },
        };
}

/// Invokes [name] on [control] the way the backend does, letting fake time
/// run past [timeout] so a call nobody answers settles as a timeout.
Future<InvokeOutcome> invokeOutcome(
    WidgetTester tester, Control control, String name,
    {Object? args,
    Duration timeout = const Duration(milliseconds: 200)}) async {
  InvokeOutcome? outcome;
  unawaited(control.invokeMethod(name, args, timeout).then(
      (value) => outcome = InvokeOutcome.value(value),
      onError: (Object error) => outcome = InvokeOutcome.error(error)));
  await tester.pump();
  if (outcome == null) await tester.pump(timeout * 2);
  return outcome ??
      InvokeOutcome.error(StateError('invoke $name did not settle'));
}

/// Every invoke listener on [control], counted through CoreHost's debug
/// census: 1 when a single CoreHost listens, the number of results when
/// several listeners answer, 0 when none does (the call times out), and -1
/// when a listener that is not a CoreHost rejects the census.
Future<int> invokeListenerCount(WidgetTester tester, Control control) async {
  final outcome =
      await invokeOutcome(tester, control, CoreHost.debugCensusMethod);
  if (outcome.timedOut) return 0;
  final value = outcome.value;
  if (value == CoreHost.debugCensusReply) return 1;
  if (value is List) return value.length;
  return -1;
}

/// The semantics nodes (with something to say) inside [finder]'s rect, in
/// tree order, as plain data.
List<Map<String, Object?>> semanticsWithin(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final area = box.localToGlobal(Offset.zero) & box.size;
  final owner = _semanticsOwner(tester);
  final nodes = <Map<String, Object?>>[];
  void visit(SemanticsNode node) {
    // Nodes merged into a parent are not exposed to assistive technology;
    // their parent already reports them.
    if (node.isMergedIntoParent) return;
    final data = node.getSemanticsData();
    final rect = globalSemanticsRect(node, tester.view.devicePixelRatio);
    final flags = data.flagsCollection.toStrings();
    final actions = [
      for (final action in SemanticsAction.values)
        if (data.hasAction(action)) action.name
    ];
    if (area.inflate(0.5).contains(rect.topLeft) &&
        area.inflate(0.5).contains(rect.bottomRight) &&
        (flags.isNotEmpty ||
            actions.isNotEmpty ||
            data.label.isNotEmpty ||
            data.value.isNotEmpty)) {
      nodes.add({
        'label': data.label,
        if (data.value.isNotEmpty) 'value': data.value,
        'flags': flags,
        'actions': actions,
        'rect': rectJson(rect),
      });
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root = owner?.rootSemanticsNode;
  if (root != null) visit(root);
  return nodes;
}

/// A semantics node's rect in logical global coordinates: the tree's
/// transforms end in physical pixels, so divide by the device pixel ratio.
Rect globalSemanticsRect(SemanticsNode node, double devicePixelRatio) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    final transform = n.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
  }
  return Rect.fromLTRB(
      rect.left / devicePixelRatio,
      rect.top / devicePixelRatio,
      rect.right / devicePixelRatio,
      rect.bottom / devicePixelRatio);
}

/// The first semantics node inside [finder] that has [action].
SemanticsNode? semanticsNodeWith(
    WidgetTester tester, Finder finder, SemanticsAction action) {
  final box = tester.renderObject<RenderBox>(finder);
  final area = (box.localToGlobal(Offset.zero) & box.size).inflate(0.5);
  final owner = _semanticsOwner(tester);
  SemanticsNode? found;
  void visit(SemanticsNode node) {
    if (found != null) return;
    final rect = globalSemanticsRect(node, tester.view.devicePixelRatio);
    if (node.getSemanticsData().hasAction(action) &&
        area.contains(rect.topLeft) &&
        area.contains(rect.bottomRight)) {
      found = node;
      return;
    }
    node.visitChildren((child) {
      visit(child);
      return found == null;
    });
  }

  final root = owner?.rootSemanticsNode;
  if (root != null) visit(root);
  return found;
}

/// Performs [action] on the first node inside [finder] that supports it, the
/// way assistive technology would. Returns false when no node has it.
Future<bool> performSemanticsAction(
    WidgetTester tester, Finder finder, SemanticsAction action) async {
  final node = semanticsNodeWith(tester, finder, action);
  if (node == null) return false;
  final owner = _semanticsOwner(tester);
  owner!.performAction(node.id, action);
  await tester.pumpAndSettle();
  return true;
}

SemanticsOwner? _semanticsOwner(WidgetTester tester) =>
    tester.binding.renderViews.first.owner?.semanticsOwner;

double _round(double v) => (v * 10).roundToDouble() / 10;

Map<String, double> rectJson(Rect rect) => {
      'l': _round(rect.left),
      't': _round(rect.top),
      'w': _round(rect.width),
      'h': _round(rect.height),
    };

/// Converts values sent to Ruby into JSON-comparable data.
Object? jsonSafe(Object? value) => switch (value) {
      null || bool() || String() => value,
      int() => value,
      double() => _round(value),
      Map() => {
          for (final e in value.entries) e.key.toString(): jsonSafe(e.value)
        },
      List() => [for (final e in value) jsonSafe(e)],
      _ => value.toString(),
    };
