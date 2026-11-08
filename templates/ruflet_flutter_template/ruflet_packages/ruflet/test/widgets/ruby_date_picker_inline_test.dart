// The inline date picker is selected by Ruby's declared `inline` property
// (cupertino_date_picker sends inline: true on the canonical DatePicker wire
// type), never by a Cupertino wire name.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

Future<Control> _pump(WidgetTester tester, TargetPlatform platform, String wire,
    Map<String, dynamic> props) async {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://inline'),
      assetsDir: '',
      extensions: [],
      multiView: false)
    ..platform = platform;
  final control = Control.fromMap({
    '_c': wire,
    '_i': 2100,
    'value': '2026-10-29T00:00:00.000',
    ...props,
  }, backend);
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: Center(child: ControlWidget(control: control)))
        : material.MaterialApp(
            home: material.Scaffold(
                body: Center(child: ControlWidget(control: control)))),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return control;
}

void main() {
  testWidgets('iOS renders the picker in place for inline: true',
      (tester) async {
    await _pump(tester, TargetPlatform.iOS, 'DatePicker', {'inline': true});
    final picker = find.byType(CupertinoDatePicker);
    expect(picker, findsOneWidget);
    expect(find.byType(CupertinoPopupSurface), findsNothing);
    // In place: the wheels have a real size in the page.
    expect(tester.getSize(picker).height, greaterThan(100));
  });

  testWidgets('iOS presents a dialog when not inline', (tester) async {
    await _pump(tester, TargetPlatform.iOS, 'DatePicker', {'open': true});
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(CupertinoPopupSurface), findsOneWidget);
  });

  testWidgets('the legacy CupertinoDatePicker wire name implies inline',
      (tester) async {
    final control =
        await _pump(tester, TargetPlatform.iOS, 'CupertinoDatePicker', {});
    expect(control.get('inline'), isTrue);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(CupertinoPopupSurface), findsNothing);
  });

  testWidgets('Material renders the calendar in place for inline: true',
      (tester) async {
    await _pump(tester, TargetPlatform.android, 'DatePicker', {'inline': true});
    expect(find.byType(material.CalendarDatePicker), findsOneWidget);
    expect(find.byType(material.Dialog), findsNothing);
  });

  // Ruby's cupertino_date_picker always sends its mode (date_and_time by
  // default), in snake_case, on the canonical DatePicker wire type.
  for (final (mode, expected) in [
    ('date_and_time', CupertinoDatePickerMode.dateAndTime),
    ('time', CupertinoDatePickerMode.time),
    ('date', CupertinoDatePickerMode.date),
  ]) {
    testWidgets('iOS inline picker honors date_picker_mode $mode',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, 'DatePicker',
          {'inline': true, 'date_picker_mode': mode});
      expect(
          tester
              .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
              .mode,
          expected);
    });
  }
}
