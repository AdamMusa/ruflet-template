import 'package:flet/flet.dart';
import 'package:flet/src/controls/cupertino_banner.dart';
import 'package:flet/src/controls/cupertino_snack_bar.dart';
import 'package:flet/src/controls/material_banner.dart';
import 'package:flet/src/controls/material_snack_bar.dart';
import 'package:flet/src/flet_core_extension.dart';
import 'package:flet/src/models/page_design.dart';
import 'package:flet/src/widgets/page_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends FletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('flet://boundary'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}
}

void main() {
  for (final type in ['Banner', 'SnackBar']) {
    for (final design in PageDesign.values) {
      testWidgets('$type honors $design when backend platform disagrees',
          (tester) async {
        final backend = _Backend(design == PageDesign.cupertino
            ? TargetPlatform.android
            : TargetPlatform.iOS);
        final control = Control.fromMap({
          '_i': 10,
          '_c': type,
          'open': false,
          'content': {'_i': 11, '_c': 'Text', 'value': 'Message'},
        }, backend, parent: backend.page);
        final child = FletCoreExtension().createWidget(null, control)!;
        await tester.pumpWidget(ChangeNotifierProvider<FletBackend>.value(
          value: backend,
          child: PageContext(
            widgetsDesign: design,
            themeMode: FletThemeMode.light,
            brightness: Brightness.light,
            child: design == PageDesign.cupertino
                ? CupertinoApp(home: CupertinoPageScaffold(child: child))
                : material.MaterialApp(home: material.Scaffold(body: child)),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final nativeType = type == 'Banner'
            ? CupertinoBannerControl
            : CupertinoSnackBarControl;
        final materialType =
            type == 'Banner' ? MaterialBannerControl : MaterialSnackBarControl;
        expect(find.byType(nativeType),
            design == PageDesign.cupertino ? findsOneWidget : findsNothing);
        expect(find.byType(materialType),
            design == PageDesign.material ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
