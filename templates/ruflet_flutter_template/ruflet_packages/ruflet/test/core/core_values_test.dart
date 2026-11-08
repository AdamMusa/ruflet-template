import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/src/core/control_spec.dart';
import 'package:ruflet/src/core/core_semantics.dart';
import 'package:ruflet/src/core/raw_prop.dart';
import 'package:ruflet/src/core/text_or_widget.dart';

void main() {
  group('ControlSpec', () {
    const spec = ControlSpec(wireType: 'Toggle', props: [
      PropSpec('value', PropType.boolean, 'value'),
      PropSpec('label', PropType.textOrWidget, 'label',
          consumer: PropConsumer.core),
      PropSpec('hover_color', PropType.color, 'hoverColor',
          skins: {Skin.material}, reason: 'no hover ink on iOS'),
    ], events: [
      EventSpec('change', source: EventSource.core),
      EventSpec('click', field: 'onClick', whileDisabled: true),
    ], methods: [
      MethodSpec('focus'),
      MethodSpec('animate_to', args: ['index'], port: true),
    ], ownedLayoutKeys: {
      'margin'
    }, sharedLayoutKeys: {
      'width'
    }, children: {
      'items':
          ControlSpec(wireType: 'Item', props: [], layout: LayoutWrap.none),
    });

    test('looks up declarations', () {
      expect(spec.prop('value')?.type, PropType.boolean);
      expect(spec.prop('nope'), isNull);
      expect(spec.event('click')?.field, 'onClick');
      expect(spec.event('nope'), isNull);
      expect(spec.declaresMethod('focus'), isTrue);
      expect(spec.declaresMethod('blur'), isFalse);
    });

    test('serializes to plain data', () {
      expect(spec.toJson(), {
        'wire_type': 'Toggle',
        'layout': 'layout',
        'props': [
          {
            'key': 'value',
            'type': 'boolean',
            'field': 'value',
            'skins': ['material', 'cupertino']
          },
          {
            'key': 'label',
            'type': 'textOrWidget',
            'field': 'label',
            'skins': ['material', 'cupertino'],
            'consumer': 'core'
          },
          {
            'key': 'hover_color',
            'type': 'color',
            'field': 'hoverColor',
            'skins': ['material'],
            'reason': 'no hover ink on iOS'
          },
        ],
        'events': [
          {
            'name': 'change',
            'source': 'core',
            'skins': ['material', 'cupertino']
          },
          {
            'name': 'click',
            'source': 'skin',
            'field': 'onClick',
            'skins': ['material', 'cupertino'],
            'while_disabled': true
          },
        ],
        'methods': [
          {'name': 'focus'},
          {
            'name': 'animate_to',
            'args': ['index'],
            'port': true
          },
        ],
        'owned_layout_keys': ['margin'],
        'shared_layout_keys': ['width'],
        'children': {
          'items': {
            'wire_type': 'Item',
            'layout': 'none',
            'props': [],
            'events': [],
            'methods': []
          },
        },
      });
    });
  });

  test('RawProp carries the key and the wire value', () {
    const density = RawProp('visual_density', 'compact');
    expect(density.isSet, isTrue);
    expect(density.string, 'compact');
    expect(const RawProp('x', 3).string, '3');
    expect(const RawProp('x', null).isSet, isFalse);
    expect(density, const RawProp('visual_density', 'compact'));
    expect(density, isNot(const RawProp('visual_density', 'standard')));
  });

  testWidgets('TextOrWidget styles plain text only', (tester) async {
    const style = TextStyle(fontSize: 21);
    final text = const TextOrWidget.text('On').build(style: style) as Text;
    expect(text.data, 'On');
    expect(text.style, style);
    const child = SizedBox(key: ValueKey('child'));
    expect(const TextOrWidget.widget(child).build(style: style), same(child));
    expect(const TextOrWidget.text('').isEmptyText, isTrue);
    expect(const TextOrWidget.widget(child).isEmptyText, isFalse);
  });

  testWidgets('CoreSemantics adds only what it is given', (tester) async {
    const child = SizedBox(key: ValueKey('child'), width: 10, height: 10);
    await tester.pumpWidget(const CoreSemantics(child: child));
    expect(find.byType(Semantics), findsNothing);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: CoreSemantics(
            label: 'Alert',
            namesRoute: true,
            scopesRoute: true,
            child: child)));
    final node = tester.getSemantics(find.byType(CoreSemantics));
    expect(node.label, 'Alert');
    expect(node.getSemanticsData().flagsCollection.toStrings(),
        containsAll(['scopesRoute', 'namesRoute']));
    handle.dispose();
  });
}
