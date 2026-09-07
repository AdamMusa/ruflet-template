import 'package:ruflet/ruflet.dart';
import 'package:ruflet_color_pickers/src/extension.dart';
import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as upstream;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class RecordingBackend extends RufletBackend {
  final events = <List<dynamic>>[];
  RecordingBackend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }
  @override
  void triggerControlEventById(int id, String name, [dynamic data]) =>
      events.add([id, name, data]);
  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    if (dart) controlsIndex.get(id)?.update(props, shouldNotify: notify);
  }
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        '$platform all six wire pickers dispatch and block selection emits unchanged payload',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = RecordingBackend(platform);
      for (final type in [
        'ColorPicker',
        'HueRingPicker',
        'SlidePicker',
        'MaterialPicker',
        'BlockPicker',
        'MultipleChoiceBlockPicker'
      ]) {
        final control = Control.fromMap({
          '_i': 1,
          '_c': type,
          'color': '#ff0000',
          'colors': ['#ff0000'],
          'available_colors': ['#ff0000', '#0000ff'],
          'on_color_change': true,
          'on_colors_change': true,
        }, backend);
        final picker = Extension().createWidget(null, control)!;
        final child = Center(
            child: SingleChildScrollView(
                child: SizedBox(width: 350, child: picker)));
        await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
            value: backend,
            child: platform == TargetPlatform.iOS
                ? CupertinoApp(home: CupertinoPageScaffold(child: child))
                : material.MaterialApp(home: material.Scaffold(body: child))));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: type);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(material.Material), findsNothing, reason: type);
          expect(find.byType(material.Theme), findsNothing, reason: type);
          expect(find.byType(material.TextField), findsNothing, reason: type);
          expect(find.byType(material.InkWell), findsNothing, reason: type);
        }
        if (type == 'BlockPicker') {
          if (platform == TargetPlatform.iOS) {
            expect(find.byType(native.BlockPicker), findsOneWidget);
            await tester.tap(find.byType(CupertinoButton).at(1));
          } else {
            expect(find.byType(upstream.BlockPicker), findsOneWidget);
            await tester.tap(find.byType(material.InkWell).at(1));
          }
          await tester.pumpAndSettle();
          expect(backend.events,
              contains(equals([1, 'color_change', '#ff0000ff'])));
          expect(control.getString('color'), '#ff0000ff');
        }
        await tester.pumpWidget(const SizedBox());
      }
      backend.dispose();
    });
  }
}
