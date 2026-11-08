import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/widgets/control_route.dart';
import 'package:ruflet/src/widgets/cupertino_license_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;

class _Backend extends RufletBackend {
  final events = <String>[];

  /// `"<control id>:<event>"`, to tell which control was dismissed.
  final controlEvents = <String>[];
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://about-dialog-test'),
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
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    events.add(name);
    controlEvents.add('${control.id}:$name');
  }
}

const _package = 'ruflet_test_package';

class _TestLicense extends LicenseEntry {
  const _TestLicense();

  @override
  Iterable<String> get packages => const [_package];

  @override
  Iterable<LicenseParagraph> get paragraphs => const [
        LicenseParagraph('TEST LICENSE', LicenseParagraph.centeredIndent),
        LicenseParagraph('Ruflet test license.', 0),
        LicenseParagraph('Indented clause of the license.', 1),
      ];
}

Control _about(_Backend backend, [Map<String, dynamic> props = const {}]) =>
    Control.fromMap({
      '_c': 'AboutDialog',
      '_i': 1,
      'open': true,
      'application_name': 'Rides',
      'application_version': '1.4.0',
      'application_legalese': '© 2026 Rides Inc.',
      'application_icon': {'_c': 'Text', '_i': 2, 'value': 'ICON'},
      'controls': [
        {'_c': 'Text', '_i': 3, 'value': 'Made with Ruflet'}
      ],
      ...props,
    }, backend);

/// Another control's dialog, mounted next to the AboutDialog.
Control _otherDialog(_Backend backend) => Control.fromMap({
      '_c': 'AlertDialog',
      '_i': 20,
      'open': false,
      'title': 'Other dialog',
    }, backend);

