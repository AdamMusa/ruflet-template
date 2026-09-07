import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://date-test'),
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
  void triggerControlEvent(Control control, String name, [dynamic data]) {}
}

void main() {
  test('date attributes accept Ruby ISO strings and decoded wire dates', () {
    final control = Control.fromMap(
        {'_c': 'DatePicker', '_i': 1}, _Backend(TargetPlatform.iOS));
    final cases = <dynamic, DateTime>{
      '2026-05-21': DateTime(2026, 5, 21),
      '2026-05-21T13:45:00': DateTime(2026, 5, 21, 13, 45),
      '2026-05-21T13:45:00Z': DateTime.utc(2026, 5, 21, 13, 45).toLocal(),
      '2026-05-21T13:45:00+02:00': DateTime.utc(2026, 5, 21, 11, 45).toLocal(),
      DateTime.utc(2026, 5, 21): DateTime.utc(2026, 5, 21).toLocal(),
    };
    for (final entry in cases.entries) {
      control.updateProperties({'value': entry.key}, python: false);
      expect(control.getDateTime('value'), entry.value);
    }
    expect(control.getDateTime('missing'), isNull);
    expect(control.getDateTime('missing', DateTime(2026)), DateTime(2026));
    control.updateProperties({'value': 'not-a-date'}, python: false);
    expect(() => control.getDateTime('value'), throwsFormatException);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final type in [
      'DatePicker',
      'DateRangePicker',
      'CupertinoDatePicker'
    ]) {
      testWidgets('$platform $type preserves Ruby dates and bounds',
          (tester) async {
        final backend = _Backend(platform);
        final control = Control.fromMap({
          '_c': type,
          '_i': 1,
          'open': true,
          'value': '2026-05-21',
          'start_value': '2026-05-01',
          'end_value': '2026-05-21',
          'first_date': '2026-01-01',
          'last_date': '2026-12-31',
          'date_picker_mode': 'date',
        }, backend);
        final child = Center(
            child:
                SizedBox(height: 400, child: ControlWidget(control: control)));
        await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: platform == TargetPlatform.iOS
              ? CupertinoApp(home: child)
              : material.MaterialApp(home: material.Material(child: child)),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsNothing);
        if (platform == TargetPlatform.iOS) {
          final pickers = tester
              .widgetList<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
              .toList();
          expect(pickers, hasLength(type == 'DateRangePicker' ? 2 : 1));
          expect(pickers.first.initialDateTime,
              DateTime(2026, 5, type == 'DateRangePicker' ? 1 : 21));
          if (pickers.length == 2) {
            expect(pickers.last.initialDateTime, DateTime(2026, 5, 21));
          }
          for (final picker in pickers) {
            expect(picker.minimumDate, DateTime(2026, 1, 1));
            expect(picker.maximumDate, DateTime(2026, 12, 31));
          }
        } else if (type == 'DateRangePicker') {
          final picker = tester.widget<material.DateRangePickerDialog>(
              find.byType(material.DateRangePickerDialog));
          expect(picker.initialDateRange!.start, DateTime(2026, 5, 1));
          expect(picker.initialDateRange!.end, DateTime(2026, 5, 21));
          expect(picker.firstDate, DateTime(2026, 1, 1));
          expect(picker.lastDate, DateTime(2026, 12, 31));
        } else {
          final picker = tester.widget<material.CalendarDatePicker>(
              find.byType(material.CalendarDatePicker));
          expect(picker.initialDate, DateTime(2026, 5, 21));
          expect(picker.firstDate, DateTime(2026, 1, 1));
          expect(picker.lastDate, DateTime(2026, 12, 31));
        }
      });
    }
  }
}
