import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// A wire value read by the core but converted by a skin.
///
/// Design-bound types (Material `VisualDensity`, `ButtonStyle` maps, Cupertino
/// enums) cannot be parsed in the design-neutral core. The core reads the key
/// once ([key] stays the Ruby keyword) and the skin turns [value] into its
/// native type with a pure converter that takes no Control.
@immutable
class RawProp {
  const RawProp(this.key, this.value);

  final String key;
  final Object? value;

  bool get isSet => value != null;

  /// The value as a string (enum names, keywords), or null when unset.
  String? get string => value?.toString();

  static const _equality = DeepCollectionEquality();

  /// Equal wire data (maps and lists compared deeply) is equal.
  @override
  bool operator ==(Object other) =>
      other is RawProp &&
      other.key == key &&
      _equality.equals(other.value, value);

  @override
  int get hashCode => Object.hash(key, _equality.hash(value));

  @override
  String toString() => 'RawProp($key: $value)';
}
