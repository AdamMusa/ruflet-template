import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_alert_dialog.dart';
import 'package:ruflet/src/controls/cupertino_app_bar.dart';
import 'package:ruflet/src/controls/cupertino_button.dart';
import 'package:ruflet/src/controls/cupertino_checkbox.dart';
import 'package:ruflet/src/controls/cupertino_container.dart';
import 'package:ruflet/src/controls/cupertino_dialog_action.dart';
import 'package:ruflet/src/controls/cupertino_radio.dart';
import 'package:ruflet/src/controls/cupertino_switch.dart';
import 'package:ruflet/src/controls/cupertino_textfield.dart';
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet/src/widgets/list_tile_clicks.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _Backend()
      : super(
            pageUri: Uri.parse('ruflet://test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = TargetPlatform.iOS;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    events.add((control.id, eventName, data));
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

void main() {
  late _Backend backend;
  var nextId = 0;
  setUp(() {
    backend = _Backend();
  });

  Control control(String type, Map<String, dynamic> properties) {
    final result = Control(
        id: ++nextId, type: type, properties: properties, backend: backend);
    backend.controlsIndex.set(result.id, result);
    return result;
  }

  Widget app(Widget child, {ObstructingPreferredSizeWidget? navigationBar}) =>
      ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: CupertinoApp(
          theme: const CupertinoThemeData(primaryColor: Color(0xff13579b)),
          builder: (context, child) => RufletStyleThemeScope(
              data: cupertinoStyleTheme(context), child: child!),
          home:
              CupertinoPageScaffold(navigationBar: navigationBar, child: child),
        ),
      );

  testWidgets(
      'native input controls use Cupertino theme roles and state colors',
      (tester) async {
    final checkbox = control('Checkbox', {
      'label': 'Check',
      'fill_color': {'selected': 'primary'},
      'value': true
    });
    final radio = control('Radio', {'value': 'a', 'disabled': true});
    final toggle = control('Switch', {
      'value': true,
      'focus_color': '#112233',
      'thumb_color': {'selected': '#abcdef', 'default': '#654321'}
    });
    var changedRadio = false;
    await tester.pumpWidget(app(Column(children: [
      CupertinoCheckboxControl(control: checkbox),
      RadioGroup<String>(
          groupValue: 'a',
          onChanged: (_) => changedRadio = true,
          child: CupertinoRadioControl(control: radio)),
      CupertinoSwitchControl(control: toggle),
    ])));
    expect(
        tester
            .widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox))
            .fillColor
            ?.resolve({WidgetState.selected}),
        const Color(0xff13579b));
    final nativeRadio = tester
        .widget<CupertinoRadio<String>>(find.byType(CupertinoRadio<String>));
    expect(nativeRadio.activeColor, const Color(0xff13579b));
    expect(nativeRadio.enabled, isFalse);
    await tester.tap(find.byType(CupertinoRadio<String>));
    expect(changedRadio, isFalse);
    final nativeSwitch =
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(nativeSwitch.thumbColor, const Color(0xffabcdef));
    expect(nativeSwitch.focusColor, const Color(0xff112233));
    expect(find.byType(material.Theme), findsNothing);
  });

  testWidgets('disabled tile toggles ignore their inherited click notifier',
      (tester) async {
    final checkbox = control('Checkbox', {'disabled': true, 'value': false});
    final toggle = control('Switch', {'disabled': true, 'value': false});
    final clicks = ListTileClickNotifier();
    await tester.pumpWidget(app(ListTileClicks(
        notifier: clicks,
        child: Column(children: [
          CupertinoCheckboxControl(control: checkbox),
          CupertinoSwitchControl(control: toggle)
        ]))));
    clicks.onClick();
    expect(checkbox.get('value'), isFalse);
    expect(toggle.get('value'), isFalse);
    expect(backend.events.where((event) => event.$2 == 'change'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    clicks.dispose();
  });

  testWidgets('textfield selection and style use native inherited values',
      (tester) async {
    final field = control('TextField', {
      'value': 'Native text',
      'text_style': {'color': 'primary'},
      'selection_color': '#abcdef',
      'cursor_color': '#123456',
      'border': 'underline'
    });
    await tester.pumpWidget(
        app(Center(child: CupertinoTextFieldControl(control: field))));
    final native =
        tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(native.style?.color, const Color(0xff13579b));
    expect(native.cursorColor, const Color(0xff123456));
    final editable = tester.element(find.byType(EditableText));
    expect(DefaultSelectionStyle.of(editable).selectionColor,
        const Color(0xffabcdef));
    expect(find.byType(material.TextSelectionTheme), findsNothing);
    expect(find.byType(material.Theme), findsNothing);
    await tester.enterText(find.byType(CupertinoTextField), 'Updated');
    expect(field.get('value'), 'Updated');
  });

  testWidgets(
      'container, app bar and dialog action parse native semantic styles',
      (tester) async {
    final box = control('Container', {
      'width': 30,
      'height': 30,
      'gradient': {
        '_type': 'linear',
        'colors': ['primary', '#ffffff']
      }
    });
    final action = control('Button', {
      'content': 'Continue',
      'text_style': {'color': 'primary'}
    });
    final bar = control('AppBar', {
      'title': 'Native title',
      'border': {
        'bottom': {'color': 'primary', 'width': 2}
      }
    });
    await tester.pumpWidget(app(
        Column(children: [
          CupertinoContainerControl(control: box),
          CupertinoDialogActionControl(control: action),
        ]),
        navigationBar: CupertinoAppBarControl(control: bar)));
    final nativeBar = tester
        .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar));
    expect(nativeBar.border?.bottom.color, const Color(0xff13579b));
    final nativeAction = tester
        .widget<CupertinoDialogAction>(find.byType(CupertinoDialogAction));
    expect(nativeAction.textStyle?.color, const Color(0xff13579b));
    final decorated = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(CupertinoContainerControl),
            matching: find.byType(Container)))
        .firstWhere((widget) =>
            (widget.decoration as BoxDecoration?)?.gradient != null);
    expect((decorated.decoration as BoxDecoration).gradient?.colors.first,
        const Color(0xff13579b));
    expect(find.byType(material.Theme), findsNothing);
  });

  testWidgets('alert dialog opens a Cupertino route and reports dismissal',
      (tester) async {
    final dialog = control('AlertDialog',
        {'title': 'Native dialog', 'open': true, 'barrier_color': '#22112233'});
    await tester.pumpWidget(app(CupertinoAlertDialogControl(control: dialog)));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(CupertinoAlertDialog));
    expect(ModalRoute.of(context), isA<CupertinoDialogRoute<dynamic>>());
    expect(ModalRoute.of(context), isNot(isA<material.DialogRoute<dynamic>>()));
    expect(dialog.get('_open'), isTrue);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(dialog.get('open'), isFalse);
    expect(
        backend.events.where((event) => event.$2 == 'dismiss'), hasLength(1));
  });

  testWidgets('common button style responds to pressed state and emits click',
      (tester) async {
    final button = control('Button', {
      'content': 'Styled button',
      'style': {
        'color': {'default': '#123456', 'pressed': '#654321'},
        'bgcolor': '#eeeeee',
        'padding': 12,
        'text_style': {'size': 21},
        'fixed_size': {'width': 220, 'height': 60},
        'side': {'color': 'primary', 'width': 2},
      }
    });
    await tester.pumpWidget(
        app(Center(child: CupertinoButtonControl(control: button))));
    final label = find.text('Styled button');
    expect(DefaultTextStyle.of(tester.element(label)).style.fontSize, 21);
    expect(DefaultTextStyle.of(tester.element(label)).style.color,
        const Color(0xff123456));
    expect(tester.getSize(find.byType(CupertinoButtonControl)),
        const Size(220, 60));
    final press = await tester.startGesture(tester.getCenter(label));
    await tester.pump();
    expect(DefaultTextStyle.of(tester.element(label)).style.color,
        const Color(0xff654321));
    await press.up();
    await tester.pumpAndSettle();
    expect(backend.events.where((event) => event.$2 == 'click'), hasLength(1));
    expect(find.byType(material.ElevatedButton), findsNothing);
    expect(find.byType(material.Theme), findsNothing);
  });
}
