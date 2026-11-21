// What Ruby receives when it invokes a method on the Page control (wire id
// 1): the reply for every method the Page handles, the immediate error for
// one it does not, and the log line each call writes. These replies are the
// wire contract behind Ruby's page.get_device_info,
// page.set_allowed_device_orientations and invoke(:page, ...).
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/protocol/message.dart';

class _RecordingChannel implements RufletBackendChannel {
  _RecordingChannel(this.onMessage);

  final RufletBackendChannelOnMessageCallback onMessage;
  final sent = <Message>[];

  @override
  Future connect() async {}

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 500;

  @override
  void send(Message message) => sent.add(message);

  @override
  void disconnect() {}
}

class _Backend extends RufletBackend {
  _Backend(TargetPlatform design, {super.channelBuilder})
      : super(
            pageUri: Uri.parse('ruflet://page-invoke-methods'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = design;
    isLoading = false;
  }
}

/// A connected backend with the Page mounted on one View, as in a session.
class _Session {
  _Session(this.backend, this.channel);

  final _Backend backend;
  final _RecordingChannel channel;

  /// Every reply to an invoke since the last [invoke], in the order sent.
  List<Map> get replies => [
        for (final message in channel.sent)
          if (message.action == MessageAction.invokeControlMethod)
            message.payload as Map
      ];

  /// Sends Ruby's invoke_control_method for the Page.
  void invoke(String name, Object? args) {
    channel.sent.clear();
    channel
        .onMessage(Message(action: MessageAction.invokeControlMethod, payload: {
      'control_id': 1,
      'call_id': 'call_$name',
      'name': name,
      'args': args,
      // Ruby's default is 10 s. The tests never advance fake time that
      // far, so a reply proves the Page answered without waiting.
      'timeout': 30,
    }));
  }
}

Future<_Session> _mount(WidgetTester tester, TargetPlatform design,
    {Map<String, dynamic> page = const {}}) async {
  late _RecordingChannel channel;
  final backend = _Backend(design,
      channelBuilder: (
              {required address,
              required args,
              required forcePyodide,
              required onDisconnect,
              required onMessage}) =>
          channel = _RecordingChannel(onMessage));
  await backend.connect();
  final view = Control.fromMap({
    '_c': 'View',
    '_i': 20,
    'route': '/',
    'controls': [
      {'_c': 'Text', '_i': 21, 'value': 'Home'}
    ],
  }, backend, parent: backend.page);
  backend.page.update({
    'platform': design.name,
    ...page,
    'views': [view]
  }, shouldNotify: true);
  // Start from an empty tree so a second mount in one test builds a new
  // Page state for the new backend instead of updating the previous one.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend, child: ControlWidget(control: backend.page)));
  await tester.pumpAndSettle();
  return _Session(backend, channel);
}

/// The single reply to [name], after one frame and no fake time.
Future<Map> _reply(
    WidgetTester tester, _Session session, String name, Object? args) async {
  session.invoke(name, args);
  await tester.pump();
  return session.replies.single;
}

/// Runs [body] and returns what it wrote with debugPrint.
Future<List<String?>> _logs(Future<void> Function() body) async {
  final logs = <String?>[];
  final print = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message);
  try {
    await body();
  } finally {
    debugPrint = print;
  }
  return logs;
}

Map<String, Object?> _answer(String name, {Object? result, String? error}) => {
      'control_id': 1,
      'call_id': 'call_$name',
      'result': result,
      'error': error
    };

LinuxDeviceInfo _linux() => LinuxDeviceInfo(
      name: 'Fedora Linux',
      version: '40 (Workstation Edition)',
      id: 'fedora',
      idLike: const ['rhel'],
      versionCodename: '',
      versionId: '40',
      prettyName: 'Fedora Linux 40 (Workstation Edition)',
      buildId: null,
      variant: 'Workstation Edition',
      variantId: 'workstation',
      machineId: 'abc123',
    );

