import 'dart:ui';

/// 8-bit channel accessors that return exactly what the deprecated
/// `Color.alpha/red/green/blue/opacity` getters and `withOpacity` returned
/// (dart:ui computes those from [Color.toARGB32]), so replacing them keeps
/// the pickers' math and rendering unchanged.
extension ColorChannels8 on Color {
  int get alpha8 => (toARGB32() >> 24) & 0xff;
  int get red8 => (toARGB32() >> 16) & 0xff;
  int get green8 => (toARGB32() >> 8) & 0xff;
  int get blue8 => toARGB32() & 0xff;

  /// [alpha8] as 0.0 to 1.0, quantized like the deprecated `opacity`.
  double get opacity8 => alpha8 / 0xff;

  /// Like the deprecated `withOpacity`: alpha quantized to 8 bits, unlike
  /// `withValues(alpha:)`, which keeps the exact double.
  Color withOpacity8(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0);
    return withAlpha((255.0 * opacity).round());
  }
}
