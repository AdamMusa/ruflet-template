// Client actions (a control's `action`, Flet's ClientAction): the client
// performs the service call itself inside the tap, before it sends `click`
// to Ruby, and reports each outcome as `action_result`. Checked on both
// designs for the controls on the shared core (Button, IconButton, ListTile)
// and the legacy renderers (Container, FloatingActionButton, TextSpan), with
// the platform channels mocked.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' as material show ListTile;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart' show Control, ControlWidget;
import 'package:ruflet/src/services/client_action.dart';
import 'package:ruflet/src/services/service_registry.dart';
import 'package:ruflet/src/widgets/ruflet_cupertino_list_tile.dart';

import '../support/control_harness.dart';

const _copy = {
  'service': 'Clipboard',
  'method': 'set',
  'args': {'data': 'token'},
};

const _open = {
  'service': 'UrlLauncher',
  'method': 'launch_url',
  'args': {'url': 'https://ruflet.dev', 'web_only_window_name': '_blank'},
};

const _pick = {
  'service': 'FilePicker',
  'method': 'pick_files',
  'args': {'file_type': 'any', 'allow_multiple': true, 'with_data': false},
};

const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// The events the control sent to Ruby so far, by name.
List<String> _events(HarnessMount mount) =>
    [for (final m in mount.backend.sent) m.name];

/// Mocks the clipboard, url_launcher and share channels and logs each
/// platform call with the events Ruby had received when it was made.
class _Platform {
  _Platform(this.tester, this.mount) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        calls.add('copy ${(call.arguments as Map)['text']} '
            'after ${_events(mount)}');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(_urlChannel, (call) async {
      final args = call.arguments as Map;
      calls.add('${call.method} ${args['url']} after ${_events(mount)}');
      return true;
    });
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      final args = call.arguments as Map;
      calls.add('share ${args['text']}');
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(_urlChannel, null);
      messenger.setMockMethodCallHandler(_shareChannel, null);
    });
  }

  final WidgetTester tester;
  final HarnessMount mount;
  final calls = <String>[];
}

/// A file picker that "picks" one file without a dialog.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.onPick);

  final void Function(Map<String, Object?> options) onPick;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    onPick({'type': type.name, 'allow_multiple': allowMultiple});
    return FilePickerResult(
        [PlatformFile(name: 'a.txt', path: '/tmp/a.txt', size: 3)]);
  }
}

Map<String, dynamic> _column(Map<String, dynamic> control) => {
      '_c': 'Column',
      '_i': 10,
      'controls': [control],
    };

Finder _controlFinder(int id) => find.byWidgetPredicate(
    (widget) => widget is ControlWidget && widget.control.id == id);

/// One clickable control of the action family, and how a user taps it.
class _Case {
  const _Case(this.name, this.wire, this.tap);
  final String name;
  final Map<String, dynamic> Function(Map<String, Object?> extra) wire;
  final Finder Function() tap;
}

final _cases = [
  _Case(
      'Button',
      (extra) =>
          _column({'_c': 'Button', '_i': 11, 'content': 'Press', ...extra}),
      () => find.text('Press')),
  _Case(
      'FilledTonalButton (cupertino_tinted_button)',
      (extra) => _column(
          {'_c': 'FilledTonalButton', '_i': 11, 'content': 'Press', ...extra}),
      () => find.text('Press')),
  _Case(
      'IconButton',
      (extra) =>
          _column({'_c': 'IconButton', '_i': 11, 'icon': 0x10000, ...extra}),
      () => _controlFinder(11)),
  _Case(
      'OutlinedIconButton',
      (extra) => _column(
          {'_c': 'OutlinedIconButton', '_i': 11, 'icon': 0x10000, ...extra}),
      () => _controlFinder(11)),
  _Case(
      'ListTile',
      (extra) =>
          _column({'_c': 'ListTile', '_i': 11, 'title': 'Tile', ...extra}),
      () => find.text('Tile')),
  _Case(
      'Container',
      (extra) => _column({
            '_c': 'Container',
            '_i': 11,
            'width': 120.0,
            'height': 40.0,
            'content': {'_c': 'Text', '_i': 12, 'value': 'Box'},
            ...extra,
          }),
      () => find.text('Box')),
  _Case(
      'Container (ink)',
      (extra) => _column({
            '_c': 'Container',
            '_i': 11,
            'ink': true,
            'width': 120.0,
            'height': 40.0,
            'content': {'_c': 'Text', '_i': 12, 'value': 'Box'},
            ...extra,
          }),
      () => find.text('Box')),
  _Case(
      'FloatingActionButton',
      (extra) => _column(
          {'_c': 'FloatingActionButton', '_i': 11, 'content': 'Add', ...extra}),
      () => find.text('Add')),
  _Case(
      'TextSpan',
      (extra) => _column({
            '_c': 'Text',
            '_i': 12,
            'spans': [
              {'_c': 'TextSpan', '_i': 11, 'text': 'link', ...extra},
            ],
          }),
      () => _controlFinder(12)),
];

