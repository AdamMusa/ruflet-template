// ruflet-coverage: AudioRecorder
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_audio_recorder/ruflet_audio_recorder.dart';

import 'support/service_harness.dart';

/// Dart fake of the record platform, so no platform channel is used.
class _FakeRecord extends RecordPlatform {
  final calls = <String>[];
  final created = <String>[];
  final disposed = <String>[];
  bool permission = true;
  bool recording = false;
  bool paused = true;
  bool encoderSupported = true;
  String? stoppedPath = '/data/voice.wav';
  List<InputDevice> devices = const [
    InputDevice(id: 'builtin', label: 'iPhone Microphone'),
    InputDevice(id: 'usb-1', label: 'USB Audio'),
  ];
  Object? error;

  RecordConfig? startConfig;
  String? startPath;
  AudioEncoder? queriedEncoder;
  final states = <String, StreamController<RecordState>>{};

  Future<T> _answer<T>(String call, T value) async {
    calls.add(call);
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<void> create(String recorderId) async => created.add(recorderId);

  @override
  Future<void> dispose(String recorderId) async => disposed.add(recorderId);

  @override
  Future<void> start(String recorderId, RecordConfig config,
      {required String path}) {
    startConfig = config;
    startPath = path;
    return _answer('start', null);
  }

  @override
  Future<Stream<Uint8List>> startStream(
          String recorderId, RecordConfig config) =>
      _answer('startStream', const Stream<Uint8List>.empty());

  @override
  Future<String?> stop(String recorderId) => _answer('stop', stoppedPath);

  @override
  Future<void> cancel(String recorderId) => _answer('cancel', null);

  @override
  Future<void> pause(String recorderId) => _answer('pause', null);

  @override
  Future<void> resume(String recorderId) => _answer('resume', null);

  @override
  Future<bool> isRecording(String recorderId) =>
      _answer('isRecording', recording);

  @override
  Future<bool> isPaused(String recorderId) => _answer('isPaused', paused);

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) =>
      _answer('hasPermission', permission);

  @override
  Future<Amplitude> getAmplitude(String recorderId) =>
      _answer('getAmplitude', Amplitude(current: -20, max: -5));

  @override
  Future<bool> isEncoderSupported(String recorderId, AudioEncoder encoder) {
    queriedEncoder = encoder;
    return _answer('isEncoderSupported', encoderSupported);
  }

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) =>
      _answer('listInputDevices', devices);

  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      (states[recorderId] = StreamController<RecordState>()).stream;
}

const _designs = [TargetPlatform.iOS, TargetPlatform.android];

