part of 'control_core.dart';

/// Invoke listeners each live host registered, per Control object.
final Expando<int> _hostedListeners = Expando<int>('CoreHost listeners');

/// Mounts a [ControlCore] for a control: the single owner of its invoke
/// listener, its props parse and its common layout keywords.
///
/// The registry entry builds it, and [builder] must return a
/// `PlatformControlRenderer` whose two closures build the skins: the
/// architecture checker only proves design boundaries through that literal
/// dispatcher, so the dispatch is never hidden in here.
class CoreHost<C extends ControlCore> extends StatefulWidget {
  const CoreHost({
    super.key,
    required Control control,
    required C Function(Control control) create,
    required this.builder,
  })  : _control = control,
        _create = create;

  /// Hosts a [core] the registry entry created, from inside the skin it
  /// handed that core to. Only for controls whose skin must be the outermost
  /// widget: a scaffold reads an app bar's `PreferredSizeWidget` metrics
  /// (and, on iOS, whether it fully obstructs the content) from the widget
  /// it is handed, before building it, so the entry returns the skin itself
  /// and the skin builds this host around its native widget. The host's
  /// duties are those of [CoreHost]: it parses the props, applies the layout
  /// wrapper and owns the one invoke listener.
  ///
  /// The entry creates a core each time it runs. The host keeps the first one
  /// for its lifetime (a Control Ruby replaced in place rebinds it, as usual),
  /// so a skin builds from the builder's `core` and uses the core it was
  /// handed only for the values a parent reads before the build
  /// ([ControlCore.peekBoolean] and friends).
  CoreHost.adopt({super.key, required C core, required this.builder})
      : _control = core._control,
        _create = ((_) => core);

  /// Library-private like [ControlCore]'s: a skin can construct a host
  /// ([CoreHost.adopt]) or find its ancestor host, and must not reach the
  /// Control through it.
  final Control _control;
  final C Function(Control control) _create;
  final Widget Function(BuildContext context, C core) builder;

  /// The id of the Control this host serves (the Control itself stays
  /// private to the kernel).
  @visibleForTesting
  int get debugControlId => _control.id;

  /// Invoke listeners that mounted hosts hold on [control] (test support for
  /// the "exactly one listener" contract).
  @visibleForTesting
  static int debugListenerCount(Control control) =>
      _hostedListeners[control] ?? 0;

  /// A method name a host answers with [debugCensusReply] in debug builds,
  /// so a test can count every invoke listener on a Control:
  /// `Control.invokeMethod` returns one result per listener, a list when
  /// there are several, and a foreign listener that rejects the name fails
  /// the call. Release builds treat it like any undeclared method.
  @visibleForTesting
  static const debugCensusMethod = '__ruflet_core_listener_census__';

  @visibleForTesting
  static const debugCensusReply = 'core-host';

  @override
  State<CoreHost<C>> createState() => _CoreHostState<C>();
}

class _CoreHostState<C extends ControlCore> extends State<CoreHost<C>> {
  late final C core;
  Control? _listening;

  @override
  void initState() {
    super.initState();
    core = widget._create(widget._control);
    core._host = this;
    core.initCore();
    _listen(widget._control);
  }

  @override
  void didUpdateWidget(CoreHost<C> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget._control, widget._control)) {
      // Ruby replaced the control in place under the same element: move the
      // listener so invokes reach the new instance and the old one is free.
      _unlisten();
      core._control = widget._control;
      core.didRebind();
      _listen(widget._control);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    core.didChangeDependencies(context);
  }

  @override
  void dispose() {
    _unlisten();
    core.disposeCore();
    core._host = null;
    super.dispose();
  }

  void _listen(Control control) {
    control.addInvokeMethodListener(_invoke);
    _hostedListeners[control] = (_hostedListeners[control] ?? 0) + 1;
    _listening = control;
  }

  void _unlisten() {
    final control = _listening;
    if (control == null) return;
    control.removeInvokeMethodListener(_invoke);
    final count = (_hostedListeners[control] ?? 1) - 1;
    _hostedListeners[control] = count > 0 ? count : null;
    _listening = null;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<Object?> _invoke(String name, dynamic args) async {
    if (name == CoreHost.debugCensusMethod) {
      var census = false;
      assert(census = true);
      if (census) return CoreHost.debugCensusReply;
    }
    final handler = core.spec.declaresMethod(name) ? core.methods[name] : null;
    if (handler == null) {
      // A migrated control has exactly one listener, so no other listener can
      // claim the name: fail fast with the same error as an attached control
      // without listeners instead of returning a silent null.
      final control = core._control;
      throw UnsupportedError(
          "${control.type}(${control.id}).$name is not supported on "
          "${control.backend.platform.name}: no handler for \"$name\" is "
          "registered for this control");
    }
    return await handler(_invokeArgs(args));
  }

  @override
  Widget build(BuildContext context) {
    core._parseProps(context);
    final child = core.decorate(context, widget.builder(context, core));
    return switch (core.spec.layout) {
      LayoutWrap.layout => LayoutControl(
          control: core._control,
          skipProperties: core.spec.ownedLayoutKeys,
          child: child),
      LayoutWrap.base => BaseControl(control: core._control, child: child),
      LayoutWrap.none => child,
    };
  }
}

/// Invoke args as a map: Ruby sends `args: nil` for methods without
/// arguments.
// TODO(#52): use `invokeArgs` from utils/invoke.dart once engine #52 merges;
// this is a copy of it.
Map<dynamic, dynamic> _invokeArgs(dynamic args) {
  if (args is Map) return args;
  if (args != null) debugPrint("Ignoring non-map invoke args: $args");
  return const {};
}
