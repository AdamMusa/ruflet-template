import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <String>[];

  _RecordingBackend(TargetPlatform platform)
      : super(
          pageUri: Uri.parse('inprocess://slider-focus-events-test'),
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
  ]) =>
      events.add(eventName);

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

Future<(_RecordingBackend, Control)> _pumpSlider(
  WidgetTester tester,
  TargetPlatform platform, {
  Map<String, dynamic> props = const {},
}) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'Slider',
    '_i': 1,
    'width': 300,
    'min': 0,
    'max': 100,
    'value': 50,
    ...props,
    'on_focus': true,
    'on_blur': true,
    'on_change': true,
    'on_change_start': true,
    'on_change_end': true,
  }, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: ControlWidget(control: control),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  return (backend, control);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform Slider fires Ruby on_focus and on_blur', (
      tester,
    ) async {
      final (backend, _) = await _pumpSlider(tester, platform);
      expect(backend.events, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(backend.events, ['focus']);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(backend.events, ['focus', 'blur']);
    });

    testWidgets('$platform Slider honors Ruby autofocus', (tester) async {
      final (backend, _) = await _pumpSlider(
        tester,
        platform,
        props: {'autofocus': true},
      );
      expect(backend.events, ['focus']);
    });
  }

  // A focused native slider is adjusted with the arrow keys (iOS Full
  // Keyboard Access, macOS). Steps match Flutter's Material slider on Apple
  // platforms: one division, or a tenth of the range without divisions.
  for (final (divisions, expected) in [(null, 60.0), (4, 75.0)]) {
    testWidgets(
      'Cupertino Slider steps with arrow keys when focused (divisions=$divisions)',
      (tester) async {
        final (backend, control) = await _pumpSlider(
          tester,
          TargetPlatform.iOS,
          props: {
            'autofocus': true,
            if (divisions != null) 'divisions': divisions
          },
        );
        backend.events.clear();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(control.getDouble('value'), expected);
        expect(backend.events, ['change_start', 'change', 'change_end']);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(control.getDouble('value'), 50);
        expect(
          tester.widget<CupertinoSlider>(find.byType(CupertinoSlider)).value,
          50,
        );
      },
    );
  }

  testWidgets('Disabled Cupertino Slider ignores arrow keys', (tester) async {
    final (backend, control) = await _pumpSlider(
      tester,
      TargetPlatform.iOS,
      props: {'autofocus': true, 'disabled': true},
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(control.getDouble('value'), 50);
    expect(backend.events.where((e) => e.startsWith('change')), isEmpty);
  });
}
