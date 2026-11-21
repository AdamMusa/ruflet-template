// JSON behaviour snapshots of one control on one design.
//
// A snapshot records (a) geometry: the control's size and the rects of its
// Text, Icon and keyed descendants, (b) the semantics nodes inside it, (c) what
// it sent to Ruby (events and write-backs) after each scripted step and (d)
// invoke outcomes. Text, not pixels: stable across hosts and reviewable as a
// diff. Snapshots live in test/snapshots/<WireType>/<fixture>.<design>.json and
// are rewritten only by `flutter test --update-goldens`.
//
// Migration PRs add the snapshot test against the legacy renderer first; the
// migration commit may then change a snapshot only for a row of the PR's
// "Parity changes" table.
import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

import 'control_harness.dart';

/// What a step can reach while it runs.
class SnapshotContext {
  SnapshotContext(this.tester, this.mount, this.target);
  final WidgetTester tester;
  final HarnessMount mount;

  /// The control under test.
  final Control target;

  /// The control under test's widget.
  Finder get finder => find.byWidgetPredicate(
      (widget) => widget is ControlWidget && widget.control.id == target.id);

  /// The native widget of the selected skin inside the control, when the
  /// runner knows its type (the contract test's parity scripts).
  Finder? native;

  /// Set by an invoke step.
  InvokeOutcome? outcome;

  /// Set by a step that could not interact (recorded instead of failing, so
  /// a legacy renderer's missing behaviour is part of its snapshot).
  String? note;
}

/// One scripted interaction; what the control sends during it is recorded.
class SnapshotStep {
  const SnapshotStep(this.name, this.run);

  final String name;
  final Future<void> Function(SnapshotContext context) run;

  /// Taps the center of [text]; notes it when no such text is rendered.
  factory SnapshotStep.tapText(String text) =>
      SnapshotStep('tap text "$text"', (c) async {
        final target = find.text(text);
        if (target.evaluate().isEmpty) {
          c.note = 'text not rendered';
          return;
        }
        await c.tester.tap(target.first, warnIfMissed: false);
        await c.tester.pumpAndSettle();
      });

  /// Performs the semantics tap of the control's first tappable node: the
  /// native toggle/button, as assistive technology would.
  factory SnapshotStep.semanticsTap() =>
      SnapshotStep('semantics tap', (c) async {
        if (!await performSemanticsAction(
            c.tester, c.finder, SemanticsAction.tap)) {
          c.note = 'no tappable semantics node';
        }
      });

  /// Taps the control at [fraction] of its size (0..1 on each axis).
  factory SnapshotStep.tapAt(Offset fraction) =>
      SnapshotStep('tap at ${fraction.dx},${fraction.dy}', (c) async {
        final box = c.tester.renderObject<RenderBox>(c.finder.first);
        await c.tester.tapAt(box.localToGlobal(Offset(
            box.size.width * fraction.dx, box.size.height * fraction.dy)));
        await c.tester.pumpAndSettle();
      });

  /// Taps the selected skin's native widget with a pointer, so the skin's
  /// own wiring (not the core's label or semantics path) is exercised.
  factory SnapshotStep.tapNative() => SnapshotStep('tap native', (c) async {
        final native = c.native;
        if (native == null || native.evaluate().isEmpty) {
          c.note = 'native widget not rendered';
          return;
        }
        await c.tester.tap(native.first, warnIfMissed: false);
        await c.tester.pumpAndSettle();
      });

  /// Removes keyboard focus from whatever has it (blur events).
  factory SnapshotStep.unfocus() => SnapshotStep('unfocus', (c) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await c.tester.pumpAndSettle();
      });

  /// Moves keyboard focus with Tab (focus/blur events).
  factory SnapshotStep.tab() => SnapshotStep('tab', (c) async {
        await c.tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await c.tester.pumpAndSettle();
      });

  /// Invokes a method on the control under test.
  factory SnapshotStep.invoke(String method, {Object? args}) =>
      SnapshotStep('invoke $method', (c) async {
        c.outcome = await invokeOutcome(c.tester, c.target, method, args: args);
        await c.tester.pumpAndSettle();
      });
}

