import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_input_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <String>[];
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) =>
      events.add(name);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform dialog has one full-screen, unscaled live barrier',
        (tester) async {
      final backend = _Backend(platform);
      final dialog = Control.fromMap({
        '_c': 'AlertDialog',
        '_i': 1,
        'open': true,
        'title': 'Dialog',
        'barrier_color': '#88112233',
      }, backend);
      final child = ControlWidget(control: dialog);
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: platform == TargetPlatform.iOS
            ? CupertinoApp(home: child)
            : material.MaterialApp(home: child),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final barrier = find.byType(AnimatedModalBarrier).last;
      expect(tester.getRect(barrier), const Rect.fromLTWH(0, 0, 800, 600));
      expect(find.ancestor(of: barrier, matching: find.byType(ScaleTransition)),
          findsNothing);
      await tester.pumpAndSettle();
      dialog.updateProperties({'barrier_color': '#99123456'},
          python: false, notify: true);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedModalBarrier>(barrier).color.value,
          const Color(0x99123456));
      expect(find.text('Dialog'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(dialog.get('open'), isFalse);
      expect(backend.events.where((name) => name == 'dismiss'), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('range picker is presented once inside its owning navigator',
      (tester) async {
    final backend = _Backend(TargetPlatform.iOS);
    final control = Control.fromMap({
      '_c': 'DateRangePicker',
      '_i': 1,
      'open': true,
      'start_value': DateTime(2026, 9, 7),
      'end_value': DateTime(2026, 9, 9),
    }, backend);
    final inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: CupertinoApp(
          home: Navigator(
        key: inner,
        onGenerateRoute: (_) => CupertinoPageRoute<void>(
            builder: (_) => CupertinoDateRangePickerControl(control: control)),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNWidgets(2));
    expect(Navigator.of(tester.element(find.text('Select dates'))),
        same(inner.currentState));
    expect(tester.getRect(find.byType(AnimatedModalBarrier).last),
        const Rect.fromLTWH(0, 0, 800, 600));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsNothing);
    expect(control.get('open'), isFalse);
    expect(backend.events.where((name) => name == 'dismiss'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
