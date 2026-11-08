/// The design-neutral control kernel.
///
/// One core per control owns everything that comes from or goes to Ruby:
/// wire-key parsing ([PropReader]), events ([ControlEvents]), client state,
/// focus, invoke methods and the common layout keywords ([CoreHost]).
/// Material and Cupertino skins only map the core's typed values onto native
/// widgets. [Control] is visible only inside this library: a core keeps it in
/// a library-private field and exposes no getter for it, so a skin cannot read
/// a key or fire an event by itself.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../controls/base_controls.dart';
import '../extensions/control.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../services/client_action.dart'
    show parseClientActions, performClientActions;
import '../utils/alignment.dart';
import '../utils/animations.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/enums.dart';
import '../utils/icons.dart';
import '../utils/images.dart';
import '../utils/mouse.dart';
import '../utils/numbers.dart';
import '../utils/style_theme.dart';
import '../utils/text.dart';
import '../utils/time.dart';
import 'control_spec.dart';
import 'raw_prop.dart';
import 'text_or_widget.dart';

part 'control_events.dart';
part 'core_host.dart';
part 'prop_reader.dart';

/// Handles one invoke method. [args] is never null (see [CoreHost]).
typedef InvokeHandler = FutureOr<Object?> Function(Map<dynamic, dynamic> args);

/// Shared logic of one control, parameterized by its immutable props class.
///
/// Subclasses declare [spec], parse every [PropSpec] in [parse] (one read per
/// key, nothing else), and expose typed values and callbacks to the skins.
abstract class ControlCore<P extends Object> {
  ControlCore(Control control) : _control = control;

  /// Library-private: neither skins nor subclasses ever see the Control.
  Control _control;
  _CoreHostState? _host;
  P? _props;

  /// The control's declared contract.
  ControlSpec get spec;

  /// Parses the props for this build. Read each declared key exactly once.
  @protected
  P parse(PropReader r);

  /// The props parsed for the current build.
  P get props {
    final props = _props;
    if (props == null) {
      throw StateError('${spec.wireType} props were read before its first '
          'build parsed them');
    }
    return props;
  }

  /// The only way migrated code fires events.
  @protected
  late final ControlEvents events = ControlEvents._(this);

  bool get disabled => _control.disabled;
  bool get enabled => !disabled;

  /// The canonical wire type of the control (`FilledButton`, never an alias).
  /// One core class may serve several wire types (a registry entry maps them
  /// all to one host) and choose its [spec] from it.
  @protected
  String get wireType => _control.canonicalType;

  /// The canonical wire type of the enclosing control, for cores whose
  /// rendering depends on where they sit (a Button inside an AlertDialog).
  @protected
  String? get parentWireType => _control.parent?.canonicalType;

  /// The property of the enclosing control that holds this one (`leading`,
  /// `actions`, `controls`...), for cores that render differently in a
  /// particular slot (the iOS back chevron of an AppBar's leading button).
  @protected
  String? get parentSlot {
    final parent = _control.parent;
    if (parent == null) return null;
    bool isSelf(Object? value) =>
        value is Control &&
        (identical(value, _control) ||
            identical(value.unwrapComponent(), _control));
    for (final MapEntry(:key, :value) in parent.properties.entries) {
      if (isSelf(value) || (value is List && value.any(isSelf))) return key;
    }
    return null;
  }

  /// Interactive states, so both skins resolve `WidgetStateProperty` values
  /// the same way. Subclasses add theirs (selected, focused...).
  Set<WidgetState> get states => {if (disabled) WidgetState.disabled};

  @protected
  @mustCallSuper
  void initCore() {}

  /// Runs after every [parse]; [previous] is null on the first build.
  @protected
  @mustCallSuper
  void didParse(P? previous) {}

  @protected
  @mustCallSuper
  void didChangeDependencies(BuildContext context) {}

  /// Ruby replaced the Control in place (same element): re-subscribe
  /// anything bound to the old one. The host already moved the invoke
  /// listener.
  @protected
  @mustCallSuper
  void didRebind() {}

  @protected
  @mustCallSuper
  void disposeCore() {}

  /// Handlers for the spec's [MethodSpec]s. Mixins add theirs with
  /// `{...super.methods, ...}`. Only declared names are ever dispatched.
  @protected
  Map<String, InvokeHandler> get methods => const {};