void main() {
  test('parses one action or a list, skipping malformed entries', () {
    expect(parseClientActions(null), isEmpty);
    expect(parseClientActions('sample'), isEmpty);
    expect(parseClientActions(_copy).single.toString(),
        'ClientAction(Clipboard.set {data: token})');
    expect(
        parseClientActions([
          _copy,
          {'service': 1, 'method': 'set'},
          'junk',
          _open,
        ]).map((a) => '${a.service}.${a.method}'),
        ['Clipboard.set', 'UrlLauncher.launch_url']);
  });

  for (final design in HarnessDesign.values) {
    group('${design.name}:', () {
      for (final c in _cases) {
        testWidgets(
            '${c.name} copies inside the tap, then sends click and the result',
            (tester) async {
          final mount = await mountWire(
              tester,
              design,
              c.wire({
                'action': _copy,
                'on_click': true,
                'on_action_result': true,
              }));
          final platform = _Platform(tester, mount);

          await tester.tap(c.tap());
          await tester.pumpAndSettle();

          // The copy reached the platform before Ruby heard of the click.
          expect(platform.calls, ['copy token after []']);
          expect(_events(mount), ['click', 'action_result']);
          expect(mount.backend.sent.last.data, {
            'index': 0,
            'service': 'Clipboard',
            'method': 'set',
            'result': null,
          });
        });

        testWidgets('${c.name} with only an action is tappable',
            (tester) async {
          final mount =
              await mountWire(tester, design, c.wire({'action': _copy}));
          final platform = _Platform(tester, mount);

          await tester.tap(c.tap());
          await tester.pumpAndSettle();

          expect(platform.calls, ['copy token after []']);
          expect(_events(mount), isEmpty, reason: 'nothing subscribed');
        });
      }

      testWidgets('a list of actions all start before click, in order',
          (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _column({
              '_c': 'Button',
              '_i': 11,
              'content': 'Press',
              'action': [_copy, _open],
              'on_click': true,
              'on_action_result': true,
            }));
        final platform = _Platform(tester, mount);

        await tester.tap(find.text('Press'));
        await tester.pumpAndSettle();

        expect(platform.calls, [
          'copy token after []',
          'launch https://ruflet.dev after []',
        ]);
        expect(_events(mount), ['click', 'action_result', 'action_result']);
        expect(
            mount.backend.sent
                .where((m) => m.name == 'action_result')
                .map((m) => (m.data as Map)['index']),
            [0, 1]);
      });

      testWidgets('a ListTile is tappable for a real action only',
          (tester) async {
        Object? onTap() {
          final tile = design == HarnessDesign.ios
              ? find.byType(RufletCupertinoListTile)
              : find.byType(material.ListTile);
          final widget = tester.widget(tile);
          return widget is material.ListTile
              ? widget.onTap
              : (widget as RufletCupertinoListTile).onTap;
        }

        for (final (action, tappable) in [
          (<String, Object?>{}, false),
          ('sample', false),
          (_copy, true),
        ]) {
          await mountWire(
              tester,
              design,
              _column({
                '_c': 'ListTile',
                '_i': 11,
                'title': 'Tile',
                'action': action,
              }));
          expect(onTap() != null, tappable, reason: '$action');
        }
      });

      testWidgets('a disabled control performs no action', (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _column({
              '_c': 'IconButton',
              '_i': 11,
              'icon': 0x10000,
              'disabled': true,
              'action': _copy,
              'on_click': true,
              'on_action_result': true,
            }));
        final platform = _Platform(tester, mount);

        await tester.tap(_controlFinder(11), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(platform.calls, isEmpty);
        expect(_events(mount), isEmpty);
      });

      testWidgets('a failing action reports its error', (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _column({
              '_c': 'ListTile',
              '_i': 11,
              'title': 'Tile',
              'action': {'service': 'Clipboard', 'method': 'get'},
              'on_action_result': true,
            }));

        await tester.tap(find.text('Tile'));
        await tester.pumpAndSettle();

        final result = mount.backend.sent.single;
        expect(result.name, 'action_result');
        expect((result.data as Map)['error'],
            contains('Clipboard.get is not a client action'));
      });

      testWidgets('share_text reports the share status', (tester) async {
        final mount = await mountWire(
            tester,
            design,
            _column({
              '_c': 'TextButton',
              '_i': 11,
              'content': 'Share',
              'action': {
                'service': 'Share',
                'method': 'share_text',
                'args': {'text': 'hello'},
              },
              'on_action_result': true,
            }));
        final platform = _Platform(tester, mount);

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();

        expect(platform.calls, ['share hello']);
        expect(mount.backend.sent.single.data, {
          'index': 0,
          'service': 'Share',
          'method': 'share_text',
          'result': {
            'status': 'unavailable',
            'raw': 'dev.fluttercommunity.plus/share/unavailable',
          },
        });
      });

      testWidgets('pick_files returns the picked files to Ruby',
          (tester) async {
        final log = <String>[];
        late HarnessMount mount;
        FilePicker.platform = _FakeFilePicker(
            (options) => log.add('pick $options after ${_events(mount)}'));
        mount = await mountWire(
            tester,
            design,
            _column({
              '_c': 'Button',
              '_i': 11,
              'content': 'Upload',
              'action': _pick,
              'on_click': true,
              'on_action_result': true,
            }));

        await tester.tap(find.text('Upload'));
        await tester.pumpAndSettle();

        expect(log, ['pick {type: any, allow_multiple: true} after []']);
        expect(_events(mount), ['click', 'action_result']);
        expect(mount.backend.sent.last.data, {
          'index': 0,
          'service': 'FilePicker',
          'method': 'pick_files',
          'result': [
            {
              'id': 0,
              'name': 'a.txt',
              'path': '/tmp/a.txt',
              'size': 3,
              'bytes': null,
            },
          ],
        });
      });

      testWidgets(
          'pick_files goes through the page FilePicker, which keeps the '
          'files for upload', (tester) async {
        FilePicker.platform = _FakeFilePicker((_) {});
        final mount = await mountWire(
            tester,
            design,
            _column({
              '_c': 'Button',
              '_i': 11,
              'content': 'Upload',
              'action': _pick,
              'on_action_result': true,
            }));
        final registry = Control.fromMap({
          '_c': 'ServiceRegistry',
          '_i': 50,
          '_services': [
            {'_c': 'FilePicker', '_i': 51, 'on_upload': true},
          ],
        }, mount.backend, parent: mount.backend.page);
        mount.backend.page.properties['_services'] = registry;
        final services = ServiceRegistry(
            control: registry,
            propertyName: '_services',
            backend: mount.backend);
        addTearDown(services.dispose);
        final picker = mount.control(51);

        await tester.tap(find.text('Upload'));
        await tester.pumpAndSettle();
        expect(_events(mount), ['action_result']);

        // The page's FilePicker kept the selection: uploading file 0 finds
        // it (and fails, the fake file having no stream to read).
        await tester.runAsync(() => picker.invokeMethod(
            'upload',
            {
              'files': [
                {
                  'id': 0,
                  'name': 'a.txt',
                  'upload_url': 'http://127.0.0.1:9/upload',
                  'method': 'PUT',
                },
              ],
            },
            const Duration(seconds: 1)));
        await tester.pumpAndSettle();
        final upload = mount.backend.sent.last;
        expect(upload.id, 51);
        expect(upload.name, 'upload');
        expect((upload.data as Map)['file_name'], 'a.txt');
        expect((upload.data as Map)['error'], contains('null stream'));
      });
    });
  }
}