void main() {
  late _FakeRecord platform;
  final mounted = <MountedService>[];

  setUp(() {
    platform = _FakeRecord();
    RecordPlatform.instance = platform;
  });

  tearDown(() {
    for (final service in mounted) {
      service.dispose();
    }
    mounted.clear();
    resetTargetPlatform();
  });

  Future<MountedService> recorder(
      {Map<String, dynamic> props = const {},
      TargetPlatform platform = TargetPlatform.android}) async {
    final service = mountService(
        Extension(), {'_c': 'AudioRecorder', 'configuration': {}, ...props},
        platform: platform);
    mounted.add(service);
    // Let the recorder register with the platform and subscribe to states.
    await pumpEventQueue();
    return service;
  }

  test('the extension creates the service for its wire type only', () {
    final backend = RecordingBackend(Extension(), TargetPlatform.android);
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(Extension().createService(control('AudioRecorder')), isNotNull);
    expect(Extension().createService(control('Audio')), isNull);
  });

  for (final design in _designs) {
    group('on ${design.name}', () {
      test('one platform recorder per service, released on dispose', () async {
        final service = await recorder(platform: design);
        expect(platform.created, hasLength(1));
        expect(platform.states.keys, platform.created);

        mounted.remove(service);
        service.dispose();
        await pumpEventQueue();
        expect(platform.disposed, platform.created);
        expect(platform.states.values.single.hasListener, isFalse);
      });

      test('query methods return the platform answers', () async {
        final service = await recorder(platform: design);

        expect(await service.invoke('has_permission'), isTrue);
        expect(await service.invoke('is_recording'), isFalse);
        expect(await service.invoke('is_paused'), isTrue);
        expect(await service.invoke('get_input_devices'), {
          'builtin': 'iPhone Microphone',
          'usb-1': 'USB Audio',
        });
        expect(platform.calls, [
          'hasPermission',
          'isRecording',
          'isPaused',
          'listInputDevices',
        ]);

        platform.permission = false;
        platform.recording = true;
        platform.paused = false;
        platform.devices = const [];
        expect(await service.invoke('has_permission'), isFalse);
        expect(await service.invoke('is_recording'), isTrue);
        expect(await service.invoke('is_paused'), isFalse);
        expect(await service.invoke('get_input_devices'), isEmpty);
      });

      test('control methods reach the platform; stop returns the path',
          () async {
        final service = await recorder(platform: design);

        expect(await service.invoke('pause_recording'), isNull);
        expect(await service.invoke('resume_recording'), isNull);
        expect(await service.invoke('stop_recording'), '/data/voice.wav');
        expect(await service.invoke('cancel_recording'), isNull);
        expect(platform.calls, ['pause', 'resume', 'stop', 'cancel']);

        platform.stoppedPath = null;
        expect(await service.invoke('stop_recording'), isNull);
      });

      test('is_supported_encoder asks about the encoder Ruby named', () async {
        final service = await recorder(platform: design);

        expect(
            await service.invoke('is_supported_encoder', {'encoder': 'opus'}),
            isTrue);
        expect(platform.queriedEncoder, AudioEncoder.opus);

        platform.encoderSupported = false;
        expect(
            await service.invoke('is_supported_encoder', {'encoder': 'aac_lc'}),
            isFalse);
        expect(platform.queriedEncoder, AudioEncoder.aacLc);
      });

      test('is_supported_encoder without a known encoder is an error',
          () async {
        final service = await recorder(platform: design);

        for (final args in [null, <String, dynamic>{}]) {
          expect(
              await service.invokeError('is_supported_encoder', args),
              isA<ArgumentError>().having((e) => e.message, 'message',
                  'AudioRecorder.is_supported_encoder requires an "encoder" argument'),
              reason: '$args');
        }
        expect(
            await service
                .invokeError('is_supported_encoder', {'encoder': 'mp3'}),
            isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'AudioRecorder.is_supported_encoder: unknown encoder "mp3", '
                    'expected one of aac_lc, aac_eld, aac_he, amr_nb, amr_wb, '
                    'opus, flac, wav, pcm16bits'));
        expect(platform.calls, isEmpty);
      });

      test('start_recording hands Ruby\'s configuration to the platform',
          () async {
        final service = await recorder(platform: design);

        final started = await service.invoke('start_recording', {
          'output_path': '/data/memo.m4a',
          'configuration': {
            'encoder': 'aac_lc',
            'bit_rate': 64000,
            'sample_rate': 22050,
            'channels': 1,
            'auto_gain': true,
            'cancel_echo': true,
            'suppress_noise': true,
            'device': {'id': 'usb-1', 'label': 'USB Audio'},
            'android_configuration': {
              'audio_source': 'voice_recognition',
              'manage_bluetooth': false,
              'mute_audio': true,
              'use_legacy': true,
            },
            'ios_configuration': {
              'manage_audio_session': false,
              'options': ['mix_with_others', 'allow_bluetooth_a2dp'],
            },
          },
        });

        expect(started, isTrue);
        expect(platform.calls, ['hasPermission', 'start']);
        expect(platform.startPath, '/data/memo.m4a');
        final config = platform.startConfig!;
        expect(config.encoder, AudioEncoder.aacLc);
        expect(config.bitRate, 64000);
        expect(config.sampleRate, 22050);
        expect(config.numChannels, 1);
        expect(config.autoGain, isTrue);
        expect(config.echoCancel, isTrue);
        expect(config.noiseSuppress, isTrue);
        expect(config.device!.id, 'usb-1');
        expect(config.device!.label, 'USB Audio');
        expect(config.androidConfig.audioSource,
            AndroidAudioSource.voiceRecognition);
        expect(config.androidConfig.manageBluetooth, isFalse);
        expect(config.androidConfig.muteAudio, isTrue);
        expect(config.androidConfig.useLegacy, isTrue);
        // ignore: deprecated_member_use
        expect(config.iosConfig.manageAudioSession, isFalse);
        expect(config.iosConfig.categoryOptions, [
          IosAudioCategoryOption.mixWithOthers,
          IosAudioCategoryOption.allowBluetoothA2DP,
        ]);
      });

      test('Ruby\'s default configuration {} records WAV with the defaults',
          () async {
        final service = await recorder(platform: design);

        expect(
            await service.invoke('start_recording',
                {'output_path': '/data/memo.wav', 'configuration': {}}),
            isTrue);

        final config = platform.startConfig!;
        expect(config.encoder, AudioEncoder.wav);
        expect(config.bitRate, 128000);
        expect(config.sampleRate, 44100);
        expect(config.numChannels, 2);
        expect(config.autoGain, isFalse);
        expect(config.echoCancel, isFalse);
        expect(config.noiseSuppress, isFalse);
        expect(config.device, isNull);
        const android = AndroidRecordConfig();
        expect(config.androidConfig.audioSource, android.audioSource);
        expect(config.androidConfig.manageBluetooth, android.manageBluetooth);
        expect(config.androidConfig.muteAudio, android.muteAudio);
        expect(config.androidConfig.useLegacy, android.useLegacy);
        expect(config.iosConfig.categoryOptions,
            const IosRecordConfig().categoryOptions);
      });

      test('ios_configuration without options keeps the default categories',
          () async {
        final service = await recorder(platform: design);

        for (final ios in <Map<String, dynamic>>[
          {'manage_audio_session': false},
          {},
        ]) {
          expect(
              await service.invoke('start_recording', {
                'output_path': '/data/memo.wav',
                'configuration': {'ios_configuration': ios},
              }),
              isTrue,
              reason: '$ios');
          final config = platform.startConfig!.iosConfig;
          expect(
              config.categoryOptions, const IosRecordConfig().categoryOptions);
          // ignore: deprecated_member_use
          expect(config.manageAudioSession, ios.isEmpty);
        }
      });

      test('ios_configuration options must be a list of option names',
          () async {
        final service = await recorder(platform: design);

        // Unknown names and nil entries are dropped, as before.
        expect(
            await service.invoke('start_recording', {
              'output_path': '/data/memo.wav',
              'configuration': {
                'ios_configuration': {
                  'options': [null, 'default_to_speaker', 'not_an_option'],
                },
              },
            }),
            isTrue);
        expect(platform.startConfig!.iosConfig.categoryOptions,
            [IosAudioCategoryOption.defaultToSpeaker]);

        // Anything else fails the invoke, as it did before, instead of
        // recording with options Ruby did not ask for.
        platform.calls.clear();
        for (final (options, shown) in [
          ('default_to_speaker', '"default_to_speaker"'),
          (
            <String, dynamic>{'default_to_speaker': true},
            '{default_to_speaker: true}'
          ),
          (1, '1'),
          ([1, 'default_to_speaker'], '[1, default_to_speaker]'),
        ]) {
          expect(
              await service.invokeError('start_recording', {
                'output_path': '/data/memo.wav',
                'configuration': {
                  'ios_configuration': {'options': options},
                },
              }),
              isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  'AudioRecorder.start_recording: "options" in '
                      '"ios_configuration" must be a list of category option '
                      'names, got $shown'),
              reason: '$options');
        }
        expect(platform.calls, isNot(contains('start')));
      });

      test('device is an id from get_input_devices, or a map with an id',
          () async {
        final service = await recorder(platform: design);
        final devices = await service.invoke('get_input_devices') as Map;

        for (final (device, id, label) in [
          (devices.keys.last, 'usb-1', ''),
          ({'id': 'usb-1'}, 'usb-1', ''),
          ({'id': 'builtin', 'label': 'Mic'}, 'builtin', 'Mic'),
          (7, '7', ''),
          ({'id': 7}, '7', ''),
          // A map with a text id and label is passed on as before, whatever
          // the id; record then picks the input that has it.
          ({'id': '', 'label': 'Mic'}, '', 'Mic'),
        ]) {
          expect(
              await service.invoke('start_recording', {
                'output_path': '/data/memo.wav',
                'configuration': {'device': device},
              }),
              isTrue,
              reason: '$device');
          expect(platform.startConfig!.device!.id, id, reason: '$device');
          expect(platform.startConfig!.device!.label, label, reason: '$device');
        }

        // A device that names no id fails the invoke, as it did before ids
        // were accepted, instead of recording from the default input.
        platform.calls.clear();
        for (final (device, shown) in [
          (<String, dynamic>{}, '{}'),
          ({'label': 'Mic'}, '{label: Mic}'),
          ({'id': ''}, '{id: }'),
          ({'id': ' '}, '{id:  }'),
          ('', '""'),
          (' ', '" "'),
          (['usb-1'], '[usb-1]'),
        ]) {
          expect(
              await service.invokeError('start_recording', {
                'output_path': '/data/memo.wav',
                'configuration': {'device': device},
              }),
              isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  'AudioRecorder.start_recording: "device" must be a device '
                      'id from get_input_devices or a map with an "id", got '
                      '$shown'),
              reason: '$device');
        }
        expect(platform.calls, isNot(contains('start')));
      });

      test('start_recording without permission or a path does not start',
          () async {
        final service = await recorder(platform: design);

        platform.permission = false;
        expect(
            await service.invoke('start_recording',
                {'output_path': '/data/memo.wav', 'configuration': {}}),
            isFalse);

        platform.permission = true;
        for (final args in [
          {'configuration': {}},
          {'output_path': '', 'configuration': {}},
        ]) {
          expect(await service.invoke('start_recording', args), isFalse,
              reason: '$args');
        }
        expect(platform.calls, isNot(contains('start')));
      });

      test('platform errors are the invoke error', () async {
        final service = await recorder(platform: design);
        platform.error =
            PlatformException(code: 'record', message: 'Microphone is in use');

        for (final method in [
          'stop_recording',
          'pause_recording',
          'has_permission',
          'get_input_devices',
        ]) {
          expect(
              await service.invokeError(method),
              isA<PlatformException>()
                  .having((e) => e.message, 'message', 'Microphone is in use'),
              reason: method);
        }
      });

      test('an unknown method fails fast without reaching the platform',
          () async {
        final service = await recorder(platform: design);

        expect((await service.invokeError('get_amplitude')).toString(),
            'Exception: Unknown AudioRecorder method: get_amplitude');
        expect(platform.calls, isEmpty);
      });
    });
  }

  test('every encoder, Android source and iOS option parses from snake_case',
      () async {
    final service = await recorder();
    Future<RecordConfig> start(Map<String, dynamic> configuration) async {
      await service.invoke('start_recording',
          {'output_path': '/data/x', 'configuration': configuration});
      return platform.startConfig!;
    }

    for (final (encoder, name) in [
      (AudioEncoder.aacLc, 'aac_lc'),
      (AudioEncoder.aacEld, 'aac_eld'),
      (AudioEncoder.aacHe, 'aac_he'),
      (AudioEncoder.amrNb, 'amr_nb'),
      (AudioEncoder.amrWb, 'amr_wb'),
      (AudioEncoder.opus, 'opus'),
      (AudioEncoder.flac, 'flac'),
      (AudioEncoder.wav, 'wav'),
      (AudioEncoder.pcm16bits, 'pcm16bits'),
      (AudioEncoder.aacLc, 'aacLc'),
    ]) {
      expect((await start({'encoder': name})).encoder, encoder, reason: name);
    }
    for (final (source, name) in [
      (AndroidAudioSource.defaultSource, 'default_source'),
      (AndroidAudioSource.mic, 'mic'),
      (AndroidAudioSource.voiceUplink, 'voice_uplink'),
      (AndroidAudioSource.voiceDownlink, 'voice_downlink'),
      (AndroidAudioSource.voiceCall, 'voice_call'),
      (AndroidAudioSource.camcorder, 'camcorder'),
      (AndroidAudioSource.voiceRecognition, 'voice_recognition'),
      (AndroidAudioSource.voiceCommunication, 'voice_communication'),
      (AndroidAudioSource.remoteSubMix, 'remote_sub_mix'),
      (AndroidAudioSource.unprocessed, 'unprocessed'),
      (AndroidAudioSource.voicePerformance, 'voice_performance'),
    ]) {
      final config = await start({
        'android_configuration': {'audio_source': name}
      });
      expect(config.androidConfig.audioSource, source, reason: name);
    }
    final options = await start({
      'ios_configuration': {
        'options': [
          'mix_with_others',
          'duck_others',
          'allow_bluetooth',
          'default_to_speaker',
          'interrupt_spoken_audio_and_mix_with_others',
          'allow_bluetooth_a2dp',
          'allow_air_play',
          'override_muted_microphone_interruption',
          'not_an_option',
        ]
      }
    });
    expect(options.iosConfig.categoryOptions, IosAudioCategoryOption.values);
  });

  group('state_change', () {
    for (final design in _designs) {
      test('on ${design.name} recorder states reach Ruby when it subscribed',
          () async {
        final service =
            await recorder(platform: design, props: {'on_state_change': true});
        final states = platform.states.values.single;

        states
          ..add(RecordState.record)
          ..add(RecordState.pause)
          ..add(RecordState.record)
          ..add(RecordState.stop);
        await pumpEventQueue();

        expect(service.backend.events.map((e) => (e.id, e.name, e.data)), [
          (1, 'state_change', 'recording'),
          (1, 'state_change', 'paused'),
          (1, 'state_change', 'recording'),
          (1, 'state_change', 'stopped'),
        ]);
      });
    }

    test('without on_state_change no state reaches Ruby', () async {
      final service = await recorder();
      platform.states.values.single.add(RecordState.record);
      await pumpEventQueue();
      expect(service.backend.events, isEmpty);

      service.patch({'on_state_change': true});
      platform.states.values.single.add(RecordState.stop);
      await pumpEventQueue();
      expect(service.backend.events.single.data, 'stopped');
    });
  });
}
