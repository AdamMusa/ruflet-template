import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <String>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://search-bar-tap-outside-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      ) {
    this.platform = platform;
  }

  @override
  void triggerControlEventById(
    int controlId,
    String eventName, [
    dynamic eventData,
  ]) => events.add(eventName);

  @override
  void updateControl(
    int id,
    Map<String, dynamic> props, {
    bool dart = true,
    bool python = true,
    bool notify = false,
  }) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

Future<_RecordingBackend> _pumpSearchBar(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'SearchBar',
    '_i': 1,
    'width': 300,
    'bar_hint_text': 'Search',
    'on_tap_outside_bar': true,
  }, backend);
  final body = Center(child: ControlWidget(control: control));
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: CupertinoPageScaffold(child: body))
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
  return backend;
}

/// A SearchBar with one suggestion; [props] adds Ruby keys.
Future<(_RecordingBackend, Control)> _pumpSearchView(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> props,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'SearchBar',
    '_i': 1,
    'width': 300,
    'bar_hint_text': 'Search',
    'controls': [
      {'_c': 'Text', '_i': 2, 'value': 'Suggestion'},
    ],
    ...props,
  }, backend);
  final body = Center(child: ControlWidget(control: control));
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: CupertinoPageScaffold(child: body))
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
  return (backend, control);
}

/// Opens the search view the way Ruby does (open_view, e.g. from on_tap):
/// Material pushes its view route, iOS activates the field and lists the
/// suggestions inline.
Future<void> _openView(WidgetTester tester, Control control) async {
  final call = control.invokeMethod(
    'open_view',
    const {},
    const Duration(seconds: 1),
  );
  await tester.pumpAndSettle();
  await call;
  expect(find.text('Suggestion'), findsOneWidget);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform SearchBar fires Ruby on_tap_outside_view', (
      tester,
    ) async {
      final (backend, control) = await _pumpSearchView(tester, platform, {
        'on_tap_outside_view': true,
        'on_tap_outside_bar': true,
      });
      // Closed: an outside tap is not a view event.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(backend.events, isEmpty);

      await _openView(tester, control);
      // Taps on the view's own field and suggestions stay inside.
      await tester.tap(find.text('Suggestion'));
      await tester.pump();
      await tester.tap(find.byType(EditableText).last);
      await tester.pump();
      expect(backend.events, isNot(contains('tap_outside_view')));

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(
        backend.events.where((e) => e == 'tap_outside_view'),
        hasLength(1),
      );
      // That tap belongs to the open view, not to the bar.
      expect(backend.events, isNot(contains('tap_outside_bar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform SearchBar view taps are silent unsubscribed', (
      tester,
    ) async {
      final (backend, control) = await _pumpSearchView(tester, platform, {});
      await _openView(tester, control);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(backend.events, isNot(contains('tap_outside_view')));
    });
  }

  testWidgets('Material SearchBar view closes on an outside tap, once', (
    tester,
  ) async {
    final (backend, control) = await _pumpSearchView(
      tester,
      TargetPlatform.android,
      {'on_tap_outside_view': true},
    );
    await _openView(tester, control);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Suggestion'), findsNothing, reason: 'barrier dismissed');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(backend.events.where((e) => e == 'tap_outside_view'), hasLength(1));
  });

  testWidgets('iOS SearchBar listing suggestions for a query is an open view', (
    tester,
  ) async {
    final (backend, control) = await _pumpSearchView(
      tester,
      TargetPlatform.iOS,
      {'value': 'S', 'on_tap_outside_view': true, 'on_tap_outside_bar': true},
    );
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(find.text('Suggestion'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(backend.events, ['tap_outside_view']);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform SearchBar fires Ruby on_tap_outside_bar', (
      tester,
    ) async {
      final backend = await _pumpSearchBar(tester, platform);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(backend.events, isNot(contains('tap_outside_bar')));

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(backend.events.where((e) => e == 'tap_outside_bar'), hasLength(1));
    });

    testWidgets('$platform SearchBar ignores outside taps while unfocused', (
      tester,
    ) async {
      final backend = await _pumpSearchBar(tester, platform);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(backend.events, isNot(contains('tap_outside_bar')));
    });
  }
}
