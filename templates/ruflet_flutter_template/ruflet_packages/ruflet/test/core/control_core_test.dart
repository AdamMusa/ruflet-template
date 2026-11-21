import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/core/control_core.dart';
import 'package:ruflet/src/core/control_spec.dart';
import 'package:ruflet/src/core/raw_prop.dart';
import 'package:ruflet/src/core/text_or_widget.dart';

import '../support/control_harness.dart';
import '../support/core_contract.dart' show sampleValue;
import '../support/core_probe.dart';

Map<String, dynamic> _probe(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 200,
      'controls': [
        {'_c': 'CoreProbe', '_i': 201, ...props}
      ],
    };

Finder get _host => find.byWidgetPredicate((w) => w is CoreHost);

Future<HarnessMount> _mount(WidgetTester tester, Map<String, dynamic> props,
        {HarnessDesign design = HarnessDesign.android,
        List<RufletExtension>? extensions}) =>
    mountWire(tester, design, _probe(props),
        extensions: extensions ?? [ProbeExtension()]);

ProbeCore get _core => ProbeCore.created.last;

void main() {
  setUp(ProbeCore.created.clear);

  group('CoreHost', () {
    for (final design in HarnessDesign.values) {
      testWidgets('selects exactly one skin on ${design.name}', (tester) async {
        await _mount(tester, {'value': true, 'count': 3, 'caption': 'hi'},
            design: design);
        final skin = design == HarnessDesign.ios ? 'cupertino' : 'material';
        expect(find.byKey(ValueKey('probe_$skin')), findsOneWidget);
        expect(find.text('true:3:hi'), findsOneWidget);
        expect(find.byType(ProbeSkin), findsOneWidget);
      });
    }

    testWidgets('parses props once per build and passes the previous props',
        (tester) async {
      final mount = await _mount(tester, {'count': 3});
      final core = _core;
      expect(core.inits, 1);
      expect(core.parses, 1);
      expect(core.lastPrevious, isNull);
      expect(core.dependencyChanges, greaterThanOrEqualTo(1));

      mount.control(201).update({'count': 4}, shouldNotify: true);
      await tester.pump();
      expect(core.parses, 2);
      expect(core.lastPrevious?.count, 3);
      expect(core.props.count, 4);
      expect(ProbeCore.created, hasLength(1), reason: 'the core survives');
    });

    testWidgets('markNeedsBuild re-parses without a Ruby update',
        (tester) async {
      await _mount(tester, {});
      _core.rebuild();
      await tester.pump();
      expect(_core.parses, 2);
    });

    testWidgets('decorate wraps the selected skin', (tester) async {
      await _mount(tester, {});
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('probe_decoration')),
              matching: find.byType(ProbeSkin)),
          findsOneWidget);
    });

    testWidgets('wraps layout keywords once and skips owned keys',
        (tester) async {
      await _mount(tester, {'opacity': 0.5, 'width': 40.0});
      final layouts =
          find.descendant(of: _host, matching: find.byType(LayoutControl));
      expect(layouts, findsOneWidget);
      expect(tester.widget<LayoutControl>(layouts).skipProperties,
          probeSpec.ownedLayoutKeys);
      expect(
          find.ancestor(
              of: find.byType(ProbeSkin), matching: find.byType(Opacity)),
          findsOneWidget);
    });

    for (final wrap in LayoutWrap.values) {
      testWidgets('layout ${wrap.name} picks its wrapper', (tester) async {
        await mountWire(tester, HarnessDesign.android, {
          '_c': 'CoreWrap',
          '_i': 300,
          'opacity': 0.5
        }, extensions: [
          _InlineExtension('CoreWrap', (c) => _WrapCore(c, wrap))
        ]);
        expect(find.byType(LayoutControl),
            wrap == LayoutWrap.layout ? findsOneWidget : findsNothing);
        expect(find.byType(BaseControl),
            wrap == LayoutWrap.base ? findsOneWidget : findsNothing);
        expect(find.byType(Opacity),
            wrap == LayoutWrap.none ? findsNothing : findsOneWidget);
      });
    }

    testWidgets(
        'a core reads its canonical wire type, its parent\'s and its slot',
        (tester) async {
      await mountWire(tester, HarnessDesign.android, {
        '_c': 'Column',
        '_i': 360,
        'controls': [
          // An alias resolves to its canonical type.
          {'_c': 'ElevatedButton', '_i': 361},
        ],
      }, extensions: [
        _InlineExtension('ElevatedButton', _TypeCore.new)
      ]);
      expect(_TypeCore.last!.props, ('Button', 'Column', 'controls'));
    });

    testWidgets('a core reads a single-child slot too', (tester) async {
      await mountWire(tester, HarnessDesign.android, {
        '_c': 'Container',
        '_i': 365,
        'content': {'_c': 'ElevatedButton', '_i': 366},
      }, extensions: [
        _InlineExtension('ElevatedButton', _TypeCore.new)
      ]);
      expect(_TypeCore.last!.props, ('Button', 'Container', 'content'));
    });

    testWidgets('disposing unregisters the listener and disposes the core',
        (tester) async {
      final mount = await _mount(tester, {});
      final control = mount.control(201);
      final core = _core;
      core.focusNode; // created lazily; must be disposed with the core
      await tester.pumpWidget(
          harnessApp(mount.backend, HarnessDesign.android, const SizedBox()));
      expect(core.disposals, 1);
      expect(CoreHost.debugListenerCount(control), 0);
      expect((await invokeOutcome(tester, control, 'echo')).timedOut, isTrue);
    });
  });

  group('CoreHost.adopt (sized entries)', () {
    Map<String, dynamic> sized(Map<String, dynamic> props) => {
          '_c': 'Column',
          '_i': 330,
          'controls': [
            {'_c': 'CoreSized', '_i': 331, ...props}
          ],
        };
    Finder sizedHost() =>
        find.byWidgetPredicate((w) => w is CoreHost && w.debugControlId == 331);

    setUp(() {
      _SizedCore.created.clear();
      _SizedCore.hosted.clear();
    });

    testWidgets('a skin hosts the core its entry created', (tester) async {
      final mount = await mountWire(
          tester, HarnessDesign.android, sized({'height': 80.0}),
          extensions: [_SizedExtension()]);
      final control = mount.control(331);
      expect(sizedHost(), findsOneWidget);
      expect(find.text('sized 80.0'), findsOneWidget);
      expect(CoreHost.debugListenerCount(control), 1);
      expect(tester.widget<_SizedSkin>(find.byType(_SizedSkin)).preferredSize,
          const Size.fromHeight(80));

      // Each entry run creates a core; the host keeps the first one.
      final hosted = _SizedCore.created.single;
      control.update({'height': 90.0}, shouldNotify: true);
      await tester.pump();
      expect(_SizedCore.created, hasLength(2));
      expect(_SizedCore.hosted, [hosted]);
      expect(find.text('sized 90.0'), findsOneWidget);
      expect(tester.widget<_SizedSkin>(find.byType(_SizedSkin)).preferredSize,
          const Size.fromHeight(90));
      expect(CoreHost.debugListenerCount(control), 1);
    });

    testWidgets('an in-place replacement rebinds the adopted core',
        (tester) async {
      final mount = await mountWire(
          tester, HarnessDesign.ios, sized({'height': 80.0}),
          extensions: [_SizedExtension()]);
      final old = mount.control(331);
      final state = tester.state(sizedHost());
      final replacementRoot =
          Control.fromMap(copyWire(sized({'height': 60.0})), mount.backend);
      await tester.pumpWidget(harnessApp(mount.backend, HarnessDesign.ios,
          ControlWidget(control: replacementRoot)));
      final replacement = mount.control(331);
      expect(identical(tester.state(sizedHost()), state), isTrue);
      expect(CoreHost.debugListenerCount(old), 0);
      expect(CoreHost.debugListenerCount(replacement), 1);
      expect(find.text('sized 60.0'), findsOneWidget);

      await tester.pumpWidget(
          harnessApp(mount.backend, HarnessDesign.ios, const SizedBox()));
      expect(CoreHost.debugListenerCount(replacement), 0);
      expect(_SizedCore.hosted.single.disposals, 1);
    });

    testWidgets('peeks read declared keys before any build', (tester) async {
      final backend = HarnessBackend(HarnessDesign.android);
      final core = _SizedCore(Control.fromMap(
          {'_c': 'CoreSized', '_i': 340, 'tall': true, 'tint': '#ff0000'},
          backend));
      expect(core.tall, isTrue);
      expect(core.height, isNull);
      await tester.pumpWidget(Builder(builder: (context) {
        expect(core.tintIn(context), const Color(0xffff0000));
        return const SizedBox();
      }));
      expect(() => core.undeclared, throwsA(isA<AssertionError>()));
      expect(() => core.wrongType, throwsA(isA<AssertionError>()));
    });
  });

  group('invoke methods', () {
    testWidgets('a declared method is answered by the one listener',
        (tester) async {
      final mount = await _mount(tester, {});
      final control = mount.control(201);
      expect(CoreHost.debugListenerCount(control), 1);
      final outcome =
          await invokeOutcome(tester, control, 'echo', args: {'value': 5});
      // One listener: Control.invokeMethod returns the scalar, not a list.
      expect(outcome.value, 5);
    });

    testWidgets('nil args reach handlers as an empty map', (tester) async {
      final mount = await _mount(tester, {});
      final outcome = await invokeOutcome(tester, mount.control(201), 'echo');
      expect(outcome.error, isNull);
      expect(outcome.value, isNull);
    });

    testWidgets('an undeclared method fails fast even when the core has it',
        (tester) async {
      final mount = await _mount(tester, {});
      for (final name in ['undeclared_but_handled', 'nope']) {
        final outcome = await invokeOutcome(tester, mount.control(201), name);
        expect(outcome.unsupported, isTrue, reason: name);
        expect(
            (outcome.error as UnsupportedError).message,
            'CoreProbe(201).$name is not supported on android: no handler '
            'for "$name" is registered for this control');
      }
    });

    testWidgets('a declared method the core does not handle fails fast',
        (tester) async {
      final mount = await mountWire(
          tester, HarnessDesign.ios, {'_c': 'CoreUnhandled', '_i': 310},
          extensions: [_InlineExtension('CoreUnhandled', _UnhandledCore.new)]);
      final outcome =
          await invokeOutcome(tester, mount.control(310), 'declared');
      expect(outcome.unsupported, isTrue);
      expect((outcome.error as UnsupportedError).message, contains('on iOS'));
    });

    testWidgets('an in-place replacement moves the listener and the events',
        (tester) async {
      final mount = await _mount(tester, {'caption': 'old'});
      final old = mount.control(201);
      final state = tester.state(_host);
      final core = _core;

      // Ruby replaces the control with a new instance (same id) that, unlike
      // the old one, subscribes to change.
      final replacementRoot = Control.fromMap(
          copyWire(_probe({'caption': 'new', 'on_change': true})),
          mount.backend);
      await tester.pumpWidget(harnessApp(mount.backend, HarnessDesign.android,
          ControlWidget(control: replacementRoot)));
      final replacement = mount.control(201);

      expect(identical(tester.state(_host), state), isTrue);
      expect(ProbeCore.created, [core]);
      expect(core.rebinds, 1);
      expect(core.props.caption?.text, 'new');
      expect(CoreHost.debugListenerCount(old), 0);
      expect(CoreHost.debugListenerCount(replacement), 1);
      expect(
          (await invokeOutcome(tester, replacement, 'echo',
                  args: {'value': 'r'}))
              .value,
          'r');
      expect((await invokeOutcome(tester, old, 'echo')).timedOut, isTrue);

      mount.backend.sent.clear();
      core.commit(true);
      expect(mount.backend.sent.map((m) => m.toJson()), [
        {
          'id': 201,
          'update': {'value': true}
        },
        {'id': 201, 'event': 'change', 'data': true},
      ]);
      expect(replacement.get('value'), isTrue);
    });
  });

  group('ControlEvents', () {
    testWidgets('fires only subscribed events, after the write-back',
        (tester) async {
      final mount = await _mount(tester, {});
      _core.commit(true);
      expect(mount.backend.sent.map((m) => m.toJson()), [
        {
          'id': 201,
          'update': {'value': true}
        },
      ]);
    });

    testWidgets('gesture callbacks are null without a subscription',
        (tester) async {
      await _mount(tester, {});
      expect(_core.onClick, isNull);
      expect(_core.onLongPress, isNull);
    });

    testWidgets('gesture callbacks fire for subscribers', (tester) async {
      final mount =
          await _mount(tester, {'on_click': true, 'on_long_press': true});
      await tester.tap(find.byType(ProbeSkin));
      await tester.longPress(find.byType(ProbeSkin));
      expect(mount.backend.sent.map((m) => m.toJson()), [
        {'id': 201, 'event': 'click', 'data': null},
        {'id': 201, 'event': 'long_press', 'data': 'pressed'},
      ]);
    });

    testWidgets('disabled controls drop callbacks unless whileDisabled',
        (tester) async {
      await _mount(
          tester, {'disabled': true, 'on_click': true, 'on_long_press': true});
      expect(_core.disabled, isTrue);
      expect(_core.states, contains(WidgetState.disabled));
      expect(_core.onClick, isNull);
      expect(_core.onLongPress, isNotNull);
    });

    testWidgets('firing an undeclared event fails in debug', (tester) async {
      await _mount(tester, {});
      expect(() => _core.fireUndeclared(), throwsAssertionError);
    });
  });

  group('FocusableCore', () {
    testWidgets('focus and blur are the same events on every design',
        (tester) async {
      for (final design in HarnessDesign.values) {
        final mount = await _mount(tester, {'on_focus': true, 'on_blur': true},
            design: design);
        final control = mount.control(201);
        await invokeOutcome(tester, control, 'focus');
        await tester.pump();
        expect(_core.states, contains(WidgetState.focused));
        await invokeOutcome(tester, control, 'blur');
        await tester.pump();
        expect(_core.states, isNot(contains(WidgetState.focused)));
        expect(
            mount.backend.sent.where((m) => m.props == null).map((m) => m.name),
            ['focus', 'blur'],
            reason: design.name);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('PropReader', () {
    testWidgets('reads every PropType with its parser', (tester) async {
      var id = 400;
      final props = <String, dynamic>{
        for (final prop in _allTypesSpec.props)
          prop.key: sampleValue(prop.type, () => ++id),
        'enum_name': 'left',
        'optional': null,
        'items': [
          {'_c': 'CoreItem', '_i': 450, 'label': 'first'},
          {'_c': 'CoreItem', '_i': 451, 'label': 'second'},
        ],
      };
      CoreReadLog.clear();
      await mountWire(tester, HarnessDesign.android,
          {'_c': 'CoreAllTypes', '_i': 399, ...props},
          extensions: [_InlineExtension('CoreAllTypes', _AllTypesCore.new)]);
      expect(tester.takeException(), isNull);
      final v = _AllTypesCore.last!.props;
      expect(v['boolean'], isTrue);
      expect(v['optional'], isNull);
      expect(v['integer'], 2);
      expect(v['number'], 24.0);
      expect(v['string'], 'sample');
      expect(v['color'], const Color(0xff336699));
      expect(
          (v['state_color'] as WidgetStateProperty<Color?>)
              .resolve({WidgetState.selected}),
          const Color(0xff993366));
      expect(
          (v['state_number'] as WidgetStateProperty<double?>).resolve({}), 2.0);
      expect((v['state_icon'] as WidgetStateProperty<Icon?>).resolve({})?.icon,
          isNotNull);
      expect(
          (v['state_border_side'] as WidgetStateBorderSide).resolve({})?.width,
          2.0);
      expect((v['text_style'] as TextStyle).fontSize, 13.0);
      expect(v['edge_insets'], const EdgeInsets.all(4));
      expect(v['border_radius'], BorderRadius.circular(4));
      expect(v['outlined_border'], isA<RoundedRectangleBorder>());
      expect(v['alignment'], Alignment.center);
      expect(v['duration'], const Duration(milliseconds: 100));
      expect(v['animation'], isNotNull);
      expect(v['enum_name'], _Side.left);
      expect(v['icon'], isA<IconData>());
      expect(v['image'], isA<ImageProvider>());
      expect(v['mouse_cursor'], SystemMouseCursors.click);
      expect(v['widget'], isA<ControlWidget>());
      expect((v['text_or_widget'] as TextOrWidget).text, 'Sample');
      expect(v['icon_or_widget'], isA<Icon>());
      expect(v['widgets'], hasLength(1));
      expect(v['raw'], const RawProp('raw', 'sample'));
      expect(v['children'], ['first', 'second']);
      expect(CoreReadLog.keysRead('CoreAllTypes'),
          {for (final p in _allTypesSpec.props) p.key, 'items'});
    });

    testWidgets('text or widget accepts text, scalars and child controls',
        (tester) async {
      await _mount(tester, {'caption': 7});
      expect(_core.props.caption?.text, '7');
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, {
        'caption': {'_c': 'Text', '_i': 250, 'value': 'child'}
      });
      expect(_core.props.caption?.widget, isA<ControlWidget>());
      expect(find.text('child'), findsNothing,
          reason: 'the probe skin only prints caption text');
    });

    testWidgets('reading an undeclared key fails in debug', (tester) async {
      await mountWire(tester, HarnessDesign.android,
          {'_c': 'CoreSneaky', '_i': 320, 'secret': 'x'},
          extensions: [_InlineExtension('CoreSneaky', _SneakyCore.new)]);
      final error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect(
          '$error',
          contains(
              'reads "secret" as string but its ControlSpec does not declare it'));
    });

    testWidgets('raw values must be plain wire data, never a child control',
        (tester) async {
      await mountWire(tester, HarnessDesign.android, {
        '_c': 'CoreRaw',
        '_i': 340,
        'style': {
          'nested': [
            1,
            'two',
            {'three': 3}
          ]
        },
      }, extensions: [
        _InlineExtension('CoreRaw', _RawCore.new)
      ]);
      expect(tester.takeException(), isNull);
      expect(
          _RawCore.last!.props,
          const RawProp('style', {
            'nested': [
              1,
              'two',
              {'three': 3}
            ]
          }));

      await mountWire(tester, HarnessDesign.android, {
        '_c': 'CoreRaw',
        '_i': 342,
        'style': {
          'nested': [
            {'_c': 'Text', '_i': 343, 'value': 'leak'}
          ]
        },
      }, extensions: [
        _InlineExtension('CoreRaw', _RawCore.new)
      ]);
      expect('${tester.takeException()}',
          contains('CoreRaw.style holds a child control'));
    });

    testWidgets('reading a declared key as another type fails in debug',
        (tester) async {
      await mountWire(tester, HarnessDesign.android,
          {'_c': 'CoreWrongType', '_i': 330, 'count': 1},
          extensions: [_InlineExtension('CoreWrongType', _WrongTypeCore.new)]);
      expect('${tester.takeException()}', contains('reads "count" as number'));
    });
  });
}

// ---------------------------------------------------------------- inline cores

class _InlineExtension extends RufletExtension {
  _InlineExtension(this.type, this.create);
  final String type;
  final ControlCore Function(Control control) create;

  @override
  Widget? createWidget(Key? key, Control control) => control.type != type
      ? null
      : CoreHost<ControlCore>(
          key: ValueKey('control_${control.id}'),
          control: control,
          create: create,
          builder: (context, core) => Text('$type skin'),
        );
}

class _WrapCore extends ControlCore<Object> {
  _WrapCore(super.control, this.wrap);
  final LayoutWrap wrap;

  @override
  ControlSpec get spec =>
      ControlSpec(wireType: 'CoreWrap', props: const [], layout: wrap);

  @override
  Object parse(PropReader r) => const Object();
}

class _TypeCore extends ControlCore<(String, String?, String?)> {
  _TypeCore(super.control) {
    last = this;
  }

  static _TypeCore? last;

  @override
  ControlSpec get spec => const ControlSpec(wireType: 'Button', props: []);

  @override
  (String, String?, String?) parse(PropReader r) =>
      (wireType, parentWireType, parentSlot);
}

class _UnhandledCore extends ControlCore<Object> {
  _UnhandledCore(super.control);

  @override
  ControlSpec get spec => const ControlSpec(
      wireType: 'CoreUnhandled', props: [], methods: [MethodSpec('declared')]);

  @override
  Object parse(PropReader r) => const Object();
}

class _SneakyCore extends ControlCore<Object> {
  _SneakyCore(super.control);

  @override
  ControlSpec get spec => const ControlSpec(wireType: 'CoreSneaky', props: []);

  @override
  Object parse(PropReader r) => r.string('secret') ?? '';
}

class _WrongTypeCore extends ControlCore<Object> {
  _WrongTypeCore(super.control);

  @override
  ControlSpec get spec => const ControlSpec(
      wireType: 'CoreWrongType',
      props: [PropSpec('count', PropType.integer, 'count')]);

  @override
  Object parse(PropReader r) => r.number('count') ?? 0;
}

class _RawCore extends ControlCore<RawProp> {
  _RawCore(super.control) {
    last = this;
  }

  static _RawCore? last;

  @override
  ControlSpec get spec => const ControlSpec(
      wireType: 'CoreRaw', props: [PropSpec('style', PropType.raw, 'style')]);

  @override
  RawProp parse(PropReader r) => r.raw('style');
}

enum _Side { right, left }

const _allTypesSpec = ControlSpec(wireType: 'CoreAllTypes', props: [
  PropSpec('boolean', PropType.boolean, 'boolean'),
  PropSpec('optional', PropType.boolean, 'optional'),
  PropSpec('integer', PropType.integer, 'integer'),
  PropSpec('number', PropType.number, 'number'),
  PropSpec('string', PropType.string, 'string'),
  PropSpec('color', PropType.color, 'color'),
  PropSpec('state_color', PropType.stateColor, 'stateColor'),
  PropSpec('state_number', PropType.stateNumber, 'stateNumber'),
  PropSpec('state_icon', PropType.stateIcon, 'stateIcon'),
  PropSpec('state_border_side', PropType.stateBorderSide, 'stateBorderSide'),
  PropSpec('text_style', PropType.textStyle, 'textStyle'),
  PropSpec('edge_insets', PropType.edgeInsets, 'edgeInsets'),
  PropSpec('border_radius', PropType.borderRadius, 'borderRadius'),
  PropSpec('outlined_border', PropType.outlinedBorder, 'outlinedBorder'),
  PropSpec('alignment', PropType.alignment, 'alignment'),
  PropSpec('duration', PropType.duration, 'duration'),
  PropSpec('animation', PropType.animation, 'animation'),
  PropSpec('enum_name', PropType.enumName, 'enumName'),
  PropSpec('icon', PropType.icon, 'icon'),
  PropSpec('image', PropType.image, 'image'),
  PropSpec('mouse_cursor', PropType.mouseCursor, 'mouseCursor'),
  PropSpec('widget', PropType.widget, 'widget'),
  PropSpec('text_or_widget', PropType.textOrWidget, 'textOrWidget'),
  PropSpec('icon_or_widget', PropType.iconOrWidget, 'iconOrWidget'),
  PropSpec('widgets', PropType.widgets, 'widgets'),
  PropSpec('raw', PropType.raw, 'raw'),
], children: {
  'items': ControlSpec(wireType: 'CoreItem', props: [
    PropSpec('label', PropType.string, 'label'),
  ]),
});

class _AllTypesCore extends ControlCore<Map<String, Object?>> {
  _AllTypesCore(super.control) {
    last = this;
  }

  static _AllTypesCore? last;

  @override
  ControlSpec get spec => _allTypesSpec;

  @override
  Map<String, Object?> parse(PropReader r) => {
        'boolean': r.boolean('boolean'),
        'optional': r.optionalBoolean('optional'),
        'integer': r.integer('integer'),
        'number': r.number('number'),
        'string': r.string('string'),
        'color': r.color('color'),
        'state_color': r.stateColor('state_color'),
        'state_number': r.stateNumber('state_number'),
        'state_icon': r.stateIcon('state_icon'),
        'state_border_side': r.stateBorderSide('state_border_side'),
        'text_style': r.textStyle('text_style'),
        'edge_insets': r.edgeInsets('edge_insets'),
        'border_radius': r.borderRadius('border_radius'),
        'outlined_border': r.outlinedBorder('outlined_border'),
        'alignment': r.alignment('alignment'),
        'duration': r.duration('duration'),
        'animation': r.animation('animation'),
        'enum_name': r.enumValue(_Side.values, 'enum_name', _Side.right),
        'icon': r.icon('icon'),
        'image': r.image('image'),
        'mouse_cursor': r.mouseCursor('mouse_cursor'),
        'widget': r.widget('widget'),
        'text_or_widget': r.textOrWidget('text_or_widget'),
        'icon_or_widget': r.iconOrWidget('icon_or_widget'),
        'widgets': r.widgets('widgets'),
        'raw': r.raw('raw'),
        'children': [
          for (final child in r.children('items')) child.string('label')
        ],
      };
}

class _SizedCore extends ControlCore<(double?,)> {
  _SizedCore(super.control) {
    created.add(this);
  }

  static final List<_SizedCore> created = [];
  static final List<_SizedCore> hosted = [];
  int disposals = 0;

  @override
  ControlSpec get spec => const ControlSpec(wireType: 'CoreSized', props: [
        PropSpec('height', PropType.number, 'height'),
        PropSpec('tall', PropType.boolean, 'tall'),
        PropSpec('tint', PropType.color, 'tint'),
      ]);

  @override
  (double?,) parse(PropReader r) {
    r.boolean('tall');
    r.color('tint');
    return (r.number('height'),);
  }

  @override
  void initCore() {
    hosted.add(this);
    super.initCore();
  }

  @override
  void disposeCore() {
    disposals++;
    super.disposeCore();
  }

  bool get tall => peekBoolean('tall');
  double? get height => peekNumber('height');
  Color? tintIn(BuildContext context) => peekColor('tint', context);
  bool get undeclared => peekBoolean('nope');
  double? get wrongType => peekNumber('tall');
}

/// A skin that is the outermost widget (a scaffold reads its size before
/// building it) and hosts its entry's core.
class _SizedSkin extends StatelessWidget implements PreferredSizeWidget {
  const _SizedSkin({required this.core});
  final _SizedCore core;

  @override
  Size get preferredSize => Size.fromHeight(core.height ?? 0);

  @override
  Widget build(BuildContext context) => CoreHost<_SizedCore>.adopt(
      core: core, builder: (context, core) => Text('sized ${core.props.$1}'));
}

class _SizedExtension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) => control.type == 'CoreSized'
      ? _SizedSkin(core: _SizedCore(control))
      : null;
}
