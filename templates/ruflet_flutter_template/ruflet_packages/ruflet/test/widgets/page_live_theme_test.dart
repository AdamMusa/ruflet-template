import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
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
  void triggerControlEvent(Control control, String name, [dynamic data]) {}
  @override
  void triggerControlEventById(int id, String name, [dynamic data]) {}
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
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
