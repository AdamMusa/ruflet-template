import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://text-field-border-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
      {bool dart = true, bool python = true, bool notify = false}) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

final _native = const CupertinoTextField().decoration!;
final _nativeSide = (_native.border! as Border).top;

Future<void> _pump(WidgetTester tester, TargetPlatform platform,
    List<Map<String, dynamic>> fields) async {
  final backend = _Backend(platform);
  var id = 100;
  final controls = [
    for (final props in fields)
      Control.fromMap({'_c': 'TextField', '_i': ++id, 'value': 'Ada', ...props},
          backend)
  ];
  // A grouped-list row background, like FormRow/ListSection on iOS.
  final body = Container(
    color: const Color(0xFFEFEFF4),
    alignment: Alignment.topLeft,
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
}

CupertinoTextField _field(WidgetTester tester, int index) =>
    tester.widget<CupertinoTextField>(find.byType(CupertinoTextField).at(index));

Rect _fieldRect(WidgetTester tester, int index) =>
    tester.getRect(find.byType(CupertinoTextField).at(index));

Rect _textRect(WidgetTester tester, int index) =>
    tester.getRect(find.byType(EditableText).at(index));

/// Every decoration actually painted inside the [index]th field.
List<BoxDecoration> _painted(WidgetTester tester, int index) => tester
    .widgetList<DecoratedBox>(find.descendant(
        of: find.byType(CupertinoTextField).at(index),
        matching: find.byType(DecoratedBox)))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.border != null || d.color != null)
    .toList();

void main() {
  group('Cupertino TextField border', () {
    testWidgets('border: "none" paints no decoration and keeps geometry',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {},
        {'border': 'none'},
        {'border': 'none', 'disabled': true},
      ]);

      // Absent border keeps the native rounded field.
      expect(_field(tester, 0).decoration, _native);
      expect(_painted(tester, 0), isNotEmpty);

      // none: no border, no fill, no disabled background box.
      expect(_field(tester, 1).decoration, isNull);
      expect(_painted(tester, 1), isEmpty);
      expect(_field(tester, 2).decoration, isNull);
      expect(_painted(tester, 2), isEmpty);

      // Same field size and text inset as the native field: the decoration
      // never contributed layout, only paint.
      expect(_fieldRect(tester, 1).size, _fieldRect(tester, 0).size);
      expect(_textRect(tester, 1).left - _fieldRect(tester, 1).left, 7);
      expect(_textRect(tester, 1).left - _fieldRect(tester, 1).left,
          _textRect(tester, 0).left - _fieldRect(tester, 0).left);
      expect(tester.takeException(), isNull);
    });

    testWidgets('border: "none" still paints an explicit background',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {'border': 'none', 'bgcolor': '#ff0000'},
        {'border': 'none', 'filled': true},
        {'border': 'none', 'filled': true, 'fill_color': '#00ff00'},
      ]);

      final bg = _field(tester, 0).decoration!;
      expect(bg.border, isNull);
      expect(bg.color, const Color(0xFFFF0000));
      expect(bg.borderRadius, _native.borderRadius);

      expect(_field(tester, 1).decoration!.color,
          CupertinoColors.tertiarySystemFill);
      expect(_field(tester, 1).decoration!.border, isNull);
      expect(_field(tester, 2).decoration!.color, const Color(0xFF00FF00));
    });

    testWidgets('border: "outline" uses the native hairline unless styled',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {'border': 'outline'},
        {'border': 'outline', 'border_color': '#ff0000', 'border_width': 2},
        {'border': 'outline', 'border_width': 0},
        {'border': 'outline', 'border_radius': 12},
      ]);

      final native = _field(tester, 0).decoration!;
      expect(native.border, Border.all(color: _nativeSide.color, width: 0));
      expect(native.borderRadius, _native.borderRadius);
      expect(native.color, _native.color);

      expect(_field(tester, 1).decoration!.border,
          Border.all(color: const Color(0xFFFF0000), width: 2));
      expect(_field(tester, 2).decoration!.border, isNull);
      expect(_field(tester, 3).decoration!.borderRadius,
          BorderRadius.circular(12));

      // Like any BoxDecoration border, a 2 dp border insets the content: the
      // field grows by 2 dp at the top and bottom (the hairline adds none).
      expect(_fieldRect(tester, 1).height, _fieldRect(tester, 0).height + 4);
      expect(_textRect(tester, 1).left - _fieldRect(tester, 1).left, 7 + 2);
    });

    testWidgets('border: "underline" draws only a bottom rule, unfilled',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {'border': 'underline'},
        {'border': 'underline', 'border_color': '#0000ff', 'border_width': 1},
        {'border': 'underline', 'filled': true},
      ]);

      final underline = _field(tester, 0).decoration!;
      expect(underline.border, Border(bottom: _nativeSide.copyWith(width: 0)));
      expect(underline.borderRadius, BorderRadius.zero);
      expect(underline.color, isNull);

      expect(_field(tester, 1).decoration!.border,
          const Border(bottom: BorderSide(color: Color(0xFF0000FF), width: 1)));
      expect(_field(tester, 2).decoration!.color,
          CupertinoColors.tertiarySystemFill);
      // Only the bottom rule insets the content (1 dp vs the hairline).
      expect(_fieldRect(tester, 1).height, _fieldRect(tester, 0).height + 1);
      expect(_textRect(tester, 1).left - _fieldRect(tester, 1).left, 7);
    });

    testWidgets('a border map is still honored on the native field',
        (tester) async {
      await _pump(tester, TargetPlatform.iOS, [
        {
          'border': {
            'bottom': {'color': '#ff0000', 'width': 3}
          },
        },
      ]);

      final decoration = _field(tester, 0).decoration!;
      expect((decoration.border! as Border).bottom.width, 3);
      expect((decoration.border! as Border).bottom.color,
          const Color(0xFFFF0000));
      expect((decoration.border! as Border).top, BorderSide.none);
      expect(decoration.color, _native.color);
    });
  });

  testWidgets('Material TextField borders are unchanged', (tester) async {
    await _pump(tester, TargetPlatform.android, [
      {},
      {'border': 'outline'},
      {'border': 'underline'},
      {'border': 'none'},
      {'border': 'none', 'filled': true, 'fill_color': '#00ff00'},
    ]);

    material.InputDecoration decoration(int index) => tester
        .widget<material.InputDecorator>(
            find.byType(material.InputDecorator).at(index))
        .decoration;

    expect(find.byType(CupertinoTextField), findsNothing);
    expect(decoration(0).border, isA<material.OutlineInputBorder>());
    expect(decoration(1).border, isA<material.OutlineInputBorder>());
    expect(decoration(2).border, isA<material.UnderlineInputBorder>());
    expect(decoration(3).border, material.InputBorder.none);
    expect(decoration(4).filled, isTrue);
    expect(decoration(4).fillColor, const Color(0xFF00FF00));
    expect(tester.takeException(), isNull);
  });
}