/// A wire tree, the id of the control under test and an interaction script.
class SnapshotFixture {
  const SnapshotFixture(this.name, this.wire,
      {required this.target,
      this.steps = const [],
      this.extensions = const []});

  final String name;
  final Map<String, dynamic> wire;
  final int target;
  final List<SnapshotStep> steps;

  /// Extensions registering test-only controls.
  final List<RufletExtension> extensions;
}

/// Renders [fixture] on [design] and records its snapshot.
Future<Map<String, Object?>> captureSnapshot(
    WidgetTester tester, HarnessDesign design, SnapshotFixture fixture) async {
  final semantics = tester.ensureSemantics();
  try {
    final mount = await mountWire(tester, design, fixture.wire,
        extensions: fixture.extensions);
    final context =
        SnapshotContext(tester, mount, mount.control(fixture.target));
    expect(context.finder, findsOneWidget,
        reason: '${fixture.name}: control ${fixture.target} is not rendered');
    final snapshot = <String, Object?>{
      'fixture': fixture.name,
      'design': design.name,
      'geometry': _geometry(tester, context.finder),
      'semantics': semanticsWithin(tester, context.finder),
    };
    final steps = <Map<String, Object?>>[];
    mount.backend.sent.clear();
    for (final step in fixture.steps) {
      context
        ..outcome = null
        ..note = null;
      await step.run(context);
      steps.add({
        'step': step.name,
        if (context.note != null) 'note': context.note,
        'sent': [for (final m in mount.backend.sent) m.toJson()],
        if (context.outcome != null) 'outcome': context.outcome!.toJson(),
        'semantics': semanticsWithin(tester, context.finder),
      });
      mount.backend.sent.clear();
    }
    snapshot['steps'] = steps;
    final exception = tester.takeException();
    expect(exception, isNull, reason: '${fixture.name}: $exception');
    return snapshot;
  } finally {
    semantics.dispose();
  }
}

Map<String, Object?> _geometry(WidgetTester tester, Finder finder) {
  final root = tester.renderObject<RenderBox>(finder.first);
  final origin = root.localToGlobal(Offset.zero);
  Map<String, double> rectOf(Element element) {
    final box = element.renderObject as RenderBox;
    return rectJson((box.localToGlobal(Offset.zero) - origin) & box.size);
  }

  final elements = <Map<String, Object?>>[];
  for (final element in find
      .descendant(
          of: finder.first, matching: find.byWidgetPredicate((w) => true))
      .evaluate()) {
    final widget = element.widget;
    if (element.renderObject is! RenderBox) continue;
    if (widget is Text) {
      elements.add({
        'text': widget.data ?? widget.textSpan?.toPlainText(),
        'rect': rectOf(element),
      });
    } else if (widget is Icon) {
      elements.add({
        'icon': widget.icon?.codePoint,
        'rect': rectOf(element),
      });
    } else if (widget.key case ValueKey<String>(:final value)
        when !value.startsWith('control_')) {
      elements.add({'key': value, 'rect': rectOf(element)});
    }
  }
  return {
    'size': {
      'w': rectJson(Offset.zero & root.size)['w'],
      'h': rectJson(Offset.zero & root.size)['h'],
    },
    'elements': elements,
  };
}

/// Compares [snapshot] with the checked-in file at [path] (relative to the
/// package root); `flutter test --update-goldens` rewrites it instead.
void expectSnapshot(Map<String, Object?> snapshot, String path) {
  final text = '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n';
  final file = File(path);
  if (autoUpdateGoldenFiles) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
    return;
  }
  expect(file.existsSync(), isTrue,
      reason: 'Missing snapshot $path: run `flutter test --update-goldens`');
  expect(text, file.readAsStringSync(),
      reason: 'Snapshot $path changed. If the change is intended, list it in '
          'the PR "Parity changes" table and rerun with --update-goldens.');
}

/// Snapshot path for [fixture] of [wireType] on [design].
String snapshotPath(String wireType, String fixture, HarnessDesign design) =>
    'test/snapshots/$wireType/$fixture.${design.name}.json';
