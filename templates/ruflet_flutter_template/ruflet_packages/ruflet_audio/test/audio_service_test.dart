import 'dart:async';
import 'dart:convert';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_audio/src/audio.dart';

/// Dart fake of the audioplayers platform, so no platform channel is used.
class _FakePlayers extends AudioplayersPlatformInterface {
  final _events = StreamController<AudioEvent>.broadcast();
  final loadedBytes = <Uint8List>[];
  PlatformException? loadError;

  @override
  Stream<AudioEvent> getEventStream(String playerId) => _events.stream;

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes,
      {String? mimeType}) async {
    loadedBytes.add(bytes);
    // Native players report load failures on the player's event channel.
    if (loadError != null) {
      _events.addError(loadError!);
    } else {
      _events.add(const AudioEvent(
          eventType: AudioEventType.prepared, isPrepared: true));
    }
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  // create, setVolume, release, dispose, ... all succeed.
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeGlobal implements GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Backend extends RufletBackend {
  final events = <(String, dynamic)>[];

  _Backend()
      : super(
            pageUri: Uri.parse('ruflet://audio-test'),
            assetsDir: '',
            extensions: [],
            multiView: false);

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    if (control.get("on_$eventName") == true) {
      events.add((eventName, data));
    }
  }
}

void main() {
  late _FakePlayers players;

  setUp(() {
    players = _FakePlayers();
    AudioplayersPlatformInterface.instance = players;
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobal();
  });

  Future<_Backend> run(WidgetTester tester, Map<String, dynamic> props) async {
    final backend = _Backend();
    final control = Control.fromMap({
      '_c': 'Audio',
      '_i': 1,
      'on_loaded': true,
      'on_error': true,
      ...props,
    }, backend);
    final service = AudioService(control: control);
    service.init();
    await tester.pump();
    service.dispose();
    await tester.pump();
    return backend;
  }

  testWidgets('loads Ruby src_base64 as bytes', (tester) async {
    final backend = await run(tester, {'src_base64': 'AAEC'});
    expect(players.loadedBytes, [
      [0, 1, 2]
    ]);
    expect(backend.events, [('loaded', null)]);
  });

  testWidgets('prefers src over src_base64', (tester) async {
    await run(tester, {
      'src': base64Encode([9]),
      'src_base64': 'AAEC'
    });
    expect(players.loadedBytes, [
      [9]
    ]);
  });

  testWidgets('fires error instead of throwing when there is no source',
      (tester) async {
    final backend = await run(tester, {});
    expect(players.loadedBytes, isEmpty);
    expect(backend.events,
        [('error', 'Audio must have "src" or "src_base64" specified.')]);
  });

  testWidgets('fires one error event when the player fails to load',
      (tester) async {
    players.loadError =
        PlatformException(code: 'AudioError', message: 'cannot decode');
    final backend = await run(tester, {
      'src_base64': base64Encode([1, 2, 3])
    });
    expect(players.loadedBytes, [
      [1, 2, 3]
    ]);
    expect(backend.events, hasLength(1));
    expect(backend.events.single.$1, 'error');
    expect(backend.events.single.$2, contains('cannot decode'));
  });
}