Future<void> _show(WidgetTester tester, _Backend backend, Control about,
    {String title = 'Ruflet App', List<Control> others = const []}) async {
  final child = Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
    ControlWidget(control: about),
    for (final other in others) ControlWidget(control: other),
  ]));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(title: title, home: CupertinoPageScaffold(child: child))
        : material.MaterialApp(
            title: title, home: material.Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

void _expectCupertinoOnly(WidgetTester tester) {
  expect(find.byWidgetPredicate(materialOnly), findsNothing);
  expect(find.byType(material.AboutDialog), findsNothing);
  expect(find.byType(material.LicensePage), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() {
    LicenseRegistry.addLicense(() => Stream.value(const _TestLicense()));
  });

  group('iOS AboutDialog', () {
    late _Backend backend;
    setUp(() => backend = _Backend(TargetPlatform.iOS));

    testWidgets('opens a native alert with app details and actions',
        (tester) async {
      await _show(tester, backend, _about(backend));

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Rides 1.4.0'), findsOneWidget);
      expect(find.text('ICON'), findsOneWidget);
      expect(find.text('© 2026 Rides Inc.'), findsOneWidget);
      expect(find.text('Made with Ruflet'), findsOneWidget);
      expect(find.widgetWithText(CupertinoDialogAction, 'View Licenses'),
          findsOneWidget);
      expect(
          find.widgetWithText(CupertinoDialogAction, 'Close'), findsOneWidget);
      // Icon, legalese and extra controls are stacked in that order.
      expect(tester.getTopLeft(find.text('ICON')).dy,
          lessThan(tester.getTopLeft(find.text('© 2026 Rides Inc.')).dy));
      expect(tester.getTopLeft(find.text('© 2026 Rides Inc.')).dy,
          lessThan(tester.getTopLeft(find.text('Made with Ruflet')).dy));
      _expectCupertinoOnly(tester);
    });

    testWidgets('defaults the name to the app title', (tester) async {
      await _show(
          tester,
          backend,
          _about(
              backend, {'application_name': null, 'application_version': null}),
          title: 'Ruflet Rides');
      expect(find.text('Ruflet Rides'), findsOneWidget);
      _expectCupertinoOnly(tester);
    });

    testWidgets('Close dismisses and fires dismiss once', (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(about.get('open'), isFalse);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('View Licenses lists packages and shows license text',
        (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoLicensePage), findsOneWidget);
      expect(find.text('Licenses'), findsWidgets);
      expect(find.byType(CupertinoListSection), findsOneWidget);
      final tile = find.widgetWithText(CupertinoListTile, _package);
      expect(tile, findsOneWidget);
      expect(
          find.descendant(of: tile, matching: find.text('1')), findsOneWidget);
      expect(
          find.descendant(
              of: tile, matching: find.byType(CupertinoListTileChevron)),
          findsOneWidget);
      // The page header repeats the application details.
      expect(find.text('Rides'), findsOneWidget);
      expect(find.text('1.4.0'), findsOneWidget);
      _expectCupertinoOnly(tester);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Ruflet test license.'));
      final indented =
          tester.getTopLeft(find.text('Indented clause of the license.'));
      expect(indented.dx - first.dx, 16);
      expect(indented.dy, greaterThan(first.dy));
      final heading = tester.getRect(find.text('TEST LICENSE'));
      expect(heading.center.dx, closeTo(400, 0.5));
      expect(heading.bottom, lessThanOrEqualTo(first.dy));
      _expectCupertinoOnly(tester);

      // Back to the list, back to the alert; the dialog is still open.
      Navigator.of(tester.element(find.text('Ruflet test license.'))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text(_package))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(backend.events, isEmpty);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('view: licenses opens the license page directly',
        (tester) async {
      final about = _about(backend, {'view': 'licenses'});
      await _show(tester, backend, about);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(CupertinoLicensePage), findsOneWidget);
      expect(find.text(_package), findsOneWidget);
      expect(ModalRoute.of(tester.element(find.text(_package))),
          isA<CupertinoPageRoute<void>>());

      Navigator.of(tester.element(find.text(_package))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoLicensePage), findsNothing);
      expect(about.get('open'), isFalse);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('open: false closes the alert and its license page',
        (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoLicensePage), findsOneWidget);

      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoLicensePage), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(backend.events, ['dismiss']);

      about.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      _expectCupertinoOnly(tester);
    });

    testWidgets('barrier tap dismisses; modal keeps it open', (tester) async {
      await _show(tester, backend, _about(backend));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('modal keeps the alert open on barrier tap', (tester) async {
      await _show(tester, backend, _about(backend, {'modal': true}));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(backend.events, isEmpty);
      _expectCupertinoOnly(tester);
    });

    testWidgets('open: false leaves another dialog above it alone',
        (tester) async {
      final about = _about(backend);
      final other = _otherDialog(backend);
      await _show(tester, backend, about, others: [other]);
      other.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsOneWidget);

      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      about.updateProperties({'data': 'rebuild'}, python: false, notify: true);
      await tester.pumpAndSettle();

      expect(find.text('Other dialog'), findsOneWidget);
      expect(find.text('Rides 1.4.0'), findsNothing);
      expect(other.get('open'), isTrue);
      expect(backend.controlEvents, ['1:dismiss']);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsNothing);
      expect(backend.controlEvents, ['1:dismiss', '20:dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('open: false closes its license pages, not a dialog above',
        (tester) async {
      final about = _about(backend);
      final other = _otherDialog(backend);
      await _show(tester, backend, about, others: [other]);
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_package));
      await tester.pumpAndSettle();
      expect(find.text('Ruflet test license.'), findsOneWidget);
      other.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();

      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();

      expect(find.text('Other dialog'), findsOneWidget);
      expect(backend.controlEvents, ['1:dismiss']);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // The alert, the package list and the license text all went with it.
      expect(find.text('Other dialog'), findsNothing);
      expect(find.byType(CupertinoLicensePage), findsNothing);
      expect(find.text('Ruflet test license.'), findsNothing);
      expect(find.text('Rides 1.4.0'), findsNothing);
      expect(backend.controlEvents, ['1:dismiss', '20:dismiss']);
      _expectCupertinoOnly(tester);
    });
  });

  group('Android AboutDialog', () {
    late _Backend backend;
    setUp(() => backend = _Backend(TargetPlatform.android));

    testWidgets('opens the Material AboutDialog', (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      final dialog = tester
          .widget<material.AboutDialog>(find.byType(material.AboutDialog));
      expect(dialog.applicationName, 'Rides');
      expect(dialog.applicationVersion, '1.4.0');
      expect(dialog.applicationLegalese, '© 2026 Rides Inc.');
      expect(find.text('ICON'), findsOneWidget);
      expect(find.text('Made with Ruflet'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await tester.tap(find.text('View licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(material.LicensePage), findsOneWidget);
      expect(find.byType(CupertinoLicensePage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Close dismisses and fires dismiss once', (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(about.get('open'), isFalse);
      expect(backend.events, ['dismiss']);
    });

    testWidgets('view: licenses opens the LicensePage directly',
        (tester) async {
      final about = _about(backend, {'view': 'licenses'});
      await _show(tester, backend, about);
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(find.byType(material.LicensePage), findsOneWidget);
      Navigator.of(tester.element(find.byType(material.LicensePage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(material.LicensePage), findsNothing);
      expect(backend.events, ['dismiss']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('open: false closes the dialog', (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(find.byType(material.Scaffold), findsOneWidget);
      expect(backend.events, ['dismiss']);
    });

    testWidgets('open: false leaves another dialog above it alone',
        (tester) async {
      final about = _about(backend);
      final other = _otherDialog(backend);
      await _show(tester, backend, about, others: [other]);
      other.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsOneWidget);

      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      about.updateProperties({'data': 'rebuild'}, python: false, notify: true);
      await tester.pumpAndSettle();

      expect(find.text('Other dialog'), findsOneWidget);
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(other.get('open'), isTrue);
      expect(backend.controlEvents, ['1:dismiss']);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsNothing);
      expect(backend.controlEvents, ['1:dismiss', '20:dismiss']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('open: false closes its LicensePage, not a dialog above',
        (tester) async {
      final about = _about(backend);
      final other = _otherDialog(backend);
      await _show(tester, backend, about, others: [other]);
      await tester.tap(find.text('View licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(material.LicensePage), findsOneWidget);
      other.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();

      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();

      expect(find.text('Other dialog'), findsOneWidget);
      expect(backend.controlEvents, ['1:dismiss']);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsNothing);
      expect(find.byType(material.LicensePage), findsNothing);
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(backend.controlEvents, ['1:dismiss', '20:dismiss']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('open: false closes the LicensePage it opened', (tester) async {
      final about = _about(backend);
      await _show(tester, backend, about);
      await tester.tap(find.text('View licenses'));
      await tester.pumpAndSettle();
      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(material.LicensePage), findsNothing);
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(find.byType(material.Scaffold), findsOneWidget);
      expect(backend.events, ['dismiss']);
      expect(tester.takeException(), isNull);
    });
  });

  group('license route bookkeeping', () {
    testWidgets('iOS: browsing licenses repeatedly leaves no stale routes',
        (tester) async {
      final backend = _Backend(TargetPlatform.iOS);
      final about = _about(backend);
      await _show(tester, backend, about);

      for (var round = 0; round < 3; round++) {
        await tester.tap(find.text('View Licenses'));
        await tester.pumpAndSettle();
        expect(adoptedControlRoutes(about), hasLength(1));
        await tester.tap(find.text(_package));
        await tester.pumpAndSettle();
        expect(adoptedControlRoutes(about), hasLength(2));

        // Back from the license text, then back to the alert.
        Navigator.of(tester.element(find.text('Ruflet test license.'))).pop();
        await tester.pumpAndSettle();
        expect(adoptedControlRoutes(about), hasLength(1),
            reason: 'round $round: the closed detail page is forgotten');
        Navigator.of(tester.element(find.text(_package))).pop();
        await tester.pumpAndSettle();
        expect(adoptedControlRoutes(about), isEmpty,
            reason: 'round $round: no stale license routes');
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      }

      // Close still removes the dialog and the license page it owns now.
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();
      expect(adoptedControlRoutes(about), hasLength(1));
      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoLicensePage), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(adoptedControlRoutes(about), isEmpty);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('Android: browsing licenses repeatedly leaves no stale routes',
        (tester) async {
      final backend = _Backend(TargetPlatform.android);
      final about = _about(backend);
      await _show(tester, backend, about);

      for (var round = 0; round < 3; round++) {
        await tester.tap(find.text('View licenses'));
        await tester.pumpAndSettle();
        expect(adoptedControlRoutes(about), hasLength(1));
        Navigator.of(tester.element(find.byType(material.LicensePage))).pop();
        await tester.pumpAndSettle();
        expect(adoptedControlRoutes(about), isEmpty,
            reason: 'round $round: no stale LicensePage routes');
        expect(find.byType(material.AboutDialog), findsOneWidget);
      }

      await tester.tap(find.text('View licenses'));
      await tester.pumpAndSettle();
      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(material.LicensePage), findsNothing);
      expect(find.byType(material.AboutDialog), findsNothing);
      expect(adoptedControlRoutes(about), isEmpty);
      expect(backend.events, ['dismiss']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reopening starts with no adopted routes', (tester) async {
      final backend = _Backend(TargetPlatform.iOS);
      final about = _about(backend);
      await _show(tester, backend, about);
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();
      // Dismiss the alert underneath via Ruby while the license page is up.
      about.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      about.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(adoptedControlRoutes(about), isEmpty);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });
  });
}
