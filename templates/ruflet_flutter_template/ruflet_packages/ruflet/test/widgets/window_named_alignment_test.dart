// A desktop `page.window.alignment` given as a named string such as "center"
// (AdamMusa/ruflet-engine#118). Ruby sends the value as the app wrote it. The
// Window service reads every window prop before it applies any, so a string
// that the alignment parser could not read used to drop the whole update:
// title, size and position never reached the platform.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/services/service_binding.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://window-named-alignment'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}
}

const _windowChannel = MethodChannel('window_manager');
const _screenChannel = MethodChannel('dev.leanflutter.plugins/screen_retriever');

/// One 1440x900 display at the origin.
const _display = {
  'id': '1',
  'size': {'width': 1440.0, 'height': 900.0},
  'visiblePosition': {'dx': 0.0, 'dy': 0.0},
  'visibleSize': {'width': 1440.0, 'height': 900.0},
};

/// Mounts Page{title, window{alignment, width: 500, height: 400}} on a
/// desktop [target] and returns the window_manager set* calls with their
/// arguments, plus every debugPrint line.
Future<(List<String>, List<String>)> _run(
    WidgetTester tester, TargetPlatform target, Object alignment) async {
  debugDefaultTargetPlatformOverride = target;
  final calls = <String>[];
  final logs = <String>[];
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => logs.add('$message');
  var bounds = {'x': 0.0, 'y': 0.0, 'width': 800.0, 'height': 600.0};
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_windowChannel, (call) async {
    switch (call.method) {
      case 'getBounds':
        return bounds;
      case 'getOpacity':
        return 1.0;
      case 'setTitle':
        calls.add('setTitle ${(call.arguments as Map)['title']}');
        return null;
      case 'setBounds':
        final args = Map<String, dynamic>.from(call.arguments as Map)
          ..remove('devicePixelRatio')
          ..remove('animate');
        bounds = {
          for (final key in bounds.keys)
            key: (args[key] as num?)?.toDouble() ?? bounds[key]!,
        };
        final shown = (args.keys.toList()..sort())
            .map((key) => '$key=${(args[key] as num).round()}')
            .join(' ');
        calls.add('setBounds $shown');
        return null;
    }
    if (call.method.startsWith('set')) calls.add(call.method);
    if (call.method.startsWith('is')) return false;
    return null;
  });
  messenger.setMockMethodCallHandler(_screenChannel, (call) async {
    switch (call.method) {
      case 'getPrimaryDisplay':
        return _display;
      case 'getAllDisplays':
        return {
          'displays': [_display]
        };
      case 'getCursorScreenPoint':
        return {'dx': 10.0, 'dy': 10.0};
    }
    return null;
  });
  try {
    final backend = _Backend(target);
    final page = Control.fromMap({
      '_c': 'Page',
      '_i': 1,
      'title': 'Named alignment',
      'window': {
        '_c': 'Window',
        '_i': 2,
        'alignment': alignment,
        'width': 500,
        'height': 400,
      },
    }, backend);
    final binding =
        ServiceBinding(control: page.child('window')!, backend: backend);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    binding.dispose();
  } finally {
    messenger.setMockMethodCallHandler(_windowChannel, null);
    messenger.setMockMethodCallHandler(_screenChannel, null);
    debugPrint = previousDebugPrint;
    debugDefaultTargetPlatformOverride = null;
  }
  return (calls, logs);
}

void main() {
  for (final target in [TargetPlatform.macOS, TargetPlatform.windows]) {
    // Each named value and the {x, y} map that means the same alignment
    // apply the same window update: the title, the 500x400 size, the
    // position on the 1440x900 display, then the title bar style the service
    // applies after the alignment.
    final cases = <String, (List<Object>, String)>{
      'center': (['center', {'x': 0, 'y': 0}], 'setBounds x=470 y=250'),
      'bottom_right': (
        ['bottom_right', 'bottomRight', {'x': 1, 'y': 1}],
        'setBounds x=940 y=500'
      ),
    };
    for (final MapEntry(key: name, value: (values, position))
        in cases.entries) {
      for (final alignment in values) {
        testWidgets(
            '${target.name} window alignment $alignment applies the whole '
            'window update ($name)', (tester) async {
          final (calls, logs) = await _run(tester, target, alignment);
          expect(calls, [
            'setTitle Named alignment',
            'setBounds height=400 width=500',
            position,
            'setTitleBarStyle',
          ]);
          expect(logs.where((line) => line.contains('Error updating window')),
              isEmpty);
        });
      }
    }
  }
}
