// A test-only control built on the shared core ("CoreProbe"), registered
// through a RufletExtension so it renders through the real ControlWidget
// path. Its two "skins" are the same design-neutral widget, keyed
// `probe_<design>` so tests can tell which one was selected.
import 'package:flutter/widgets.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/core/control_core.dart';
import 'package:ruflet/src/core/control_spec.dart';
import 'package:ruflet/src/core/text_or_widget.dart';
import 'package:ruflet/src/core/raw_prop.dart';

const probeSpec = ControlSpec(
  wireType: 'CoreProbe',
  props: [
    PropSpec('value', PropType.boolean, 'value'),
    PropSpec('count', PropType.integer, 'count'),
    PropSpec('caption', PropType.textOrWidget, 'caption'),
    PropSpec('tint', PropType.color, 'tint'),
    PropSpec('density', PropType.raw, 'density',
        skins: {Skin.material}, reason: 'probe: Material-only value'),
    PropSpec('width', PropType.number, 'width'),
  ],
  events: [
    EventSpec('change', source: EventSource.core),
    EventSpec('focus', source: EventSource.core),
    EventSpec('blur', source: EventSource.core),
    EventSpec('click', field: 'onClick'),
    EventSpec('long_press', field: 'onLongPress', whileDisabled: true),
  ],
  methods: [
    MethodSpec('echo', args: ['value']),
    MethodSpec('focus'),
    MethodSpec('blur'),
  ],
  ownedLayoutKeys: {'width'},
);

@immutable
class ProbeProps {
  ProbeProps.parse(PropReader r, {bool forgetTint = false})
      : value = r.boolean('value'),
        count = r.integer('count'),
        caption = r.textOrWidget('caption'),
        tint = forgetTint ? null : r.color('tint'),
        density = r.raw('density'),
        width = r.number('width');

  final bool value;
  final int? count;
  final TextOrWidget? caption;
  final Color? tint;
  final RawProp density;
  final double? width;
}

/// Counts every lifecycle call so tests can assert on them.
class ProbeCore extends ControlCore<ProbeProps> with FocusableCore<ProbeProps> {
  ProbeCore(super.control) {
    created.add(this);
  }

  /// Every core the probe extension created, in order.
  static final List<ProbeCore> created = [];

  int parses = 0;
  int inits = 0;
  int rebinds = 0;
  int disposals = 0;
  int dependencyChanges = 0;
  ProbeProps? lastPrevious;

  @override
  ControlSpec get spec => probeSpec;

  @override
  ProbeProps parse(PropReader r) {
    parses++;
    return ProbeProps.parse(r);
  }

  @override
  void didParse(ProbeProps? previous) {
    lastPrevious = previous;
    super.didParse(previous);
  }

  @override
  void initCore() {
    inits++;
    super.initCore();
  }

  @override
  void didRebind() {
    rebinds++;
    super.didRebind();
  }

  @override
  void didChangeDependencies(BuildContext context) {
    dependencyChanges++;
    super.didChangeDependencies(context);
  }

  @override
  void disposeCore() {
    disposals++;
    super.disposeCore();
  }

  @override
  Map<String, InvokeHandler> get methods => {
        ...super.methods,
        'echo': (args) => args['value'],
        // Handled but not declared in the spec: must never be dispatched.
        'undeclared_but_handled': (_) => 'leaked',
      };

  VoidCallback? get onClick => events.callback('click');
  ValueChanged<bool>? get onChanged => enabled ? commit : null;
  VoidCallback? get onLongPress =>
      events.callback('long_press', data: () => 'pressed');

  /// A value commit, as a toggle would do it.
  void commit(bool next) {
    writeBack({'value': next});
    events.fire('change', next);
  }

  /// Exposes markNeedsBuild for tests.
  void rebuild() => markNeedsBuild();

  /// Fires an event the spec does not declare (must assert).
  void fireUndeclared() => events.fire('undeclared');

  @override
  Widget decorate(BuildContext context, Widget skin) =>
      KeyedSubtree(key: const ValueKey('probe_decoration'), child: skin);
}

/// A parse that forgets a declared key (contract rule C6 must catch it).
class ForgetfulProbeCore extends ProbeCore {
  ForgetfulProbeCore(super.control);

  @override
  ProbeProps parse(PropReader r) {
    parses++;
    return ProbeProps.parse(r, forgetTint: true);
  }
}

/// The probe's "native" toggle: a pointer tap reports the flipped value.
class ProbeNative extends StatelessWidget {
  const ProbeNative({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: const SizedBox(width: 24, height: 24),
      );
}

class ProbeSkin extends StatelessWidget {
  const ProbeSkin(
      {super.key,
      required this.core,
      required this.design,
      this.invert = false});

  final ProbeCore core;
  final String design;

  /// A miswired skin (contract rule C7 must catch it).
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    final onChanged = core.onChanged;
    return Focus(
      key: ValueKey('probe_$design'),
      focusNode: core.focusNode,
      child: GestureDetector(
        onTap: core.onClick,
        onLongPress: core.onLongPress,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ProbeNative(
            value: p.value,
            onChanged: invert && onChanged != null
                ? (value) => onChanged(!value)
                : onChanged,
          ),
          Flexible(
            child: SizedBox(
              width: p.width,
              child: Text('${p.value}:${p.count}:${p.caption?.text ?? ''}'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Registers "CoreProbe" through the same extension path as real controls.
/// [invertMaterial] and [forgetful] build deliberately broken variants.
class ProbeExtension extends RufletExtension {
  ProbeExtension({this.invertMaterial = false, this.forgetful = false});

  final bool invertMaterial;
  final bool forgetful;

  @override
  Widget? createWidget(Key? key, Control control) {
    if (control.type != 'CoreProbe') return null;
    return CoreHost<ProbeCore>(
      key: ValueKey('control_${control.id}'),
      control: control,
      create: forgetful ? ForgetfulProbeCore.new : ProbeCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) =>
            ProbeSkin(core: core, design: 'material', invert: invertMaterial),
        cupertino: (_) => ProbeSkin(core: core, design: 'cupertino'),
      ),
    );
  }
}