  /// Reads a declared key before this control builds, for the few values a
  /// parent needs first: a scaffold reads an app bar's preferred size (and,
  /// on iOS, whether it fully obstructs the content) from the widget it is
  /// handed, before building it. Works on any core of the Control, hosted or
  /// not. Checked against the spec like [PropReader] reads, and not a parse:
  /// [parse] must still read the key (contract rule C6).
  @protected
  bool peekBoolean(String key, [bool fallback = false]) {
    assert(_declares(key, PropType.boolean));
    return _control.getBool(key, fallback)!;
  }

  /// Like [peekBoolean] for a number.
  @protected
  double? peekNumber(String key, [double? fallback]) {
    assert(_declares(key, PropType.number));
    return _control.getDouble(key, fallback);
  }

  /// Like [peekBoolean] for a color, resolved in the parent's [context].
  @protected
  Color? peekColor(String key, BuildContext context) {
    assert(_declares(key, PropType.color));
    return _control.getColor(key, context);
  }

  bool _declares(String key, PropType type) {
    if (spec.props.any((p) => p.key == key && p.type == type)) return true;
    throw AssertionError('${spec.wireType} peeks "$key" as ${type.name} but '
        'its ControlSpec does not declare it');
  }

  /// Performs the client actions Ruby attached to the control ([action],
  /// its `action` key read as raw wire data): each service call starts now,
  /// synchronously, so it runs inside the tap that called this, where
  /// browsers still allow clipboard writes, new tabs, file pickers and the
  /// share sheet. Call it from the tap callback before firing `click`. Each
  /// outcome is reported as the `action_result` event, which the spec must
  /// declare.
  @protected
  void runClientActions(RawProp action) {
    if (!hasClientActions(action)) return;
    performClientActions(_control, action.value,
        (outcome) => events.fire('action_result', outcome));
  }

  /// Whether [action] (a control's `action` key) holds any client action,
  /// for a core whose tap does nothing otherwise.
  @protected
  bool hasClientActions(RawProp action) =>
      parseClientActions(action.value).isNotEmpty;

  /// Client-owned state written back to Ruby (value, selected index...).
  @protected
  void writeBack(Map<String, Object?> values) =>
      _control.updateProperties(values, notify: true);

  /// Rebuilds the host (and so the skin) outside a Ruby update.
  @protected
  void markNeedsBuild() => _host?._rebuild();

  /// Design-neutral wrappers around the skin (semantics, scopes, sizing).
  @protected
  Widget decorate(BuildContext context, Widget skin) => skin;

  void _parseProps(BuildContext context) {
    final previous = _props;
    _props = parse(PropReader._(_control, spec, context));
    didParse(previous);
  }
}

/// A core whose control can take keyboard focus: owns the one [FocusNode],
/// fires `focus`/`blur` identically on both designs and answers the `focus`
/// and `blur` methods when the spec declares them.
mixin FocusableCore<P extends Object> on ControlCore<P> {
  FocusNode? _focusNode;

  /// Pass to the native widget.
  FocusNode get focusNode => _focusNode ??= FocusNode(debugLabel: spec.wireType)
    ..addListener(_focusChanged);

  bool get hasFocus => _focusNode?.hasFocus ?? false;

  void _focusChanged() {
    events.fire(hasFocus ? 'focus' : 'blur');
    markNeedsBuild();
  }

  @override
  Set<WidgetState> get states =>
      {...super.states, if (hasFocus) WidgetState.focused};

  @override
  Map<String, InvokeHandler> get methods => {
        ...super.methods,
        'focus': (_) {
          focusNode.requestFocus();
          return null;
        },
        'blur': (_) {
          _focusNode?.unfocus();
          return null;
        },
      };

  @override
  void disposeCore() {
    _focusNode
      ?..removeListener(_focusChanged)
      ..dispose();
    _focusNode = null;
    super.disposeCore();
  }
}

/// Debug-only record of the keys each wire type's core parsed, used by the
/// contract test to prove a core reads every key its spec declares.
@visibleForTesting
abstract final class CoreReadLog {
  static final Map<String, Set<String>> _reads = {};

  static void record(String wireType, String key) =>
      (_reads[wireType] ??= <String>{}).add(key);

  static Set<String> keysRead(String wireType) => {...?_reads[wireType]};

  static void clear() => _reads.clear();
}
