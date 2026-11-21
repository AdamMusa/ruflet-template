import 'dart:async';

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/services/service_binding.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://invoke-fail-fast'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

/// The Ruby side waits this long; failing fast must not depend on it.
const _rubyTimeout = Duration(seconds: 30);

Widget _app(_Backend backend, Widget child) =>
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: backend.platform == TargetPlatform.iOS
          ? CupertinoApp(home: CupertinoPageScaffold(child: Center(child: child)))
          : material.MaterialApp(home: material.Scaffold(body: Center(child: child))),
    );

/// Starts [method] and reports whether it settled within one frame, without
/// advancing fake time towards [_rubyTimeout].
Future<({bool settled, Object? error})> _invokeNow(
    WidgetTester tester, Control control, String method) async {
  var settled = false;
  Object? error;
  unawaited(control
      .invokeMethod(method, const {}, _rubyTimeout)
      .then((_) {}, onError: (Object e) {
        error = e;
      })
      .whenComplete(() => settled = true));
  await tester.pump();
  return (settled: settled, error: error);
}

void main() {
  testWidgets('a mounted control without a handler fails fast',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final text = Control.fromMap(
        {'_c': 'Text', '_i': 10, 'value': 'Hello'}, backend);
    await tester.pumpWidget(_app(backend, ControlWidget(control: text)));

    expect(text.isAttached, isTrue);
    final result = await _invokeNow(tester, text, 'open');
    expect(result.settled, isTrue);
    expect(
        result.error,
        isA<UnsupportedError>().having((e) => e.message, 'message',
            allOf(contains('Text'), contains('"open"'), contains('android'))));
  });

  testWidgets('iOS ContextMenu.open fails fast instead of timing out',
      (tester) async {
    final backend = _Backend(TargetPlatform.iOS);
    final menu = Control.fromMap({
      '_c': 'ContextMenu',
      '_i': 20,
      'content': {'_c': 'Text', '_i': 21, 'value': 'Hold me'},
      'actions': [
        {
          '_c': 'ContextMenuAction',
          '_i': 22,
          'content': {'_c': 'Text', '_i': 23, 'value': 'Copy'}
        }
      ],
    }, backend);
    await tester.pumpWidget(_app(backend, ControlWidget(control: menu)));

    final result = await _invokeNow(tester, menu, 'open');
    expect(result.settled, isTrue);
    expect(result.error, isA<UnsupportedError>());
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform Window service methods fail fast off desktop',
        (tester) async {
      final backend = _Backend(platform);
      final window = Control(
          id: 30, type: 'Window', properties: {}, backend: backend);
      final binding = ServiceBinding(control: window, backend: backend);

      expect(window.isAttached, isTrue);
      for (final method in ['center', 'close', 'start_resizing']) {
        final result = await _invokeNow(tester, window, method);
        expect(result.settled, isTrue, reason: method);
        expect(
            result.error,
            isA<UnsupportedError>().having((e) => e.message, 'message',
                allOf(contains('Window'), contains(platform.name))),
            reason: method);
      }

      binding.dispose();
      expect(window.isAttached, isFalse);
    });
  }

  // Regression from QA's probe (qa_e59_race_test.dart): on desktop the
  // Window service reads the window state through an async platform round
  // trip. A Window method invoked in that gap must reach the platform once
  // the state is ready, not fail as "not supported".
  testWidgets('desktop Window methods invoked during init wait for readiness',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final calls = <String>[];
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      // A real platform round trip takes a moment.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      switch (call.method) {
        case 'getBounds':
          return {'x': 0.0, 'y': 0.0, 'width': 800.0, 'height': 600.0};
        case 'getOpacity':
          return 1.0;
      }
      if (call.method.startsWith('is')) return false;
      return null;
    });
    try {
      final backend = _Backend(TargetPlatform.macOS);
      final window =
          Control(id: 31, type: 'Window', properties: {}, backend: backend);
      final binding = ServiceBinding(control: window, backend: backend);
      expect(window.isAttached, isTrue);

      Object? error;
      var settled = false;
      unawaited(window
          .invokeMethod('wait_until_ready_to_show', const {}, _rubyTimeout)
          .then((_) {}, onError: (Object e) {
        error = e;
      }).whenComplete(() => settled = true));
      // Still reading the window state: pending, not rejected.
      await tester.pump();
      expect(settled, isFalse);
      expect(calls, isNot(contains('waitUntilReadyToShow')));

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(settled, isTrue);
      expect(error, isNull);
      // The call reached the platform, after the window state was read.
      expect(calls, contains('waitUntilReadyToShow'));
      expect(calls.indexOf('getBounds'),
          lessThan(calls.indexOf('waitUntilReadyToShow')));
      binding.dispose();
    } finally {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop Window calls fail at once when the state read fails',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final calls = <String>[];
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (call.method == 'getBounds') {
        throw PlatformException(code: 'unavailable', message: 'no window');
      }
      if (call.method.startsWith('is')) return false;
      return null;
    });
    try {
      final backend = _Backend(TargetPlatform.macOS);
      final window =
          Control(id: 32, type: 'Window', properties: {}, backend: backend);
      final binding = ServiceBinding(control: window, backend: backend);

      // A call made while the state is being read is still pending...
      Object? pendingError;
      var pendingSettled = false;
      unawaited(window
          .invokeMethod('center', const {}, _rubyTimeout)
          .then((_) {}, onError: (Object e) {
        pendingError = e;
      }).whenComplete(() => pendingSettled = true));
      await tester.pump();
      expect(pendingSettled, isFalse);

      // ...and fails as soon as the read fails, with the reason.
      await tester.pump(const Duration(milliseconds: 50));
      expect(pendingSettled, isTrue);
      expect(
          pendingError,
          isA<StateError>().having((e) => e.message, 'message',
              allOf(contains('Window state could not be read'),
                  contains('no window'))));

      // Later calls fail immediately too, within one frame.
      final later = await _invokeNow(tester, window, 'close');
      expect(later.settled, isTrue);
      expect(later.error, isA<StateError>());

      // Property changes after the failure apply nothing to the window.
      window.update({'width': 500.0}, shouldNotify: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, isNot(contains('center')));
      expect(calls, isNot(contains('close')));
      expect(calls, isNot(contains('setBounds')));
      binding.dispose();
    } finally {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an invoke that arrives before the control mounts still waits',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final field = Control.fromMap(
        {'_c': 'TextField', '_i': 40, 'value': 'x', 'on_focus': true},
        backend);
    expect(field.isAttached, isFalse);

    Object? error;
    var settled = false;
    unawaited(field
        .invokeMethod('focus', const {}, _rubyTimeout)
        .then((_) {}, onError: (Object e) {
        error = e;
      })
        .whenComplete(() => settled = true));
    await tester.pump();
    expect(settled, isFalse);

    await tester.pumpWidget(_app(backend, ControlWidget(control: field)));
    await tester.pump();
    expect(settled, isTrue);
    expect(error, isNull);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);
  });

  testWidgets('a control that never mounts still times out', (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final text = Control.fromMap(
        {'_c': 'Text', '_i': 50, 'value': 'Offscreen'}, backend);

    Object? error;
    final call = text
        .invokeMethod('open', const {}, const Duration(seconds: 1))
        .then((_) {}, onError: (Object e) {
        error = e;
      });
    await tester.pump(const Duration(seconds: 2));
    await call;
    expect(error, isA<TimeoutException>());
  });

  testWidgets('attachment follows the control across rebuilds and unmounts',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final first =
        Control.fromMap({'_c': 'Text', '_i': 60, 'value': 'A'}, backend);
    final second =
        Control.fromMap({'_c': 'Text', '_i': 61, 'value': 'B'}, backend);

    await tester.pumpWidget(_app(backend, ControlWidget(control: first)));
    expect(first.isAttached, isTrue);
    expect(second.isAttached, isFalse);

    // Same element, new control: the attachment moves with it.
    await tester.pumpWidget(_app(backend, ControlWidget(control: second)));
    expect(first.isAttached, isFalse);
    expect(second.isAttached, isTrue);

    // Rendered twice, detached once: still attached.
    await tester.pumpWidget(_app(
        backend,
        Column(mainAxisSize: MainAxisSize.min, children: [
          ControlWidget(control: second),
          ControlWidget(control: second),
        ])));
    expect(second.isAttached, isTrue);

    await tester.pumpWidget(_app(backend, const SizedBox()));
    expect(second.isAttached, isFalse);
  });
}
