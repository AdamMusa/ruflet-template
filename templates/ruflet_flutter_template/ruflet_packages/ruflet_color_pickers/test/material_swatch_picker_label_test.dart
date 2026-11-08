import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_color_pickers/src/extension.dart';
import 'package:ruflet_color_pickers/src/material_swatch_picker/material_swatch_picker.dart';

void main() {
  testWidgets('Android material_picker labels show #RRGGBB from the channels',
      (tester) async {
    final backend = RufletBackend(
        pageUri: Uri.parse('ruflet://test'),
        assetsDir: '',
        extensions: [],
        multiView: false)
      ..platform = TargetPlatform.android;
    final control = Control.fromMap({
      '_i': 1,
      '_c': 'MaterialPicker',
      'color': '#ffebee', // red 50
      'enable_label': true,
      'portrait_only': true,
    }, backend);
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: MaterialApp(
            home: Scaffold(
                body:
                    Center(child: Extension().createWidget(null, control)!)))));

    expect(find.byType(MaterialSwatchPicker), findsOneWidget);
    // Red shades, in palette order: 50 and 100.
    expect(find.text('#FFEBEE  '), findsOneWidget);
    expect(find.text('#FFCDD2  '), findsOneWidget);
    // Never the Flutter 3.27+ Color.toString() format.
    expect(find.textContaining('COLOR('), findsNothing);
    expect(find.textContaining('ALPHA'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
