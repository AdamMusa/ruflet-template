// A DatePicker the page presents (page.show_dialog / page.open /
// page.dialog =, all of which host it in the page's `_dialogs` layer) is a
// modal picker on both designs, whatever its `inline` property says. Ruby's
// cupertino_date_picker sends inline: true by default, and before this rule
// page.show_dialog(cupertino_date_picker(...)) drew the wheels in place over
// the page instead of popping up, the way it did in v0.0.23.
//
// Inline pickers laid out in a view, or used as a bottom sheet's content,
// keep rendering in place.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/material_date_picker.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';

class _Backend extends RufletBackend {
  final events = <String>[];

  _Backend(PageDesign design)
      : super(
            pageUri: Uri.parse('inprocess://date-picker-dialog'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    isLoading = false;
    platform = design == PageDesign.cupertino
        ? TargetPlatform.iOS
        : TargetPlatform.android;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) =>
      events.add(name);
}

// The DatePicker exactly as Ruby sends it for
// page.show_dialog(cupertino_date_picker(value: ..., on_change: ...)).
Map<String, dynamic> _rubyCupertinoDatePicker(int id,
        {Map<String, dynamic> extra = const {}}) =>
    {
      '_c': 'DatePicker',
      '_i': id,
      'date_picker_mode': 'date_and_time',
      'inline': true,
      'item_extent': 32.0,
      'minimum_year': 1,
      'minute_interval': 1,
      'show_day_of_week': false,
      'use_24h_format': false,
      'value': '2026-05-15T09:30:00',
      'on_change': true,
      ...extra,
    };

Future<_Backend> _pumpPage(
  WidgetTester tester,
  PageDesign design, {
  List<Map<String, dynamic>> controls = const [],
  List<Map<String, dynamic>> dialogs = const [],
}) async {
  final backend = _Backend(design);
  final view = Control.fromMap({
    '_c': 'View',
    '_i': 10,
    'route': '/',
    'controls': [
      {'_c': 'Text', '_i': 11, 'value': 'Page body'},
      ...controls,
    ],
  }, backend, parent: backend.page);
  backend.page.update({
    'views': [view],
    '_overlay': {'_c': 'Overlay', '_i': 12, 'controls': []},
    '_dialogs': {'_c': 'Dialogs', '_i': 13, 'controls': dialogs},
  }, shouldNotify: false);

  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: PlatformApp(
      design: design,
      config: PlatformAppConfig(
        title: 'test',
        showSemanticsDebugger: false,
        themeMode: RufletThemeMode.light,
        routerDelegate: null,
        routeInformationParser: null,
        routeInformationProvider: null,
        localizationsDelegates: const [],
        supportedLocales: const [Locale('en')],
        locale: const Locale('en'),
        home: PageContext(
          widgetsDesign: design,
          themeMode: RufletThemeMode.light,
          brightness: Brightness.light,
          child: ControlWidget(control: view),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return backend;
}

// Mirrors Ruby's page.show_dialog: the Dialogs container's controls are
// replaced with the presented controls.
Future<void> _showDialogs(WidgetTester tester, _Backend backend,
    List<Map<String, dynamic>> dialogs) async {
  backend.page
      .child('_dialogs')!
      .update({'controls': dialogs}, shouldNotify: true);
  await tester.pumpAndSettle();
}

// Mirrors Ruby's page.close_dialog: `open` is patched on the control itself.
Future<void> _patchOpen(WidgetTester tester, _Backend backend, int id,
    {required bool open}) async {
  backend.controlsIndex
      .get(id)!
      .updateProperties({'open': open}, python: false, notify: true);
  await tester.pumpAndSettle();
}

Finder _modalPicker(PageDesign design) => design == PageDesign.cupertino
    ? find.descendant(
        of: find.byType(CupertinoPopupSurface),
        matching: find.byType(CupertinoDatePicker))
    : find.byType(material.DatePickerDialog);

// Pickers drawn in place: on iOS, wheels outside a popup surface.
Finder _inlinePicker(PageDesign design) => design == PageDesign.cupertino
    ? find.byElementPredicate((element) =>
        element.widget is CupertinoDatePicker &&
        element.findAncestorWidgetOfExactType<CupertinoPopupSurface>() == null)
    : find.byType(MaterialInlineDatePickerControl);

void main() {
  for (final design in [PageDesign.cupertino, PageDesign.material]) {
    group('$design', () {
      testWidgets(
          'show_dialog(cupertino_date_picker) presents a modal picker, '
          'and close_dialog leaves nothing over the page', (tester) async {
        final backend = await _pumpPage(tester, design);
        await _showDialogs(tester, backend, [
          _rubyCupertinoDatePicker(20, extra: {'open': true})
        ]);

        expect(_modalPicker(design), findsOneWidget);
        expect(_inlinePicker(design), findsNothing);
        expect(tester.takeException(), isNull);

        await _patchOpen(tester, backend, 20, open: false);
        expect(_inlinePicker(design), findsNothing);
        if (design == PageDesign.cupertino) {
          // The iOS popup pops on open: false. The Material DatePicker
          // dialog has no programmatic close (date_picker neither, in
          // v0.0.23 too), so only the inline calendar is checked there.
          expect(_modalPicker(design), findsNothing);
          expect(find.byType(CupertinoDatePicker), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('cancelling the presented inline picker closes it',
          (tester) async {
        final backend = await _pumpPage(tester, design);
        await _showDialogs(tester, backend, [
          _rubyCupertinoDatePicker(20, extra: {'open': true})
        ]);
        expect(_modalPicker(design), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(_modalPicker(design), findsNothing);
        expect(backend.controlsIndex.get(20)!.get('open'), isFalse);
        expect(
            backend.events
                .where((name) => name == 'dismiss' || name == 'change'),
            ['dismiss']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a closed presented picker draws nothing over the page',
          (tester) async {
        final backend = await _pumpPage(tester, design, dialogs: [
          _rubyCupertinoDatePicker(20, extra: {'open': false})
        ]);
        expect(_modalPicker(design), findsNothing);
        expect(_inlinePicker(design), findsNothing);

        await _patchOpen(tester, backend, 20, open: true);
        expect(_modalPicker(design), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the documented date_picker + show_dialog is unchanged',
          (tester) async {
        final backend = await _pumpPage(tester, design);
        await _showDialogs(tester, backend, [
          {
            '_c': 'DatePicker',
            '_i': 20,
            'value': '2026-01-15',
            'first_date': '2026-01-01',
            'last_date': '2026-12-31',
            'on_change': true,
            'open': true,
          }
        ]);
        expect(_modalPicker(design), findsOneWidget);
        expect(_inlinePicker(design), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an inline picker laid out in the view stays in place',
          (tester) async {
        // The wheels fill their box, so a laid-out picker is given a height
        // (cupertino_date_picker(height: 216)).
        await _pumpPage(tester, design, controls: [
          _rubyCupertinoDatePicker(20, extra: {'height': 216})
        ]);
        expect(_inlinePicker(design), findsOneWidget);
        expect(_modalPicker(design), findsNothing);
        expect(find.byType(CupertinoPopupSurface), findsNothing);
        expect(find.byType(material.Dialog), findsNothing);
      });

      testWidgets(
          'a picker laid out and shown with show_dialog under one wire id: '
          'the view copy stays in place, the Dialogs copy is modal',
          (tester) async {
        // Ruby sends a picker that is laid out (in a view, or captured by a
        // DSL block) and then shown with page.show_dialog in both places
        // under one wire id, as v0.0.23 did. Each place gets its own control.
        final backend = await _pumpPage(tester, design, controls: [
          _rubyCupertinoDatePicker(20, extra: {'height': 216})
        ]);
        expect(_inlinePicker(design), findsOneWidget);

        await _showDialogs(tester, backend, [
          _rubyCupertinoDatePicker(20, extra: {'height': 216, 'open': true})
        ]);
        expect(_modalPicker(design), findsOneWidget);
        expect(_inlinePicker(design), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _patchOpen(tester, backend, 20, open: false);
        expect(_inlinePicker(design), findsOneWidget);
        if (design == PageDesign.cupertino) {
          expect(_modalPicker(design), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('an inline picker as bottom sheet content stays in place',
          (tester) async {
        final backend = await _pumpPage(tester, design);
        await _showDialogs(tester, backend, [
          {
            '_c': 'BottomSheet',
            '_i': 30,
            'open': true,
            'content': _rubyCupertinoDatePicker(20),
          }
        ]);
        expect(_inlinePicker(design), findsOneWidget);
        expect(_modalPicker(design), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
