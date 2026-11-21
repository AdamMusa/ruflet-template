import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// Relative, not package:ruflet_client/: `ruflet build` renames this package to
// the app's package name, and build/client keeps this test, so a package
// import would stop resolving there.
//
// lib/main.self.dart carries a byte-identical copy of these functions
// (tool/conformance/test_bootstrap_hooks_contract.rb holds them equal). It is
// not imported here because it only compiles against the ruby_runtime that
// `ruflet build --self` pins.
// ignore: avoid_relative_lib_imports
import '../lib/main.server.dart';

// Only the runner is tested here, never the two hook lists by name. While a
// build feature adds hooks, `ruflet build` moves the lists into
// lib/ruflet_bootstrap.g.dart, which the entrypoints import but do not
// export, so a test naming them would stop compiling in that build/client.
// tool/conformance/test_bootstrap_hooks_contract.rb pins that the template
// declares both lists empty.
void main() {
  test('awaits each hook before starting the next, in list order', () async {
    final calls = <String>[];
    await runRufletBootstrapHooks([
      () async {
        calls.add('a started');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        calls.add('a finished');
      },
      () => calls.add('b'),
      () async => calls.add('c'),
    ], 'pre-runApp');

    expect(calls, ['a started', 'a finished', 'b', 'c']);
  });

  test('reports a failing hook and still runs the hooks after it', () async {
    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    final calls = <String>[];

    await runRufletBootstrapHooks([
      () => throw StateError('sync failure'),
      () async => throw StateError('async failure'),
      () => calls.add('after'),
    ], 'pre-runApp');

    expect(calls, ['after']);
    expect(
      reported.map((details) => (details.exception as StateError).message),
      ['sync failure', 'async failure'],
    );
    for (final details in reported) {
      expect(details.library, 'ruflet bootstrap');
      expect(details.stack, isNotNull);
      expect(details.context.toString(), 'while running a pre-runApp hook');
    }
  });

  testWidgets('post-first-frame hooks run once, after the first frame', (
    tester,
  ) async {
    final calls = <String>[];
    scheduleRufletBootstrapHooksAfterFirstFrame([
      () => calls.add('a'),
      () async => calls.add('b'),
    ]);
    expect(calls, isEmpty, reason: 'no frame has been drawn yet');

    await tester.pumpWidget(const SizedBox());
    expect(calls, ['a', 'b']);

    await tester.pumpWidget(const Placeholder());
    expect(calls, ['a', 'b'], reason: 'the hooks run after one frame only');
  });

  testWidgets('a failing post-first-frame hook is reported', (tester) async {
    final calls = <String>[];
    scheduleRufletBootstrapHooksAfterFirstFrame([
      () => throw StateError('frame failure'),
      () => calls.add('after'),
    ]);

    await tester.pumpWidget(const SizedBox());

    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect((error as StateError).message, 'frame failure');
    expect(calls, ['after']);
  });
}
