import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final explicit in [false, true]) {
      testWidgets(
          'FAB uses Ruby theme or explicit colors ($brightness, $explicit)',
          (tester) async {
        final backend = RufletBackend(
            pageUri: Uri.parse('inprocess://color-test'),
            assetsDir: '',
            extensions: [],
            multiView: false)
          ..platform = TargetPlatform.iOS;
        final control = Control.fromMap({
          '_c': 'FloatingActionButton',
          '_i': 9,
          'icon': 71571,
          'content': 'Open',
          if (explicit) 'bgcolor': '#123456',
          if (explicit) 'foreground_color': '#abcdef',
        }, backend);
        const brand = Color(0xff6750a4);
        const contrast = Color(0xffeeeeee);
        await tester.pumpWidget(ChangeNotifierProvider.value(
            value: backend,
            child: CupertinoApp(
                theme: CupertinoThemeData(
                    brightness: brightness,
                    primaryColor: brand,
                    primaryContrastingColor: contrast),
                home: Center(child: ControlWidget(control: control)))));
        final native =
            tester.widget<CupertinoButton>(find.byType(CupertinoButton));
        final foreground = explicit ? const Color(0xffabcdef) : contrast;
        expect(native.color, explicit ? const Color(0xff123456) : brand);
        expect(native.foregroundColor, foreground);
        expect(
            IconTheme.of(tester.element(find.byType(Icon))).color, foreground);
        expect(
            DefaultTextStyle.of(tester.element(find.text('Open'))).style.color,
            foreground);
        control.update({'disabled': true}, shouldNotify: true);
        await tester.pump();
        final disabled =
            tester.widget<CupertinoButton>(find.byType(CupertinoButton));
        expect(disabled.onPressed, isNull);
        expect(disabled.foregroundColor, explicit ? foreground : isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
