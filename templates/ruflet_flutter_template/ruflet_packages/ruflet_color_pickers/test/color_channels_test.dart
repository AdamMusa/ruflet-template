// The point of this test is to compare against the deprecated getters.
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_color_pickers/src/utils/color_channels.dart';

void main() {
  test('8-bit channel accessors equal the deprecated Color getters', () {
    final colors = [
      const Color(0x00000000),
      const Color(0xffffffff),
      const Color(0x80123456),
      const Color(0x7fabcdef),
      // Non 8-bit floats, as produced by HSV/HSL conversions.
      const Color.from(alpha: 0.5004, red: 0.1234, green: 0.9876, blue: 0.5),
      const Color.from(alpha: 0.0019, red: 0.0019, green: 0.998, blue: 0.333),
    ];
    for (final c in colors) {
      expect(c.alpha8, c.alpha, reason: '$c');
      expect(c.red8, c.red, reason: '$c');
      expect(c.green8, c.green, reason: '$c');
      expect(c.blue8, c.blue, reason: '$c');
      expect(c.opacity8, c.opacity, reason: '$c');
      expect(c.toARGB32(), c.value, reason: '$c');
      for (final o in [0.0, 0.004, 0.5, 0.731, 1.0]) {
        expect(c.withOpacity8(o), c.withOpacity(o), reason: '$c $o');
      }
    }
  });
}
