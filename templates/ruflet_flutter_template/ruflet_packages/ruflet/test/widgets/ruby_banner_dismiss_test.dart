import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <String>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://banner-dismiss-test'),
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

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform Banner fires Ruby on_dismiss when it closes', (
      tester,
    ) async {
      final backend = _RecordingBackend(platform);
      final control = Control.fromMap({
        '_c': 'Banner',
        '_i': 1,
        'open': true,
        'content': {'_c': 'Text', '_i': 2, 'value': 'Offline'},
        'actions': [
          {'_c': 'Button', '_i': 3, 'content': 'Retry'},
        ],
        'on_dismiss': true,
      }, backend);
      final host = ControlWidget(control: control);
      await tester.pumpWidget(
        ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: platform == TargetPlatform.iOS
              ? CupertinoApp(home: CupertinoPageScaffold(child: host))
              : material.MaterialApp(home: material.Scaffold(body: host)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(backend.events, isNot(contains('dismiss')));

      for (var cycle = 1; cycle <= 2; cycle++) {
        control.update({'open': false}, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(find.text('Offline'), findsNothing);
        expect(backend.events.where((e) => e == 'dismiss'), hasLength(cycle));

        control.update({'open': true}, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(find.text('Offline'), findsOneWidget);
        expect(backend.events.where((e) => e == 'dismiss'), hasLength(cycle));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
