// The iOS sliding segmented control is selected by Ruby's declared `sliding`
// property (cupertino_sliding_segmented_button sends sliding: true on the
// canonical SegmentedButton wire type), never by a Cupertino wire name.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/control_type.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://sliding'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  final events = <(int, String, dynamic)>[];

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    if (control.get("on_$eventName") == true) {
      events.add((control.id, eventName, eventData));
    }
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

Map<String, dynamic> _segmented(String wire, Map<String, dynamic> props) => {
      '_c': wire,
      '_i': 2000,
      'selected_index': 0,
      'on_change': true,
      'controls': [
        {'_c': 'Text', '_i': 2001, 'value': 'One'},
        {'_c': 'Text', '_i': 2002, 'value': 'Two'},
      ],
      ...props,
    };

Future<(_Backend, Control)> _pump(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> wire) async {
  final backend = _Backend(platform);
  final control = Control.fromMap(wire, backend);
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(
            home: Align(
                alignment: Alignment.topLeft,
                child: ControlWidget(control: control)))
        : material.MaterialApp(
            home: material.Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: ControlWidget(control: control)))),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return (backend, control);
}

void main() {
  testWidgets('iOS renders the sliding control for sliding: true',
      (tester) async {
    final (backend, _) = await _pump(tester, TargetPlatform.iOS,
        _segmented('SegmentedButton', {'sliding': true}));
    final sliding = find.byType(CupertinoSlidingSegmentedControl<int>);
    expect(sliding, findsOneWidget);
    expect(find.byType(CupertinoSegmentedControl<int>), findsNothing);
    // Both segments sit side by side inside the sliding control's track.
    final track = tester.getRect(sliding);
    final one = tester.getRect(find.text('One'));
    final two = tester.getRect(find.text('Two'));
    expect(track.contains(one.center) && track.contains(two.center), isTrue);
    expect(two.left, greaterThan(one.right));
    expect(one.center.dy, moreOrLessEquals(two.center.dy));

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(backend.events, [(2000, 'change', 1)]);
  });

  testWidgets('iOS renders the segmented control without sliding',
      (tester) async {
    await _pump(tester, TargetPlatform.iOS, _segmented('SegmentedButton', {}));
    expect(find.byType(CupertinoSegmentedControl<int>), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);
  });

  testWidgets(
      'the legacy CupertinoSlidingSegmentedButton wire name implies '
      'sliding', (tester) async {
    final (_, control) = await _pump(tester, TargetPlatform.iOS,
        _segmented('CupertinoSlidingSegmentedButton', {}));
    expect(control.get('sliding'), isTrue);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsOneWidget);
  });

  testWidgets('an explicit sliding: false wins over the legacy alias',
      (tester) async {
    await _pump(tester, TargetPlatform.iOS,
        _segmented('CupertinoSlidingSegmentedButton', {'sliding': false}));
    expect(find.byType(CupertinoSegmentedControl<int>), findsOneWidget);
  });

  testWidgets('Material has no sliding variant: SegmentedButton',
      (tester) async {
    await _pump(tester, TargetPlatform.android,
        _segmented('SegmentedButton', {'sliding': true}));
    expect(find.byType(material.SegmentedButton<String>), findsOneWidget);
  });

  test('alias properties are exposed for the canonical renderers', () {
    expect(controlTypeAliasProperties('CupertinoSlidingSegmentedButton'),
        {'sliding': true});
    expect(controlTypeAliasProperties('SegmentedButton'), isEmpty);
  });

  // Ruby's canonical segmented_button sends `segments` and `selected`;
  // sliding: true must render those too, not only the legacy `controls`.
  Map<String, dynamic> canonical(Map<String, dynamic> props) => {
        '_c': 'SegmentedButton',
        '_i': 2010,
        'on_change': true,
        'sliding': true,
        'selected': ['day'],
        'segments': [
          {'_c': 'Segment', '_i': 2011, 'value': 'day', 'label': 'Day'},
          {'_c': 'Segment', '_i': 2012, 'value': 'week', 'label': 'Week'},
          {
            '_c': 'Segment',
            '_i': 2013,
            'value': 'month',
            'label': 'Month',
            'disabled': true
          },
        ],
        ...props,
      };

  testWidgets('iOS slides between canonical segments', (tester) async {
    final (backend, control) =
        await _pump(tester, TargetPlatform.iOS, canonical({}));
    expect(find.byType(ErrorControl), findsNothing);
    final sliding = tester.widget<CupertinoSlidingSegmentedControl<String>>(
        find.byType(CupertinoSlidingSegmentedControl<String>));
    expect(sliding.groupValue, 'day');
    expect(sliding.children.keys, ['day', 'week', 'month']);
    expect(sliding.disabledChildren, {'month'});

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(control.get('selected'), ['week']);
    expect(backend.events, hasLength(1));
    final (id, name, data) = backend.events.single;
    expect((id, name), (2010, 'change'));
    expect(data, ['week']);

    // A disabled segment is not picked.
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(control.get('selected'), ['week']);
    expect(backend.events, hasLength(1));
  });

  testWidgets('iOS sliding needs two visible canonical segments',
      (tester) async {
    await _pump(
        tester,
        TargetPlatform.iOS,
        canonical({
          'segments': [
            {'_c': 'Segment', '_i': 2011, 'value': 'day', 'label': 'Day'},
            {
              '_c': 'Segment',
              '_i': 2012,
              'value': 'week',
              'label': 'Week',
              'visible': false
            },
          ],
        }));
    expect(find.byType(ErrorControl), findsOneWidget);
  });
}
