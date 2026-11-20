// ruflet-coverage: Lottie
//
// The Lottie control mounted from the protocol map Ruby sends
// (`Ruflet.lottie(src, **props)`), on the Cupertino (TargetPlatform.iOS) and
// Material (TargetPlatform.android) hosts. A small inline animation stands in
// for Ruby's file; asset loads go through a mocked asset channel.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_lottie/ruflet_lottie.dart';
import 'package:ruflet_lottie/src/lottie.dart';

import 'support/harness.dart';

/// A 2-second (60 frames at 30 fps) 100x50 animation with no layers.
final _animationJson = jsonEncode({
  'v': '5.7.4',
  'fr': 30,
  'ip': 0,
  'op': 60,
  'w': 100,
  'h': 50,
  'nm': 'ruflet-test',
  'ddd': 0,
  'assets': [],
  'layers': [],
});
final _animationBytes = Uint8List.fromList(utf8.encode(_animationJson));
final _animationBase64 = base64.encode(_animationBytes);

Map<String, dynamic> _wire(Object? src,
        [Map<String, dynamic> props = const {}]) =>
    {
      '_c': 'Lottie',
      '_i': 5,
      if (src != null) 'src': src,
      ...props,
    };

/// Lets the composition future and the onLoaded microtask complete without
/// settling, since a repeating animation never settles.
Future<void> _load(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  tearDown(() {
    // Each test gets its own compositions, so cached ones cannot hide loads.
    Lottie.cache.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('the extension creates Lottie for its wire type only', () {
    final backend = HarnessBackend(TargetPlatform.android, extensions: []);
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(Extension().createWidget(null, control('Lottie')),
        isA<LottieControl>());
    expect(Extension().createWidget(null, control('Rive')), isNull);
  });

  testWidgets('defaults: plays and repeats forward at the size Ruby gives it',
      (tester) async {
    final mounted = await mountWire(
        tester,
        _wire(_animationBase64, {'width': 120, 'height': 60, 'on_load': true}),
        Extension(),
        settle: false);
    await _load(tester);

    final lottie = tester.widget<Lottie>(find.byType(Lottie));
    expect(lottie.composition, isNotNull);
    expect(lottie.composition!.seconds, closeTo(2, 0.01));
    expect(lottie.animate, isTrue);
    expect(lottie.repeat, isTrue);
    expect(lottie.reverse, isFalse);
    expect(lottie.fit, isNull);
    expect(lottie.alignment, isNull);
    expect(lottie.options!.enableMergePaths, isFalse);
    expect(lottie.options!.enableApplyingOpacityToLayers, isFalse);
    final builder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect(builder.lottie, isA<MemoryLottie>());
    expect(builder.lottie.backgroundLoading, isFalse);

    expect(tester.getSize(find.byType(Lottie)), const Size(120, 60));
    expect(tester.getTopLeft(find.byType(Lottie)), Offset.zero);
    expect(tester.hasRunningAnimations, isTrue);
    expect(mounted.backend.events, [
      [5, 'load', null]
    ]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('hands the plugin every playback and painting option Ruby sets',
      (tester) async {
    await mountWire(
        tester,
        _wire(_animationBase64, {
          'repeat': false,
          'reverse': true,
          'animate': false,
          'fit': 'cover',
          'alignment': {'x': 1, 'y': -1},
          'filter_quality': 'high',
          'enable_merge_paths': true,
          'enable_layers_opacity': true,
        }),
        Extension(),
        settle: false);
    await _load(tester);

    final lottie = tester.widget<Lottie>(find.byType(Lottie));
    expect(lottie.composition, isNotNull);
    expect(lottie.repeat, isFalse);
    expect(lottie.reverse, isTrue);
    expect(lottie.animate, isFalse);
    expect(lottie.fit, BoxFit.cover);
    expect(lottie.alignment, Alignment.topRight);
    expect(lottie.filterQuality, FilterQuality.high);
    expect(lottie.options!.enableMergePaths, isTrue);
    expect(lottie.options!.enableApplyingOpacityToLayers, isTrue);
    // animate: false holds the first frame.
    expect(tester.hasRunningAnimations, isFalse);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('src as raw bytes plays the same animation', (tester) async {
    await mountWire(
        tester, _wire(_animationBytes, {'on_load': true}), Extension(),
        settle: false);
    await _load(tester);

    final lottie = tester.widget<Lottie>(find.byType(Lottie));
    expect(lottie.composition!.seconds, closeTo(2, 0.01));
    expect(
        (tester.widget<LottieBuilder>(find.byType(LottieBuilder)).lottie
                as MemoryLottie)
            .bytes,
        _animationBytes);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('a bundled asset path loads from the app asset bundle',
      (tester) async {
    final requested = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      requested.add(key);
      return key == 'app/assets/success.json'
          ? ByteData.sublistView(_animationBytes)
          : null;
    });

    final mounted = await mountWire(
        tester, _wire('assets/success.json', {'on_load': true}), Extension(),
        settle: false, assetsBundlePath: 'app/assets');
    await _load(tester);

    final builder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect(builder.lottie, isA<AssetLottie>());
    expect((builder.lottie as AssetLottie).keyName, 'app/assets/success.json');
    expect(requested, ['app/assets/success.json']);
    expect(tester.widget<Lottie>(find.byType(Lottie)).composition, isNotNull);
    expect(mounted.backend.eventData('load'), [null]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('a url loads over the network with the headers Ruby sends',
      (tester) async {
    await mountWire(
        tester,
        _wire('https://cdn.ruflet.test/loading.json', {
          'headers': {'Authorization': 'token'},
          'background_loading': true,
        }),
        Extension(),
        settle: false);

    final provider = tester
        .widget<LottieBuilder>(find.byType(LottieBuilder))
        .lottie as NetworkLottie;
    expect(provider.url, 'https://cdn.ruflet.test/loading.json');
    expect(provider.headers, {'Authorization': 'token'});
    expect(provider.backgroundLoading, isTrue);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'a src that fails to load reports on_error and shows error_content',
      (tester) async {
    final mounted = await mountWire(
        tester,
        _wire(base64.encode(utf8.encode('not a lottie file')), {
          'on_error': true,
          'error_content': {'_c': 'Text', '_i': 6, 'value': 'Failed'},
        }),
        Extension(),
        settle: false);
    await _load(tester);

    expect(find.byType(Lottie), findsNothing);
    expect(find.text('Failed'), findsOneWidget);
    expect(mounted.backend.eventData('error'), [isA<String>()]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('without error_content a failed load shows the error, unsent',
      (tester) async {
    final mounted = await mountWire(tester,
        _wire(base64.encode(utf8.encode('not a lottie file'))), Extension(),
        settle: false);
    await _load(tester);

    expect(find.byType(Lottie), findsNothing);
    expect(find.textContaining('Error loading Lottie'), findsOneWidget);
    // Ruby did not subscribe to on_error.
    expect(mounted.backend.events, isEmpty);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('a missing or unsupported src shows an error instead of crashing',
      (tester) async {
    await mountWire(tester, _wire(''), Extension());
    expect(tester.takeException(), isNull);
    expect(find.text('Lottie must have "src" specified.'), findsOneWidget);
    await unmount(tester);

    await mountWire(tester, _wire(null), Extension());
    expect(tester.takeException(), isNull);
    expect(find.byType(Lottie), findsNothing);
    expect(find.textContaining('src'), findsOneWidget);
    await unmount(tester);

    await mountWire(tester, _wire(42), Extension());
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Error decoding src'), findsOneWidget);
    await unmount(tester);

    await mountWire(
        tester,
        _wire(42, {
          'error_content': {'_c': 'Text', '_i': 6, 'value': 'Bad src'}
        }),
        Extension());
    expect(find.text('Bad src'), findsOneWidget);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('a Ruby update that keeps src keeps the loaded composition',
      (tester) async {
    final mounted = await mountWire(
        tester, _wire(_animationBase64, {'on_load': true}), Extension(),
        settle: false);
    await _load(tester);
    final loaded = tester.widget<Lottie>(find.byType(Lottie)).composition;
    expect(loaded, isNotNull);

    // Ruby: lottie.animate = false; page.update (pause it)
    mounted.control.update({'animate': false}, shouldNotify: true);
    await _load(tester);

    final paused = tester.widget<Lottie>(find.byType(Lottie));
    expect(paused.animate, isFalse);
    expect(paused.composition, same(loaded));
    expect(mounted.backend.eventData('load'), [null],
        reason: 'the animation was not loaded again');
    expect(tester.hasRunningAnimations, isFalse);

    // Ruby re-sending the same base64 text: a patch replace op stores a new,
    // equal String (Control.update would keep the old one).
    final sameText = base64.encode(utf8.encode(_animationJson));
    expect(identical(sameText, _animationBase64), isFalse);
    mounted.control.applyPatch([
      [0],
      [0, 0, 'src', sameText]
    ], mounted.backend);
    await _load(tester);
    expect(mounted.control.get('src'), same(sameText));
    expect(tester.widget<Lottie>(find.byType(Lottie)).composition,
        same(loaded));
    expect(mounted.backend.eventData('load'), [null],
        reason: 'the same base64 text is the same animation');

    // A src Ruby replaces is loaded.
    mounted.control.update({'src': _animationBytes}, shouldNotify: true);
    await _load(tester);
    expect(tester.widget<Lottie>(find.byType(Lottie)).composition,
        isNot(same(loaded)));
    expect(mounted.backend.eventData('load'), [null, null]);
    await unmount(tester);
  }, variant: bothDesigns);
}