void main() {
  tearDown(() {
    debugDeviceInfoSource = null;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final design in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${design.name}: an unhandled Page method fails at once',
        (tester) async {
      final session = await _mount(tester, design);

      final logs = await _logs(() async {
        expect(
            await _reply(tester, session, 'no_such_method', null),
            _answer('no_such_method',
                error: 'Exception: Unknown Page method: no_such_method'));
        // Names match exactly.
        expect(
            await _reply(tester, session, 'Push_Route', {'route': '/x'}),
            _answer('Push_Route',
                error: 'Exception: Unknown Page method: Push_Route'));
        expect(await _reply(tester, session, '', null),
            _answer('', error: 'Exception: Unknown Page method: '));
        // Methods that belong to a View, not the Page.
        expect(
            await _reply(tester, session, 'show_drawer', null),
            _answer('show_drawer',
                error: 'Exception: Unknown Page method: show_drawer'));
      });

      expect(logs, contains('Page.no_such_method({})'));
      expect(logs, contains('Page.Push_Route({route: /x})'));
      expect(session.backend.route, isNot('/x'));
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${design.name}: push_route moves the route', (tester) async {
      final session = await _mount(tester, design);

      for (final args in <Object?>[
        null,
        <String, dynamic>{},
        {'route': null}
      ]) {
        expect(
            await _reply(tester, session, 'push_route', args),
            _answer('push_route',
                error: 'Invalid argument(s): Page.push_route requires a '
                    '"route" argument'),
            reason: 'push_route($args)');
      }

      late Map reply;
      final logs = await _logs(() async {
        reply = await _reply(tester, session, 'push_route', {'route': '/next'});
      });
      expect(reply, _answer('push_route'));
      expect(logs, contains('Page.push_route({route: /next})'));
      expect(session.backend.route, '/next');

      // A non-string route is sent as its string form.
      expect(await _reply(tester, session, 'push_route', {'route': 42}),
          _answer('push_route'));
      expect(session.backend.route, '42');
      expect(tester.takeException(), isNull);
    });

    testWidgets('${design.name}: get_device_info answers the record',
        (tester) async {
      debugDeviceInfoSource = () async => _linux();
      final session = await _mount(tester, design);

      for (final args in <Object?>[
        null,
        {'ignored': true}
      ]) {
        final reply = await _reply(tester, session, 'get_device_info', args);
        expect(reply['error'], isNull);
        expect(reply['call_id'], 'call_get_device_info');
        final record = reply['result'] as Map<String, dynamic>;
        expect(record['pretty_name'], 'Fedora Linux 40 (Workstation Edition)');
        expect(record['machine_id'], 'abc123');
        expect(record['locales'], isA<List>());
      }

      debugDeviceInfoSource = () async => throw StateError('no record');
      expect(await _reply(tester, session, 'get_device_info', null),
          _answer('get_device_info', error: 'Bad state: no record'));
    });

    testWidgets('${design.name}: set_allowed_device_orientations replies',
        (tester) async {
      final calls = <Object?>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final session = await _mount(tester, design);
      const name = 'set_allowed_device_orientations';

      expect(
          await _reply(tester, session, name, {
            'orientations': ['portraitUp', 'landscape_left', 'portraitUp']
          }),
          _answer(name));
      expect(await _reply(tester, session, name, {'orientations': []}),
          _answer(name));
      expect(await _reply(tester, session, name, null), _answer(name));
      expect(
          await _reply(tester, session, name, {
            'orientations': ['portraitUp', 'sideways']
          }),
          _answer(name,
              error: 'Invalid argument (orientations): '
                  'Page.set_allowed_device_orientations: unknown orientation: '
                  '"sideways"'));
      expect(calls, [
        ['DeviceOrientation.portraitUp', 'DeviceOrientation.landscapeLeft'],
        <String>[],
        [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.portraitDown',
          'DeviceOrientation.landscapeRight',
        ],
      ]);

      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      late Map unsupported;
      try {
        unsupported = await _reply(tester, session, name, {
          'orientations': ['portraitUp']
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(
          unsupported,
          _answer(name,
              error: 'Unsupported operation: set_allowed_device_orientations '
                  'is only supported on mobile platforms'));
      expect(calls, isEmpty);
    });

    testWidgets('${design.name}: take_screenshot answers PNG bytes',
        (tester) async {
      // Without enable_screenshots there is nothing to capture: no bytes.
      final plain = await _mount(tester, design);
      plain.invoke('take_screenshot', null);
      await tester.pump(const Duration(milliseconds: 20));
      expect(plain.replies.single, _answer('take_screenshot'));

      final session =
          await _mount(tester, design, page: {'enable_screenshots': true});
      await tester.runAsync(() async {
        session.invoke('take_screenshot', {'delay': 0, 'pixel_ratio': 1.0});
        for (var i = 0; i < 100 && session.replies.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });

      final reply = session.replies.single;
      expect(reply['error'], isNull);
      expect(reply['call_id'], 'call_take_screenshot');
      final png = reply['result'] as Uint8List;
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(tester.takeException(), isNull);
    });
  }
}
