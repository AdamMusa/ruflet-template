import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/app_bar_core.dart';
import 'package:ruflet/src/controls/cupertino_app_bar.dart';

Future<CupertinoNavigationBar> _pumpBar(
  WidgetTester tester,
  Map<String, dynamic> props,
) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://cupertino-app-bar-keys-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = TargetPlatform.iOS;
  // Ruflet.cupertino_app_bar sends WIRE "AppBar".
  final control = Control.fromMap({
    '_c': 'AppBar',
    '_i': 1,
    'title': 'Inbox',
    ...props,
  }, backend);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: CupertinoAppBarSkin(core: AppBarCore(control)),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return tester.widget<CupertinoNavigationBar>(
    find.byType(CupertinoNavigationBar),
  );
}

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'Cupertino AppBar honors Ruby enable_background_filter_blur (large=$large)',
      (tester) async {
        final bar = await _pumpBar(tester, {
          'large': large,
          'enable_background_filter_blur': false,
        });
        expect(bar.enableBackgroundFilterBlur, isFalse);
      },
    );

    testWidgets(
      'Cupertino AppBar keeps background blur on by default (large=$large)',
      (tester) async {
        final bar = await _pumpBar(tester, {'large': large});
        expect(bar.enableBackgroundFilterBlur, isTrue);
      },
    );
  }
}
