part of 'control_core.dart';

/// The only place migrated code calls `control.getX(...)`.
///
/// Every read is checked against the [ControlSpec] in debug builds: reading a
/// key the spec does not declare (or with another [PropType]) fails an
/// assertion, and every read is logged in [CoreReadLog] for the contract test.
/// Theme-dependent values resolve against [RufletStyleTheme.of] for the
/// host's own context, which the app renderers and per-control theme scopes
/// install for each design (a design that shades raised surfaces, like iOS
/// dialogs and sheets, resolves them for the surface the control is on).
class PropReader {
  PropReader._(this._control, this._spec, this._context)
      : _theme = RufletStyleTheme.of(_context);

  final Control _control;
  final ControlSpec _spec;
  final BuildContext _context;
  final RufletStyleTheme _theme;

  T _read<T>(String key, PropType type, T Function() parse) {
    assert(_spec.props.any((p) => p.key == key && p.type == type),
        '${_spec.wireType} reads "$key" as ${type.name} but its ControlSpec does not declare it');
    assert(() {
      CoreReadLog.record(_spec.wireType, key);
      return true;
    }());
    return parse();
  }

  /// Whether Ruby sent a non-null value for [key] (a declared key).
  bool has(String key) {
    assert(_spec.prop(key) != null,
        '${_spec.wireType} checks "$key" but its ControlSpec does not declare it');
    return _control.get(key) != null;
  }

  bool get disabled => _control.disabled;

  bool boolean(String key, [bool fallback = false]) =>
      _read(key, PropType.boolean, () => _control.getBool(key, fallback)!);

  /// A nullable boolean (tristate values): null when Ruby sent nothing.
  bool? optionalBoolean(String key, [bool? fallback]) =>
      _read(key, PropType.boolean, () => _control.getBool(key, fallback));

  int? integer(String key, [int? fallback]) =>
      _read(key, PropType.integer, () => _control.getInt(key, fallback));

  double? number(String key, [double? fallback]) =>
      _read(key, PropType.number, () => _control.getDouble(key, fallback));

  String? string(String key, [String? fallback]) =>
      _read(key, PropType.string, () => _control.getString(key, fallback));

  Color? color(String key, [Color? fallback]) => _read(
      key, PropType.color, () => _control.getColor(key, _context, fallback));

  WidgetStateProperty<Color?>? stateColor(String key) => _read(key,
      PropType.stateColor, () => _control.getWidgetStateColor(key, _theme));

  WidgetStateProperty<double?>? stateNumber(String key) => _read(
      key, PropType.stateNumber, () => _control.getWidgetStateDouble(key));

  WidgetStateProperty<Icon?>? stateIcon(String key) => _read(
      key, PropType.stateIcon, () => _control.getWidgetStateIcon(key, _theme));

  WidgetStateBorderSide? stateBorderSide(String key) => _read(
      key,
      PropType.stateBorderSide,
      () => _control.getWidgetStateBorderSide(key, _theme));

  TextStyle? textStyle(String key) =>
      _read(key, PropType.textStyle, () => _control.getTextStyle(key, _theme));

  EdgeInsets? edgeInsets(String key) =>
      _read(key, PropType.edgeInsets, () => _control.getPadding(key));

  BorderRadius? borderRadius(String key) =>
      _read(key, PropType.borderRadius, () => _control.getBorderRadius(key));

  OutlinedBorder? outlinedBorder(String key) =>
      _read(key, PropType.outlinedBorder, () => _control.getShape(key, _theme));

  Alignment? alignment(String key) =>
      _read(key, PropType.alignment, () => _control.getAlignment(key));

  Duration? duration(String key) =>
      _read(key, PropType.duration, () => _control.getDuration(key));

  ImplicitAnimationDetails? animation(String key) =>
      _read(key, PropType.animation, () => _control.getAnimation(key));

  T enumValue<T extends Enum>(List<T> values, String key, T fallback) => _read(
      key,
      PropType.enumName,
      () => parseEnum(values, _control.getString(key), fallback)!);

  IconData? icon(String key) =>
      _read(key, PropType.icon, () => _control.getIconData(key));

  ImageProvider? image(String key) => _read(
      key, PropType.image, () => _control.getImageProvider(key, _context));

  MouseCursor? mouseCursor(String key) =>
      _read(key, PropType.mouseCursor, () => _control.getMouseCursor(key));

  Widget? widget(String key) =>
      _read(key, PropType.widget, () => _control.buildWidget(key));

  /// A label-like value Ruby sends as plain text or as a child control.
  TextOrWidget? textOrWidget(String key) =>
      _read(key, PropType.textOrWidget, () {
        final value = _control.get(key);
        if (value is Control) {
          final child = _control.buildWidget(key);
          return child == null ? null : TextOrWidget.widget(child);
        }
        if (value is String) return TextOrWidget.text(value);
        if (value is num || value is bool) {
          return TextOrWidget.text(value.toString());
        }
        return null;
      });

  Widget? iconOrWidget(String key) =>
      _read(key, PropType.iconOrWidget, () => _control.buildIconOrWidget(key));

  List<Widget> widgets(String key) =>
      _read(key, PropType.widgets, () => _control.buildWidgets(key));

  /// Typed child lists (steps, segments, rows...): each child gets a reader
  /// checked against its own child spec.
  List<PropReader> children(String slot) {
    final childSpec = _spec.children[slot];
    assert(childSpec != null,
        '${_spec.wireType} reads child slot "$slot" but its ControlSpec does not declare it');
    assert(() {
      CoreReadLog.record(_spec.wireType, slot);
      return true;
    }());
    return _control
        .children(slot)
        .map((child) => PropReader._(child, childSpec!, _context))
        .toList();
  }

  /// Design-bound values (visual density, button style maps, Cupertino
  /// enums): read here, converted by a pure function in the skin's design.
  RawProp raw(String key) => _read(key, PropType.raw, () {
        final value = _control.get(key);
        assert(!_holdsControl(value),
            '${_spec.wireType}.$key holds a child control: declare it as a widget type, never raw');
        return RawProp(key, value);
      });

  /// A raw value must be plain wire data; a Control inside it would reach the
  /// skin and let it read keys or fire events itself.
  static bool _holdsControl(Object? value) => switch (value) {
        Control() => true,
        Map() =>
          value.keys.any(_holdsControl) || value.values.any(_holdsControl),
        Iterable() => value.any(_holdsControl),
        _ => false,
      };
}
