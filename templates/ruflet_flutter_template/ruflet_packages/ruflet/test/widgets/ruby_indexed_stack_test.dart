import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://indexed-stack-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {}
}

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

Map<String, dynamic> _text(int id, String value) =>
    {'_c': 'Text', '_i': id, 'value': value};

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('${platform.name}: IndexedStack paints only the indexed child',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'IndexedStack',
        '_i': 1,
        'index': 1,
        'width': 200,
        'height': 120,
        'controls': [
          _text(2, 'One'),
          {
            '_c': 'Container',
            '_i': 3,
            'width': 80,
            'height': 40,
            'content': _text(4, 'Two'),
          },
          _text(5, 'Three'),
        ],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      // Only the indexed child is on stage; the others stay mounted offstage.
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('One'), findsNothing);
      expect(find.text('Three'), findsNothing);
      expect(find.text('One', skipOffstage: false), findsOneWidget);
      expect(find.text('Three', skipOffstage: false), findsOneWidget);

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 1);
      expect(stack.alignment, AlignmentDirectional.topStart);
      expect(stack.sizing, StackFit.loose);
      expect(stack.clipBehavior, Clip.hardEdge);
      expect(tester.getSize(find.byType(IndexedStack)), const Size(200, 120));
      // Default alignment is topStart: the 80x40 child sits at the stack origin.
      expect(tester.getTopLeft(find.text('Two')),
          tester.getTopLeft(find.byType(IndexedStack)));
    });

    testWidgets('${platform.name}: IndexedStack forwards alignment/fit/clip',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'IndexedStack',
        '_i': 1,
        'width': 200,
        'height': 100,
        'alignment': {'x': 1, 'y': 1},
        'fit': 'expand',
        'clip_behavior': 'none',
        'controls': [_text(2, 'One')],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 0);
      expect(stack.alignment, const Alignment(1, 1));
      expect(stack.sizing, StackFit.expand);
      expect(stack.clipBehavior, Clip.none);
      // fit: expand forces the child to the stack's full size.
      expect(tester.getSize(find.text('One')), const Size(200, 100));
    });

    testWidgets('${platform.name}: IndexedStack keeps child state across index',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'IndexedStack',
        '_i': 1,
        'index': 0,
        'width': 300,
        'height': 200,
        'controls': [
          {'_c': 'TextField', '_i': 2, 'value': ''},
          _text(3, 'Second tab'),
        ],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));

      await tester.enterText(find.byType(EditableText), 'typed by user');
      await tester.pump();
      final stateBefore =
          tester.state<EditableTextState>(find.byType(EditableText));

      backend.updateControl(1, {'index': 1}, notify: true);
      await tester.pump();
      expect(find.text('Second tab'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(EditableText, skipOffstage: false), findsOneWidget);

      backend.updateControl(1, {'index': 0}, notify: true);
      await tester.pump();
      expect(find.text('Second tab'), findsNothing);
      final stateAfter =
          tester.state<EditableTextState>(find.byType(EditableText));
      expect(identical(stateBefore, stateAfter), isTrue,
          reason: 'the hidden child must stay mounted, not be rebuilt');
      expect(stateAfter.textEditingValue.text, 'typed by user');
      expect(tester.takeException(), isNull);
    });

    testWidgets('${platform.name}: IndexedStack clamps out-of-range index',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'IndexedStack',
        '_i': 1,
        'index': 7,
        'controls': [_text(2, 'One'), _text(3, 'Two')],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      expect(tester.takeException(), isNull);
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('One'), findsNothing);

      backend.updateControl(1, {'index': -3}, notify: true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsNothing);
    });

    testWidgets('${platform.name}: hidden children keep their index slot',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'IndexedStack',
        '_i': 1,
        'index': 2,
        'controls': [
          _text(2, 'One'),
          {'_c': 'Text', '_i': 3, 'value': 'Hidden', 'visible': false},
          _text(4, 'Three'),
        ],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      expect(tester.takeException(), isNull);
      // Index 2 still addresses the third child although the second is hidden.
      expect(find.text('Three'), findsOneWidget);
      expect(find.text('Hidden', skipOffstage: false), findsNothing);

      backend.updateControl(1, {'index': 1}, notify: true);
      await tester.pump();
      expect(find.text('Hidden', skipOffstage: false), findsNothing);
      expect(find.text('One'), findsNothing);
      expect(find.text('Three'), findsNothing);
    });

    testWidgets('${platform.name}: empty IndexedStack renders nothing',
        (tester) async {
      final backend = _Backend(platform);
      final control =
          Control.fromMap({'_c': 'IndexedStack', '_i': 1, 'index': 3}, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      expect(find.byType(IndexedStack), findsOneWidget);
    });
  }
}
