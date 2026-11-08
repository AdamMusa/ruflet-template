import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <(int, String)>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://text-field-focus-styling'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    events.add((control.id, eventName));
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

const _red = Color(0xFFFF0000);
const _gray = Color(0xFF888888);
const _yellow = Color(0xFFFFFF00);

final _native = const CupertinoTextField().decoration!;
final _nativeSide = (_native.border! as Border).top;

Future<_Backend> _pump(WidgetTester tester, TargetPlatform platform,
    List<Map<String, dynamic>> fields) async {
  final backend = _Backend(platform);
  var id = 100;
  final controls = [
    for (final props in fields)
      Control.fromMap({'_c': 'TextField', '_i': ++id, 'value': 'Ada', ...props},
          backend)
  ];
  final body = Center(
    child: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final c in controls) ControlWidget(control: c)],
      ),
    ),
  );
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  ));
  return backend;
}

BoxDecoration? _decoration(WidgetTester tester, int index) => tester
    .widget<CupertinoTextField>(find.byType(CupertinoTextField).at(index))
    .decoration;

Future<void> _focus(WidgetTester tester, int index) async {
  await tester.showKeyboard(find.byType(EditableText).at(index));
  await tester.pumpAndSettle();
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  group('Cupertino TextField focus styling', () {
    testWidgets('focused_border_color and focused_bgcolor apply while focused',
        (tester) async {
      final backend = await _pump(tester, TargetPlatform.iOS, [
        {
          'border': 'outline',
          'border_color': '#888888',
          'focused_border_color': '#ff0000',
          'focused_bgcolor': '#ffff00',
          'on_focus': true,
          'on_blur': true,
        },
      ]);

      expect(_decoration(tester, 0)!.border,
          Border.all(color: _gray, width: _nativeSide.width));
      expect(_decoration(tester, 0)!.color, _native.color);

      await _focus(tester, 0);
      expect(_decoration(tester, 0)!.border,
          Border.all(color: _red, width: _nativeSide.width));
      expect(_decoration(tester, 0)!.color, _yellow);

      await _unfocus(tester);
      expect(_decoration(tester, 0)!.border,
          Border.all(color: _gray, width: _nativeSide.width));
      expect(_decoration(tester, 0)!.color, _native.color);
      expect(backend.events, containsAllInOrder([(101, 'focus'), (101, 'blur')]));
    });

    testWidgets('focused_border_width widens the focused border',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {'border': 'outline', 'border_width': 1, 'focused_border_width': 2},
      ]);
      final unfocusedHeight =
          tester.getSize(find.byType(CupertinoTextField)).height;
      expect(_decoration(tester, 0)!.border,
          Border.all(color: _nativeSide.color, width: 1));

      await _focus(tester, 0);
      expect(_decoration(tester, 0)!.border,
          Border.all(color: _nativeSide.color, width: 2));
      // The wider border insets the content by 1 dp on each side.
      expect(tester.getSize(find.byType(CupertinoTextField)).height,
          unfocusedHeight + 2);
    });

    testWidgets('a field without a border keyword gets an outline focus ring',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {'focused_border_color': '#ff0000'},
      ]);
      // Unfocused it is indistinguishable from the native field.
      expect(_decoration(tester, 0), _native);

      await _focus(tester, 0);
      expect(_decoration(tester, 0)!.border,
          Border.all(color: _red, width: _nativeSide.width));
      expect(_decoration(tester, 0)!.borderRadius, _native.borderRadius);
    });

    testWidgets('underline and Border maps recolor only their drawn sides',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {'border': 'underline', 'focused_border_color': '#ff0000'},
        {
          'border': {
            'bottom': {'color': '#888888', 'width': 3}
          },
          'focused_border_color': '#ff0000',
        },
      ]);

      await _focus(tester, 0);
      expect(_decoration(tester, 0)!.border,
          Border(bottom: _nativeSide.copyWith(color: _red)));

      await _focus(tester, 1);
      final map = _decoration(tester, 1)!.border! as Border;
      expect(map.bottom, const BorderSide(color: _red, width: 3));
      expect(map.top, BorderSide.none);
      // The first field lost focus and is back to its resting color.
      expect(_decoration(tester, 0)!.border, Border(bottom: _nativeSide));
    });

    testWidgets('border: "none" stays borderless but takes focused_bgcolor',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {
          'border': 'none',
          'focused_border_color': '#ff0000',
          'focused_bgcolor': '#ffff00',
        },
      ]);
      expect(_decoration(tester, 0), isNull);

      await _focus(tester, 0);
      expect(_decoration(tester, 0)!.border, isNull);
      expect(_decoration(tester, 0)!.color, _yellow);

      await _unfocus(tester);
      expect(_decoration(tester, 0), isNull);
    });

    testWidgets('shift_enter fields style their own focus node',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {
          'shift_enter': true,
          'border': 'outline',
          'focused_border_color': '#ff0000',
        },
      ]);
      await _focus(tester, 0);
      expect(_decoration(tester, 0)!.border,
          Border.all(color: _red, width: _nativeSide.width));
    });
  });

  testWidgets('Material focused border and fill are unchanged',
      (tester) async {
    await _pump(tester, TargetPlatform.android, [
      {
        'border_color': '#888888',
        'focused_border_color': '#ff0000',
        'focused_bgcolor': '#ffff00',
        'filled': true,
      },
    ]);
    material.InputDecoration decoration() => tester
        .widget<material.InputDecorator>(find.byType(material.InputDecorator))
        .decoration;

    expect(find.byType(CupertinoTextField), findsNothing);
    expect((decoration().focusedBorder! as material.OutlineInputBorder)
        .borderSide
        .color, _red);
    expect(decoration().fillColor, isNull);
    expect(tester.takeException(), isNull);
  });
}
