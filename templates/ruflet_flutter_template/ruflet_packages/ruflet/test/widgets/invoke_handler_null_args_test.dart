import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/protocol/message.dart';
import 'package:ruflet/src/ruflet_core_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target,
      {super.tester, super.channelBuilder})
      : super(
            pageUri: Uri.parse('ruflet://invoke-null-args'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
    isLoading = false;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}

  @override
  void triggerControlEventById(int id, String name, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

const _timeout = Duration(seconds: 2);

/// Ruby's Page#invoke sends `args: nil` when a method has no arguments;
/// a hand-built payload may also omit every key.
const _payloads = <Object?>[null, <String, dynamic>{}];

Map<String, dynamic> _text(int id, [String value = 'Content']) =>
    {'_c': 'Text', '_i': id, 'value': value};

/// One mounted control and the invoke methods its renderer(s) handle.
class _ControlCase {
  final String type;
  final Map<String, dynamic> props;
  final List<String> methods;

  /// Methods only the Material renderer handles.
  final List<String> materialOnly;

  const _ControlCase(this.type, this.props, this.methods,
      {this.materialOnly = const []});
}

final _controlCases = <_ControlCase>[
  const _ControlCase('TextField', {'value': 'x'}, ['focus']),
  const _ControlCase('TextField', {'value': 'x', 'shift_enter': true}, ['focus']),
  const _ControlCase('Button', {'content': 'Go'}, ['focus']),
  const _ControlCase('IconButton', {'icon': 71571}, ['focus']),
  const _ControlCase(
      'Dropdown',
      {
        'editable': true,
        'options': [
          {'_c': 'DropdownOption', '_i': 901, 'key': 'a', 'text': 'A'}
        ],
      },
      ['focus']),
  const _ControlCase('SearchBar', {'value': 'q'}, ['focus'],
      materialOnly: ['open_view', 'close_view']),
  _ControlCase('KeyboardListener', {'content': _text(902)}, ['focus']),
  _ControlCase(
      'Tabs',
      {
        'length': 2,
        'content': {
          '_c': 'Column',
          '_i': 903,
          'controls': [
            {
              '_c': 'TabBar',
              '_i': 904,
              'tabs': [
                {'_c': 'Tab', '_i': 905, 'label': _text(906, 'One')},
                {'_c': 'Tab', '_i': 907, 'label': _text(908, 'Two')},
              ],
            },
            {
              '_c': 'TabBarView',
              '_i': 909,
              'height': 80,
              'controls': [_text(910, 'First'), _text(911, 'Second')],
            },
          ],
        },
      },
      ['move_to']),
  _ControlCase(
      'PageView',
      {
        'height': 120,
        'animation_duration': 10,
        'controls': [_text(912, 'P1'), _text(913, 'P2')],
      },
      ['go_to_page', 'jump_to_page', 'jump_to', 'next_page', 'previous_page']),
  const _ControlCase('Canvas', {'height': 50, 'width': 50},
      ['capture', 'get_capture', 'clear_capture']),
  _ControlCase(
      'Column',
      {
        'scroll': 'auto',
        'height': 60,
        'controls': [for (var i = 0; i < 6; i++) _text(920 + i, 'Row $i')],
      },
      ['scroll_to']),
  _ControlCase('InteractiveViewer', {'content': _text(930)},
      ['zoom', 'pan', 'reset', 'save_state', 'restore_state']),
  _ControlCase('Dismissible', {'content': _text(931)}, ['confirm_dismiss']),
  _ControlCase('ContextMenu', {
    'content': _text(932),
    'actions': [
      {'_c': 'ContextMenuAction', '_i': 933, 'content': _text(934, 'Copy')}
    ],
  }, [], materialOnly: [
    'open'
  ]),
];

/// Service methods whose argument is genuinely required: a missing value
/// must reach Ruby as an error naming the method and the argument, never as
/// a silent success.
const _requiredArgs = <String, Map<String, String>>{
  'Clipboard': {'set': 'data', 'set_image': 'data', 'set_files': 'files'},
  // The test platform is Android, where save_file needs the bytes.
  'FilePicker': {'save_file': 'src_bytes'},
  'ScreenBrightness': {
    'set_system_screen_brightness': 'value',
    'set_application_screen_brightness': 'value',
    'set_animate': 'value',
    'set_auto_reset': 'value',
  },
  'SemanticsService': {
    'announce_message': 'message',
    'announce_tooltip': 'message',
  },
  'Share': {'share_text': 'text', 'share_uri': 'uri', 'share_files': 'files'},
  'SharedPreferences': {
    'set': 'key',
    'get': 'key',
    'contains_key': 'key',
    'remove': 'key',
  },
  'Tester': {
    'find_by_text': 'text',
    'find_by_text_containing': 'pattern',
    'find_by_key': 'key',
    'find_by_tooltip': 'value',
    'find_by_icon': 'icon',
    'take_screenshot': 'name',
    'tap': 'finder_id',
    'tap_at': 'offset',
    'long_press': 'finder_id',
    'enter_text': 'finder_id',
    'mouse_hover': 'finder_id',
  },
  'UrlLauncher': {
    'launch_url': 'url',
    'can_launch_url': 'url',
    'open_window': 'url',
  },
  // Window registers its listener on desktop only.
};

/// A harness that is never reached: every call below fails argument checks
/// first, or only uses the no-argument paths.
class _FakeTester implements Tester {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// A transport that records what the backend sends back to Ruby.
class _RecordingChannel implements RufletBackendChannel {
  final RufletBackendChannelOnMessageCallback onMessage;
  final sent = <Message>[];

  _RecordingChannel(this.onMessage);

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

Control _service(_Backend backend, String type, int id) {
  final control = Control.fromMap({'_c': type, '_i': id}, backend);
  RufletCoreExtension().createService(control)!.init();
  return control;
}

Future<Object?> _serviceError(
    Control control, String method, Object? args) async {
  Object? error;
  await control
      .invokeMethod(method, args, _timeout)
      .then((_) {}, onError: (Object e) {
    error = e;
  });
  return error;
}

/// Invokes [method] like the backend does and pumps until it completes;
/// returns the error the handler threw, if any.
Future<Object?> _invoke(WidgetTester tester, Control control, String method,
    Object? args) async {
  Object? error;
  final call = control
      .invokeMethod(method, args, _timeout)
      .catchError((Object e) => error = e);
  await tester.pumpAndSettle();
  await call;
  return error;
}

void main() {
  testWidgets('Control.invokeMethod always hands listeners a map',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final control =
        Control(id: 1, type: 'Probe', properties: {}, backend: backend);
    final received = <dynamic>[];
    control.addInvokeMethodListener((name, args) async => received.add(args));

    await control.invokeMethod('probe', null, _timeout);
    await control.invokeMethod('probe', 'not a map', _timeout);
    await control.invokeMethod('probe', {'index': 1}, _timeout);

    expect(received[0], isA<Map>().having((m) => m.isEmpty, 'isEmpty', true));
    expect(received[1], isA<Map>().having((m) => m.isEmpty, 'isEmpty', true));
    expect(received[2], {'index': 1});
    expect(invokeArgs(null), isEmpty);
    expect(skipInvoke('Probe.probe', 'index'), isNull);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final cupertino = platform == TargetPlatform.iOS;

    for (final testCase in _controlCases) {
      final methods = [
        ...testCase.methods,
        if (!cupertino) ...testCase.materialOnly,
      ];
      if (methods.isEmpty) continue;
      final label = '${testCase.type}'
          '${testCase.props.containsKey('shift_enter') ? ' (shift_enter)' : ''}';

      testWidgets('$platform $label tolerates nil and empty invoke args',
          (tester) async {
        final backend = _Backend(platform);
        final control = Control.fromMap(
            {'_c': testCase.type, '_i': 800, ...testCase.props}, backend);
        final body = Center(
          child: SizedBox(
              width: 360,
              height: 320,
              child: Column(children: [ControlWidget(control: control)])),
        );
        await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: cupertino
              ? CupertinoApp(home: CupertinoPageScaffold(child: body))
              : material.MaterialApp(home: material.Scaffold(body: body)),
        ));

        for (final args in _payloads) {
          for (final method in methods) {
            expect(await _invoke(tester, control, method, args), isNull,
                reason: '${testCase.type}.$method($args)');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform Page and View tolerate nil and empty invoke args',
        (tester) async {
      // set_allowed_device_orientations awaits a SystemChrome platform call.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final backend = _Backend(platform);
      final view = Control.fromMap({
        '_c': 'View',
        '_i': 700,
        'route': '/',
        'controls': [_text(701, 'Home')],
      }, backend, parent: backend.page);
      backend.page.update({
        'platform': platform.name,
        'views': [view]
      }, shouldNotify: true);
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend, child: ControlWidget(control: backend.page)));
      await tester.pumpAndSettle();

      for (final args in _payloads) {
        // Optional: all orientations, and "keep the view".
        expect(
            await _invoke(
                tester, backend.page, 'set_allowed_device_orientations', args),
            isNull,
            reason: 'Page.set_allowed_device_orientations($args)');
        expect(await _invoke(tester, view, 'confirm_pop', args), isNull,
            reason: 'View.confirm_pop($args)');
        // Required: a route.
        expect(
            await _invoke(tester, backend.page, 'push_route', args),
            isA<ArgumentError>().having((e) => e.message, 'message',
                'Page.push_route requires a "route" argument'),
            reason: 'Page.push_route($args)');
      }
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in _requiredArgs.entries) {
    testWidgets('${entry.key} rejects missing required args with a clear error',
        (tester) async {
      final backend = _Backend(TargetPlatform.android, tester: _FakeTester());
      final control = _service(backend, entry.key, 600);

      for (final args in _payloads) {
        for (final method in entry.value.keys) {
          final argument = entry.value[method]!;
          expect(
              await _serviceError(control, method, args),
              isA<ArgumentError>().having((e) => e.message, 'message',
                  '${entry.key}.$method requires a "$argument" argument'),
              reason: '${entry.key}.$method($args)');
        }
      }
    });
  }

  testWidgets('required values and malformed args are rejected too',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final prefs = _service(backend, 'SharedPreferences', 601);
    final clipboard = _service(backend, 'Clipboard', 602);
    final share = _service(backend, 'Share', 603);
    final urls = _service(backend, 'UrlLauncher', 604);

    String? message(Object? error) => (error as ArgumentError?)?.message;
    expect(message(await _serviceError(prefs, 'set', {'key': 'k'})),
        'SharedPreferences.set requires a "value" argument');
    expect(message(await _serviceError(clipboard, 'set_files', {'files': 'a'})),
        'Clipboard.set_files requires "files" to be a list');
    expect(message(await _serviceError(share, 'share_files', {'files': []})),
        'Share.share_files requires at least one file');
    expect(message(await _serviceError(urls, 'launch_url', {'url': 5})),
        'UrlLauncher.launch_url requires "url" to be a string');
  });

  testWidgets('optional args fall back to their defaults', (tester) async {
    SharedPreferences.setMockInitialValues({'a': '1', 'b': '2'});
    final backend = _Backend(TargetPlatform.android, tester: _FakeTester());
    final prefs = _service(backend, 'SharedPreferences', 610);
    final filePicker = _service(backend, 'FilePicker', 611);
    final harness = _service(backend, 'Tester', 612);

    for (final args in _payloads) {
      // No prefix lists every key.
      expect(
          await prefs.invokeMethod('get_keys', args, _timeout), ['a', 'b']);
      // Nothing to upload is not an error.
      expect(await filePicker.invokeMethod('upload', args, _timeout), isNull);
      for (final method in ['pump', 'pump_and_settle', 'teardown']) {
        expect(await _serviceError(harness, method, args), isNull,
            reason: 'Tester.$method($args)');
      }
    }
  });

  testWidgets('Tester without a harness fails instead of passing silently',
      (tester) async {
    final control = _service(_Backend(TargetPlatform.android), 'Tester', 620);
    for (final method in ['pump', 'find_by_text', 'tap', 'teardown']) {
      expect(
          await _serviceError(control, method, {'text': 'x', 'finder_id': 1}),
          isA<StateError>().having((e) => e.message, 'message',
              'Tester.$method requires a running test harness'));
    }
  });

  testWidgets('Ruby receives an error reply for a missing required arg',
      (tester) async {
    SharedPreferences.setMockInitialValues({'a': '1'});
    late _RecordingChannel channel;
    final backend = _Backend(TargetPlatform.android,
        channelBuilder: (
                {required address,
                required args,
                required forcePyodide,
                required onDisconnect,
                required onMessage}) =>
            channel = _RecordingChannel(onMessage));
    await backend.connect();
    _service(backend, 'SharedPreferences', 630);
    final pager = Control.fromMap({
      '_c': 'PageView',
      '_i': 631,
      'height': 100,
      'controls': [_text(632, 'P1'), _text(633, 'P2')],
    }, backend);
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: material.MaterialApp(
            home: material.Scaffold(body: ControlWidget(control: pager)))));

    Future<Map> reply(int controlId, String name, Object? args) async {
      channel.sent.clear();
      channel.onMessage(Message(
          action: MessageAction.invokeControlMethod,
          payload: {
            'control_id': controlId,
            'call_id': 'call_$name',
            'name': name,
            'args': args,
          }));
      await tester.pumpAndSettle();
      final message = channel.sent.singleWhere(
          (m) => m.action == MessageAction.invokeControlMethod);
      return message.payload as Map;
    }

    // Required and missing: an error Ruby raises, never a silent nil.
    final missing = await reply(630, 'set', null);
    expect(missing['call_id'], 'call_set');
    expect(missing['result'], isNull);
    expect(missing['error'],
        contains('SharedPreferences.set requires a "key" argument'));

    // Optional and missing: the default, with no error.
    final keys = await reply(630, 'get_keys', null);
    expect(keys['error'], isNull);
    expect(keys['result'], ['a']);

    // A control method called without args (Page#invoke sends nil).
    final paged = await reply(631, 'next_page', null);
    expect(paged['error'], isNull);
    expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
  });
}
