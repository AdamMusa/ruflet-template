part of 'control_core.dart';

/// The one event dispatcher of a core. Every event goes to the core's
/// current Control, so a control Ruby replaced in place never receives
/// events meant for its successor.
class ControlEvents {
  ControlEvents._(this._core);

  final ControlCore _core;

  /// Ruby passed `on_<name>:` (wire `on_<name>: true`).
  bool subscribed(String name) => _core._control.hasEventHandler(name);

  /// The only call site of `Control.triggerEvent` in migrated code.
  void fire(String name, [Object? data]) {
    assert(_core.spec.event(name) != null,
        '${_core.spec.wireType} fires "$name", which its ControlSpec does not declare');
    if (subscribed(name)) _core._control.triggerEvent(name, data);
  }

  bool _active(String name) {
    final spec = _core.spec.event(name);
    assert(spec != null,
        '${_core.spec.wireType} wires "$name", which its ControlSpec does not declare');
    return subscribed(name) &&
        (!_core.disabled || (spec?.whileDisabled ?? false));
  }

  /// A native-gesture callback, or null when Ruby did not subscribe or the
  /// control is disabled, which also disables the native affordance.
  VoidCallback? callback(String name, {Object? Function()? data}) =>
      _active(name) ? () => fire(name, data?.call()) : null;

  /// Like [callback] for gestures that carry a value.
  ValueChanged<T>? valueCallback<T>(String name,
          {Object? Function(T value)? encode}) =>
      _active(name)
          ? (value) => fire(name, encode == null ? value : encode(value))
          : null;
}
