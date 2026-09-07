
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/ruflet_core_extension.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class MatrixBackend extends RufletBackend {
  MatrixBackend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://matrix'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

class Fixtures {
  int nextId = 100;
  Map<String, dynamic> node(String type,
          [Map<String, dynamic> props = const {}]) =>
      {'_c': type, '_i': ++nextId, ...props};
  Map<String, dynamic> text([String value = 'Content']) =>
      node('Text', {'value': value});

  Map<String, dynamic> fixture(String type) {
    final props = <String, dynamic>{
      'content': text(),
      'controls': [text('One'), text('Two')],
    };
    switch (type) {
      case 'Text':
      case 'TextField':
      case 'Markdown':
        props['value'] = 'Content';
      case 'Hero':
        props['tag'] = 'hero';
      case 'Chip':
        props['label'] = text('Chip');
      case 'GestureDetector':
        props['on_tap'] = true;
      case 'ContextMenu':
        props['actions'] = [
          node('ContextMenuAction', {'content': text('Action')})
        ];
      case 'Image':
        props['src'] =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6i8AAAAASUVORK5CYII=';
      case 'SegmentedButton':
        props.addAll({
          'segments': [
            node('Segment', {'value': 'one', 'label': text('One')}),
            node('Segment', {'value': 'two', 'label': text('Two')})
          ],
          'selected': ['one']
        });
      case 'DataTable':
        props.addAll({
          'columns': [
            node('DataColumn', {'label': text('Column')})
          ],
          'rows': [
            node('DataRow', {
              'cells': [
                node('DataCell', {'content': text('Cell')})
              ]
            })
          ]
        });
      case 'NavigationBar':
      case 'NavigationRail':
        props['destinations'] = [
          node('NavigationBarDestination', {'label': 'One', 'icon': text('1')}),
          node('NavigationBarDestination', {'label': 'Two', 'icon': text('2')})
        ];
      case 'NavigationBarDestination':
        return node('NavigationBar', {
          'destinations': [
            node(type, {'label': 'One', 'icon': text('1')}),
            node(type, {'label': 'Two', 'icon': text('2')})
          ]
        });
      case 'Dropdown':
        props['options'] = [
          node('DropdownOption', {'key': 'one', 'text': 'One'})
        ];
      case 'ExpansionPanelList':
        return node('Column', {
          'controls': [
            node(type, {
              'controls': [
                node('ExpansionPanel',
                    {'header': text('Header'), 'content': text('Body')})
              ]
            })
          ]
        });
      case 'ExpansionTile':
      case 'ListTile':
      case 'AppBar':
        props['title'] = text('Title');
      case 'Radio':
        return node('RadioGroup', {
          'value': 'one',
          'content': node('Radio', {'value': 'one', 'label': 'One'})
        });
      case 'RadioGroup':
        props.addAll({
          'value': 'one',
          'content': node('Radio', {'value': 'one', 'label': 'One'})
        });
      case 'RangeSlider':
        props.addAll(
            {'start_value': 0.2, 'end_value': 0.8, 'min': 0.0, 'max': 1.0});
      case 'Tab':
      case 'TabBar':
      case 'TabBarView':
      case 'Tabs':
        return node('Tabs', {
          'length': 2,
          'content': node('Column', {
            'controls': [
              node('TabBar', {
                'tabs': [
                  node('Tab', {'label': text('One')}),
                  node('Tab', {'label': text('Two')})
                ]
              }),
              node('TabBarView', {
                'height': 180,
                'controls': [text('First'), text('Second')]
              })
            ]
          })
        });
      case 'ReorderableDragHandle':
        return node('ReorderableListView', {
          'controls': [
            node(type, {'index': 0, 'content': text('Drag')})
          ]
        });
      case 'ShaderMask':
        props['shader'] = {
          '_type': 'linear',
          'colors': ['#112233', '#445566']
        };
      case 'Shimmer':
        props.addAll({'base_color': '#112233', 'highlight_color': '#445566'});
      case 'RotatedBox':
        props['quarter_turns'] = 1;
      case 'ActionSheet':
        props['actions'] = [
          node('ActionSheetAction', {'content': text('Action')})
        ];
      case 'AlertDialog':
      case 'BottomSheet':
      case 'SnackBar':
      case 'DatePicker':
      case 'DateRangePicker':
      case 'TimePicker':
        props['open'] = false;
      case 'TimerPicker':
        props['value'] = 0;
      case 'MenuBar':
      case 'SubmenuButton':
      case 'PopupMenuButton':
        props['controls'] = [
          node('MenuItemButton', {'content': text('Menu item')})
        ];
    }
    return node(type, props);
  }
}

bool materialOnly(Widget widget) =>
    widget is material.Material ||
    widget is material.Theme ||
    widget is material.Scaffold ||
    widget is material.Scrollbar ||
    widget is material.InkResponse ||
    widget is material.SelectableText ||
    widget is material.SelectionArea ||
    widget is material.TextSelectionTheme ||
    widget is material.TextField ||
    widget is material.ButtonStyleButton ||
    widget is material.CircularProgressIndicator ||
    widget is material.LinearProgressIndicator ||
    widget is material.AlertDialog ||
    widget is material.BottomSheet;

void main() {
  final registry = File('lib/src/ruflet_core_extension.dart')
      .readAsStringSync()
      .split('Widget? createWidget')
      .last
      .split('createService')
      .first;
  final types =
      RegExp(r'case "([^"]+)"').allMatches(registry).map((m) => m[1]!).toSet();
  // App/backend lifecycle and view routing have separate integration fixtures.
  const appShells = {'Page', 'View', 'RufletApp'};

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux
  ]) {
    for (final type in types.difference(appShells)) {
      testWidgets(
          '${platform.name}: canonical $type renders without opposite chrome',
          (tester) async {
        final backend = MatrixBackend(platform);
        final fixture = Fixtures().fixture(type);
        final root = Control.fromMap(fixture, backend, parent: backend.page);
        final rendered = RufletCoreExtension().createWidget(null, root);
        expect(rendered, isNotNull, reason: type);
        final design = usesCupertinoControls(platform)
            ? PageDesign.cupertino
            : PageDesign.material;
        final content =
            Center(child: SizedBox(width: 500, height: 500, child: rendered));
        await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: PageContext(
            themeMode: RufletThemeMode.light,
            brightness: Brightness.light,
            widgetsDesign: design,
            targetPlatform: platform,
            child: PlatformApp(
                design: design,
                config: PlatformAppConfig(
                  title: 'Matrix',
                  showSemanticsDebugger: false,
                  targetPlatform: platform,
                  home: design == PageDesign.cupertino
                      ? CupertinoPageScaffold(child: content)
                      : material.Scaffold(body: content),
                  routerDelegate: null,
                  routeInformationParser: null,
                  routeInformationProvider: null,
                  localizationsDelegates: const [],
                  supportedLocales: const [Locale('en')],
                  locale: const Locale('en'),
                )),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: type);
        expect(find.byType(ErrorControl), findsNothing,
            reason: 'Fixture must exercise $type, not its error fallback');
        if (design == PageDesign.cupertino) {
          expect(find.byWidgetPredicate(materialOnly), findsNothing,
              reason: type);
        } else {
          // Flutter's Material Theme internally supplies an inherited Cupertino
          // compatibility theme, even on Android. It is not a Ruflet renderer.
          expect(
              find.byWidgetPredicate((w) =>
                  w is CupertinoButton ||
                  w is CupertinoTextField ||
                  w is CupertinoPageScaffold ||
                  w is CupertinoScrollbar),
              findsNothing,
              reason: type);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
