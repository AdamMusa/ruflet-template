import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  void Function(Control, String, dynamic)? onEvent;
  _Backend()
      : super(
            pageUri: Uri.parse('inprocess://test'),
            assetsDir: '',
            extensions: [],
            multiView: false,
            controlId: 50) {
    isLoading = false;
  }
  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) =>
      onEvent?.call(control, name, data);
  @override
  void triggerControlEventById(int id, String name, [dynamic data]) {}
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        '$platform theme radio updates mounted pages without navigation',
        (tester) async {
      final backend = _Backend();
      var nextId = 100;
      final views = [
        for (final route in ['/', '/gallery', '/settings'])
          Control.fromMap({
            '_c': 'View',
            '_i': nextId++,
            'route': route,
            'controls': [
              {
                '_c': 'Text',
                '_i': nextId++,
                'value': 'Theme $route',
                'color': 'onsurface'
              },
              {'_c': 'Text', '_i': nextId++, 'value': 'Default $route'},
              {
                '_c': 'Text',
                '_i': nextId++,
                'value': 'Fixed $route',
                'color': '#123456'
              },
              if (route == '/settings')
                {
                  '_c': 'RadioGroup',
                  '_i': nextId++,
                  'value': 'light',
                  'content': {
                    '_c': 'Column',
                    '_i': nextId++,
                    'controls': [
                      {
                        '_c': 'Radio',
                        '_i': nextId++,
                        'value': 'light',
                        'label': 'Light'
                      },
                      {
                        '_c': 'Radio',
                        '_i': nextId++,
                        'value': 'dark',
                        'label': 'Dark'
                      },
                    ]
                  },
                },
            ],
          }, backend, parent: backend.page)
      ];
      backend.page.update(
          {'platform': platform.name, 'theme_mode': 'light', 'views': views},
          shouldNotify: true);
      backend.onEvent = (_, name, data) {
        if (name == 'change') {
          // This is the page update requested by the Ruby change handler.
          backend.page.update({'theme_mode': data}, shouldNotify: true);
        }
      };
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend, child: ControlWidget(control: backend.page)));
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text('Dark')));
      Color? color(String label) => tester
          .widget<Text>(find.text(label, skipOffstage: false))
          .style
          ?.color;
      final before = [
        for (final route in ['/', '/gallery', '/settings'])
          color('Theme $route')
      ];
      Color? renderedColor(String label) => tester
          .renderObject<RenderParagraph>(find.text(label, skipOffstage: false))
          .text
          .style
          ?.color;
      final defaultBefore = [
        for (final path in ['/', '/gallery', '/settings'])
          renderedColor('Default $path')
      ];
      final radioBefore = renderedColor('Dark');
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(backend.page.get('theme_mode'), 'dark');
      expect(ModalRoute.of(tester.element(find.text('Dark'))), same(route));
      for (final (index, path) in ['/', '/gallery', '/settings'].indexed) {
        expect(color('Theme $path'), isNot(before[index]));
        expect(color('Fixed $path'), const Color(0xff123456));
      }
      // Material pauses native theme animations on offstage routes. The
      // currently visible settings page must update without leaving it.
      expect(renderedColor('Default /settings'), isNot(defaultBefore.last));
      expect(renderedColor('Dark'), isNot(radioBefore));
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      for (final (index, path) in ['/', '/gallery', '/settings'].indexed) {
        expect(color('Theme $path'), before[index]);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform updates theme and view in place on the same route',
        (tester) async {
      final backend = _Backend();
      var nextId = 100;
      Control view(String text) => Control.fromMap({
            '_c': 'View',
            '_i': nextId++,
            'route': '/settings',
            'controls': [
              {'_c': 'Text', '_i': nextId++, 'value': text}
            ],
          }, backend, parent: backend.page);
      backend.page.update({
        'platform': platform.name,
        'theme_mode': 'light',
        'views': [view('Light palette')]
      }, shouldNotify: true);
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend, child: ControlWidget(control: backend.page)));
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text('Light palette')));
      backend.page.update({
        'theme_mode': 'dark',
        'views': [view('Dark palette')]
      }, shouldNotify: true);
      await tester.pumpAndSettle();
      expect(find.text('Dark palette'), findsOneWidget);
      final context = tester.element(find.text('Dark palette'));
      expect(ModalRoute.of(context), same(route));
      expect(
          platform == TargetPlatform.iOS
              ? CupertinoTheme.of(context).brightness
              : material.Theme.of(context).brightness,
          Brightness.dark);
      backend.page.update({'theme_mode': 'system'}, shouldNotify: true);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(backend.platformBrightness, Brightness.dark);
      expect(
          platform == TargetPlatform.iOS
              ? CupertinoTheme.of(context).brightness
              : material.Theme.of(context).brightness,
          Brightness.dark);
      expect(ModalRoute.of(context), same(route));
      expect(tester.takeException(), isNull);
    });
  }
}
